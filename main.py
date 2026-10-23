import os
import time
import re
from dotenv import load_dotenv
from google import genai
from flask import Flask, request, send_from_directory, make_response
import threading

from schema_loader import SchemaLoader
from prompt_builder import PromptBuilder
from db_manager import verifier_utilisateur, executer_sql_genere, generer_otp, get_langue_utilisateur
from mailer import envoyer_otp
from interfaces.whatsapp_adapter import WhatsAppAdapter
from intl import t
from csv_exporter import traiter_resultats_avec_csv, nettoyer_exports_expires, EXPORT_DIR

# --- CONFIGURATION ---
TIMEOUT_SECONDS = 10 * 60
app = Flask(__name__)
load_dotenv()

# Pool de modèles Gemini valides (ordre de priorité)
MODELES_POOL = [
    'gemini-flash-latest',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-3-flash-preview',
    'gemini-3.1-flash-lite-preview',
    'gemma-3n-e4b-it',
    'gemma-3n-e2b-it',
    'gemma-3-27b-it',
    'gemma-3-12b-it'
]

# Client Gemini
client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

# Chargement du schéma Orionis (tables + procédures)
loader = SchemaLoader(
    global_config_path='Dictionnaire de Contexte/schema_global.json',
    procedures_path='Dictionnaire de Contexte/procedure/procedures.json'
)
db_schema = loader.load()
builder = PromptBuilder(db_schema)

# Sessions utilisateurs en mémoire
user_sessions = {}

# Nettoyage des CSV expirés au démarrage
nettoyer_exports_expires()


# --- FONCTIONS OUTILS ---

def est_une_ecriture(sql):
    """Détecte si la requête modifie les données."""
    mots_cles_ecriture = ["INSERT", "UPDATE", "DELETE", "CALL", "BEGIN"]
    return any(mot in sql.upper() for mot in mots_cles_ecriture)


def extraire_sql(texte):
    """Nettoie la réponse de l'IA pour ne garder que le SQL."""
    sql = re.sub(r"```sql|```", "", texte)
    return sql.strip()


def appeler_ia_avec_fallback(prompt_final, nom_etape="IA"):
    """
    Appelle l'IA Gemini avec gestion des quotas et fallback sur les modèles du pool.
    Retourne le texte de la réponse ou None si tout échoue.
    """
    for modele_id in MODELES_POOL:
        try:
            print(f"📡 [{nom_etape}] Tentative avec : {modele_id}...")
            response = client.models.generate_content(
                model=modele_id,
                contents=prompt_final
            )
            if response and response.text:
                print(f"✅ [{nom_etape}] Succès via {modele_id}")
                return response.text.strip()

        except Exception as e:
            error_msg = str(e).lower()
            if any(k in error_msg for k in ["429", "quota", "limit", "503", "overload"]):
                print(f"⚠️ [{nom_etape}] {modele_id} indisponible/saturé. Suivant...")
                continue
            else:
                print(f"❌ [{nom_etape}] Erreur critique sur {modele_id}: {e}")
                break

    return None


def detecter_langue(pays: str) -> str:
    """Demande à l'IA la langue officielle du pays, retourne 'fr' ou 'en'."""
    if not pays:
        return "fr"

    prompt = (
        f"Le pays est : '{pays}'.\n"
        "Quelle est sa langue officielle principale ?\n"
        "Réponds UNIQUEMENT par 'fr' si c'est le français, 'en' sinon. "
        "Aucun autre texte."
    )
    resultat = appeler_ia_avec_fallback(prompt, nom_etape="DETECT_LANGUE")
    langue = resultat.strip().lower() if resultat else "fr"
    return langue if langue in ("fr", "en") else "fr"


def poser_question(question, user_context):
    """
    Envoie la question + contexte à l'IA.
    Retourne soit du SQL, soit une réponse directe préfixée par 'DIRECT:'.
    """
    historique = user_context.get("historique", [])
    prompt_complet = builder.generate_final_prompt(question, user_context, historique)

    response_brute = appeler_ia_avec_fallback(prompt_complet, nom_etape="DECISION_IA")
    if not response_brute:
        return "ERREUR_QUOTA_TOTAL"

    mots_cles_sql = ["SELECT", "INSERT", "UPDATE", "DELETE", "CALL", "BEGIN", "WITH"]
    if any(keyword in response_brute.upper() for keyword in mots_cles_sql):
        print("🔍 [MODE DATA] Génération SQL détectée")
        return extraire_sql(response_brute)
    else:
        print("💬 [MODE CHIT-CHAT] Réponse directe détectée")
        return f"DIRECT:{response_brute}"


def verifier_timeout(phone):
    """Vérifie si la session a expiré. Supprime la session si c'est le cas."""
    session = user_sessions.get(phone)
    if not session:
        return False
    temps_ecoule = time.time() - session.get("last_activity", 0)
    if temps_ecoule > TIMEOUT_SECONDS:
        print(f"⏰ Timeout pour {phone}")
        del user_sessions[phone]
        return True
    return False


def generer_reponse_finale(question_user, resultat, lang="fr", phone=None):
    """
    Formule une réponse WhatsApp claire à partir des données SQL ou d'un message d'erreur.
    Si les résultats dépassent le seuil, génère et envoie un CSV en pièce jointe.

    Args:
        question_user : question originale de l'utilisateur
        resultat      : retour de executer_sql_genere
        lang          : langue de la session ('fr' ou 'en')
        phone         : numéro de l'utilisateur (requis pour l'export CSV)
    """
    # Requête bloquée par la validation AST
    if isinstance(resultat, str) and resultat.startswith("VALIDATION_ERROR:"):
        message_validation = resultat.replace("VALIDATION_ERROR:", "").strip()
        return f"⛔ *Requête refusée* : {message_validation}"

    # Erreur métier levée par un trigger
    if isinstance(resultat, str) and resultat.startswith("METIER_ERROR:"):
        message_metier = resultat.replace("METIER_ERROR:", "").strip()
        return t("action_refused", lang, message=message_metier)

    # Erreur SQL
    if isinstance(resultat, str) and resultat.startswith("SQL_ERROR:"):
        print(f"🔴 Erreur SQL : {resultat}")
        return t("sql_error", lang)

    # Erreur d'exécution générale
    if isinstance(resultat, str) and resultat.startswith("Erreur d'exécution"):
        print(f"🔴 {resultat}")
        return t("unexpected_error", lang)

    # Confirmation d'écriture réussie
    if isinstance(resultat, str) and resultat.startswith("✅"):
        return resultat

    # Aucun résultat SELECT
    if not resultat:
        prompt = (
            f"L'utilisateur a demandé : '{question_user}'. "
            "Aucune donnée ne correspond. Informe-le poliment qu'aucun résultat "
            "ne correspond à cette recherche, sans mentionner de termes techniques. "
            f"Réponds en {'français' if lang == 'fr' else 'anglais'}."
        )
        reponse = appeler_ia_avec_fallback(prompt, nom_etape="FORMATAGE")
        return reponse or t("overloaded", lang)

    # ── Export CSV si résultats volumineux ──────────────────────────────
    rows_apercu = resultat
    csv_envoye  = False

    if phone and isinstance(resultat, list):
        rows_apercu, csv_envoye = traiter_resultats_avec_csv(
            resultat, phone, question_user, lang
        )

    # ── Formatage de la réponse principale ──────────────────────────────
    suffixe_csv = ""
    if csv_envoye:
        if lang == "en":
            suffixe_csv = "\n\n📎 The full results have been sent as a CSV attachment."
        else:
            suffixe_csv = "\n\n📎 Les résultats complets ont été envoyés en pièce jointe CSV."

    prompt = f"""
L'utilisateur a demandé : '{question_user}'
Voici {"les 5 premières lignes des" if csv_envoye else "les"} données extraites : {rows_apercu}

CONSIGNES :
1. Formate une réponse claire et concise pour WhatsApp.
2. Utilise des emojis et des listes à puces si pertinent.
3. Ne mentionne JAMAIS les termes 'SQL', 'base de données', 'requête' ou 'table'.
4. Si les données sont vides, dis poliment qu'aucune information n'est disponible.
{"5. Précise qu'il s'agit d'un aperçu, le fichier complet a été envoyé en pièce jointe." if csv_envoye else ""}
5. Réponds en {'français' if lang == 'fr' else 'anglais'}.
"""

    reponse = appeler_ia_avec_fallback(prompt, nom_etape="FORMATAGE")
    if not reponse:
        return t("overloaded", lang)

    return reponse + suffixe_csv


# --- LOGIQUE CHATBOT ---

def gerer_chatbot(phone, message):
    # Vérification timeout avant tout
    if phone in user_sessions and verifier_timeout(phone):
        lang = user_sessions.get(phone, {}).get("lang", "fr")
        return t("session_expired", lang)

    session = user_sessions.get(phone, {"status": "CLOSED"})

    # --- DÉMARRAGE ---
    if session["status"] == "CLOSED" and "hello" in message.lower():
        employe = verifier_utilisateur(phone)
        if employe:
            pays = get_langue_utilisateur(employe["id_entite"])
            lang = detecter_langue(pays)

            otp = generer_otp()
            if envoyer_otp(employe["email"], otp):
                user_sessions[phone] = {
                    "status":        "AWAITING_OTP",
                    "lang":          lang,
                    "otp_secret":    otp,
                    "email":         employe["email"],
                    "role":          employe["role"],
                    "nom":           employe["nom"],
                    "id_entite":     employe["id_entite"],
                    "no_matricule":  employe["no_matricule"],
                    "last_activity": time.time(),
                    "historique":    []
                }
                return t("welcome_otp", lang, nom=employe["nom"], email=employe["email"])
            return t("otp_mail_error", lang)
        return t("unknown_number", "fr")

    # --- VALIDATION OTP ---
    elif session["status"] == "AWAITING_OTP":
        lang = session.get("lang", "fr")
        if message.strip() == session["otp_secret"]:
            user_sessions[phone]["status"] = "ACTIVE"
            user_sessions[phone]["last_activity"] = time.time()
            return t("session_validated", lang, nom=session["nom"])
        return t("otp_wrong", lang)

    # --- EN ATTENTE DE CONFIRMATION ---
    elif session["status"] == "AWAITING_CONFIRMATION":
        lang = session.get("lang", "fr")
        if any(word in message.lower() for word in ["oui", "ok", "confirme", "valider", "yes"]):
            sql_a_executer = session["pending_sql"]
            original_msg   = session["pending_msg"]

            resultats      = executer_sql_genere(
                sql_a_executer,
                session["no_matricule"],
                original_msg,
                role=session.get("role", "user")
            )
            reponse_finale = generer_reponse_finale(
                original_msg, resultats, lang, phone=phone
            )

            user_sessions[phone]["status"] = "ACTIVE"
            user_sessions[phone].pop("pending_sql", None)
            user_sessions[phone].pop("pending_msg", None)
            return reponse_finale
        else:
            user_sessions[phone]["status"] = "ACTIVE"
            user_sessions[phone].pop("pending_sql", None)
            user_sessions[phone].pop("pending_msg", None)
            return t("action_cancelled", lang)

    # --- SESSION ACTIVE ---
    elif session["status"] == "ACTIVE":
        lang = session.get("lang", "fr")
        user_sessions[phone]["last_activity"] = time.time()

        if any(word in message.lower() for word in ["quitter", "fin", "bye", "logout"]):
            del user_sessions[phone]
            return t("session_closed", lang)

        # Appel IA
        resultat_ia = poser_question(message, session)

        if resultat_ia == "ERREUR_QUOTA_TOTAL":
            return t("quota_error", lang)

        reponse_finale = None

        if resultat_ia.startswith("DIRECT:"):
            reponse_finale = resultat_ia.replace("DIRECT:", "").strip()

            if "[CLOSE_SESSION]" in reponse_finale:
                reponse_finale = reponse_finale.replace("[CLOSE_SESSION]", "").strip()
                del user_sessions[phone]
                return f"{reponse_finale}\n\n{t('session_closed_suffix', lang)}"

        else:
            # C'est du SQL
            sql_genere = resultat_ia

            if est_une_ecriture(sql_genere):
                user_sessions[phone]["status"]      = "AWAITING_CONFIRMATION"
                user_sessions[phone]["pending_sql"]  = sql_genere
                user_sessions[phone]["pending_msg"]  = message
                return t("confirm_request", lang, msg=message)

            resultats      = executer_sql_genere(
                sql_genere,
                session["no_matricule"],
                message,
                role=session.get("role", "user")
            )
            reponse_finale = generer_reponse_finale(
                message, resultats, lang, phone=phone
            )

        # Mise à jour de l'historique
        if reponse_finale is not None:
            user_sessions[phone]["historique"].append(f"Utilisateur: {message}")
            user_sessions[phone]["historique"].append(f"Assistant: {reponse_finale}")
            user_sessions[phone]["historique"] = user_sessions[phone]["historique"][-6:]
            return reponse_finale
        else:
            return t("no_response", lang)

    return t("start_prompt", "fr")


def traitement_asynchrone(phone, message):
    """Traite le message en arrière-plan et envoie la réponse via WhatsApp."""
    try:
        reponse_bot = gerer_chatbot(phone, message)
        if reponse_bot:
            WhatsAppAdapter.send_direct_message(phone, reponse_bot)
    except Exception as e:
        print(f"🚨 Erreur traitement_asynchrone pour {phone} : {e}")
        WhatsAppAdapter.send_direct_message(phone, t("async_error", "fr"))


# --- FLASK WEBHOOK ---

@app.route("/whatsapp", methods=['POST'])
def whatsapp_webhook():
    phone, user_message = WhatsAppAdapter.extract_data()
    task = threading.Thread(target=traitement_asynchrone, args=(phone, user_message))
    task.start()
    return "", 200


@app.route("/exports/<filename>")
def servir_export(filename):
    """
    Route Flask pour servir les fichiers CSV générés.
    Twilio appelle cette URL pour télécharger le fichier avant de l'envoyer à l'utilisateur.
    """

    response = make_response(send_from_directory(EXPORT_DIR, filename, as_attachment=False))
    response.headers['Content-Type'] = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    response.headers['Content-Disposition'] = 'inline'
    return response


if __name__ == "__main__":
    print("\n🚀 SERVEUR ORIONIS ACTIF\n")
    app.run(host="0.0.0.0", port=5000, debug=False)