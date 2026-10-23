import psycopg2
from psycopg2.extras import RealDictCursor
import os
from dotenv import load_dotenv
import random
 
try:
    from sql_validator import valider_sql
    VALIDATION_AST_DISPONIBLE = True
except ImportError:
    print("⚠️ sqlglot non disponible — validation AST désactivée. Installez : pip install sqlglot")
    VALIDATION_AST_DISPONIBLE = False
 
load_dotenv()
 
 
def get_connection():
    """Établit la connexion avec le conteneur Docker."""
    return psycopg2.connect(
        host=os.getenv("DB_HOST"),
        database=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        port=os.getenv("DB_PORT")
    )
 
 
def verifier_utilisateur(phone):
    """Cherche l'utilisateur en base par son numéro de téléphone."""
    query = "SELECT no_matricule, nom, prenom, email, role, id_entite FROM personnel WHERE telephone = %s;"
    try:
        with get_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(query, (phone,))
                return cur.fetchone()
    except Exception as e:
        print(f"❌ Erreur DB verifier_utilisateur : {e}")
        return None
 
 
def executer_sql_genere(sql, no_matricule, message, role="user"):
    """
    Exécute la requête SQL générée par le LLM.
 
    Étapes :
      1. Nettoyage des balises Markdown
      2. Validation AST via sqlglot (liste blanche tables/colonnes, rôle)
      3. Injection de app.current_matricule pour les triggers d'audit
      4. Exécution avec gestion commit/rollback
      5. Logging des SELECT et des erreurs
    """
    sql_clean = sql.replace("```sql", "").replace("```", "").strip()
    est_ecriture = any(word in sql_clean.upper() for word in ["INSERT", "UPDATE", "DELETE", "CALL"])
 
    # ── Étape 2 : Validation AST ────────────────────────────────────────
    if VALIDATION_AST_DISPONIBLE:
        result = valider_sql(sql_clean, role=role)
        if not result.valid:
            print(f"🚫 [VALIDATION AST] Refus : {result.error}")
            description = f"Question: {message} | SQL: {sql_clean} | Refus AST: {result.error}"
            enregistrer_action(no_matricule, sql_clean, description, "ECHEC")
            return f"VALIDATION_ERROR:{result.error}"
        # Utiliser le SQL normalisé par sqlglot
        sql_clean = result.sql_clean or sql_clean
        print(f"✅ [VALIDATION AST] SQL validé pour rôle {role.upper()}")
 
    conn = None
    try:
        conn = get_connection()
 
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # ── Étape 3 : Contexte de session pour les triggers d'audit ──
            cur.execute("SET LOCAL app.current_matricule = %s", (no_matricule,))
 
            cur.execute(sql_clean)
 
            if est_ecriture:
                conn.commit()
                # Les triggers d'audit gèrent le logging en base pour les écritures
                return "✅ Données enregistrées avec succès."
            else:
                rows = cur.fetchall()
                conn.commit()
                # Les SELECT ne déclenchent pas de trigger → on logue manuellement
                description = f"Question: {message} | SQL: {sql_clean}"
                enregistrer_action(no_matricule, sql_clean, description, "SUCCES")
                return rows
 
    except psycopg2.errors.RaiseException as e:
        # Exceptions métier levées par triggers ou procédures (budget, solde, etc.)
        if conn:
            conn.rollback()
        message_erreur = str(e).split('\n')[0].strip()
        description = f"Question: {message} | SQL: {sql_clean} | Refus métier: {message_erreur}"
        enregistrer_action(no_matricule, sql_clean, description, "ECHEC")
        return f"METIER_ERROR:{message_erreur}"
 
    except psycopg2.Error as e:
        # Erreurs PostgreSQL (syntaxe SQL, contraintes FK, etc.)
        if conn:
            conn.rollback()
        description = f"Question: {message} | SQL: {sql_clean} | Erreur PG: {str(e)}"
        enregistrer_action(no_matricule, sql_clean, description, "ECHEC")
        return f"SQL_ERROR:{str(e)}"
 
    except Exception as e:
        # Erreurs inattendues
        if conn:
            conn.rollback()
        description = f"Question: {message} | SQL: {sql_clean} | Erreur: {str(e)}"
        enregistrer_action(no_matricule, sql_clean, description, "ECHEC")
        return f"Erreur d'exécution : {e}"
 
    finally:
        if conn:
            conn.close()
 
 
def generer_otp():
    """Génère un code OTP à 6 chiffres."""
    return str(random.randint(100000, 999999))
 
 
def enregistrer_action(no_matricule, sql_genere, description, statut="SUCCES"):
    """
    Logue une action dans la table action.
    Utilise une connexion séparée pour ne pas interférer avec la transaction principale.
    """
    try:
        mots = sql_genere.strip().split()
        type_action = mots[0].upper() if mots else "INCONNU"
 
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO action (type, description, date_action, statut, no_matricule)
                    VALUES (%s, %s, CURRENT_TIMESTAMP, %s, %s)
                    """,
                    (type_action, description, statut, no_matricule)
                )
            conn.commit()
        print(f"💾 Log [{statut}] [{type_action}] pour matricule {no_matricule}")
 
    except Exception as e:
        print(f"⚠️ Erreur logging action : {e}")

def get_langue_utilisateur(id_entite: int) -> str:
    """Récupère le pays de l'entité et retourne le code langue via l'IA."""
    conn = None
    cursor = None
    try:
        conn = get_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT pays FROM entite_juridique WHERE id_entite = %s", (id_entite,)
        )
        row = cursor.fetchone()
        return row[0] if row else None
    except Exception as e:
        print(f"❌ Erreur get_langue_utilisateur : {e}")
        return None
    finally:
        cursor.close()
        conn.close()