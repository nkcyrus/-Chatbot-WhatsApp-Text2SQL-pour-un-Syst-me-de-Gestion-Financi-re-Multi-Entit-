"""
excel_exporter.py (anciennement csv_exporter.py)
================================================
Génération d'exports Excel (.xlsx) à partir des résultats SQL et envoi en pièce jointe
WhatsApp via l'API Twilio Media.
"""

import os
import uuid
import time
import threading
from pathlib import Path
from typing import Optional

# openpyxl permet de créer un fichier Excel proprement sans dépendre de Pandas
from openpyxl import Workbook 
from twilio.rest import Client as TwilioClient

# ============================================================
# CONFIGURATION
# ============================================================

SEUIL_CSV = 10
EXPORT_DIR = Path("exports")
EXPORT_DIR.mkdir(exist_ok=True)

CSV_TTL = 300  # 5 minutes
PUBLIC_URL = os.getenv("PUBLIC_URL")


# ============================================================
# GÉNÉRATION DU FICHIER EXCEL (Remplaçant du CSV)
# ============================================================

def generer_csv(rows: list, question: str) -> Optional[Path]:
    """
    Génère un fichier Excel (.xlsx) à partir d'une liste de RealDictRow psycopg2.
    Garde le nom 'generer_csv' pour ne pas casser tes autres scripts.
    """
    if not rows:
        return None

    try:
        # WhatsApp adore le .xlsx, on change donc l'extension
        nom_fichier = f"export_{uuid.uuid4().hex[:8]}.xlsx"
        chemin = EXPORT_DIR / nom_fichier

        colonnes = list(rows[0].keys())

        # Création du classeur Excel avec openpyxl
        wb = Workbook()
        ws = wb.active
        ws.title = "Résultats"

        # Écriture de l'en-tête
        ws.append(colonnes)

        # Écriture des lignes de données
        for row in rows:
            ws.append([row[col] for col in colonnes])

        # Sauvegarde du fichier
        wb.save(chemin)

        print(f"📊 [Excel] Fichier généré : {chemin} ({len(rows)} lignes)")
        return chemin

    except Exception as e:
        print(f"❌ [Excel] Erreur génération : {e}")
        return None


# ============================================================
# ENVOI VIA TWILIO
# ============================================================

def envoyer_csv_whatsapp(
    phone: str,
    chemin_csv: Path,
    question: str,
    lang: str = "fr"
) -> bool:
    """
    Envoie le fichier Excel en pièce jointe WhatsApp via Twilio Media.
    """
    try:
        account_sid = os.getenv("TWILIO_ACCOUNT_SID")
        auth_token  = os.getenv("TWILIO_AUTH_TOKEN")
        from_number = os.getenv("TWILIO_NUMBER")

        if not account_sid or not auth_token:
            print("❌ [Excel] Identifiants Twilio manquants")
            return False

        # L'URL publique pointera vers le fichier .xlsx
        url_fichier = f"{PUBLIC_URL}/exports/{chemin_csv.name}"

        client = TwilioClient(account_sid, auth_token)

        # Envoi du fichier
        message = client.messages.create(
            from_=f"whatsapp:{from_number}",
            to=f"whatsapp:{phone}" if not phone.startswith("whatsapp:") else phone,
            media_url=[url_fichier]
        )

        print(f"✅ [Excel] Envoyé à {phone} — SID : {message.sid}")

        _planifier_suppression(chemin_csv)
        return True

    except Exception as e:
        print(f"❌ [Excel] Erreur envoi Twilio : {e}")
        return False


# ============================================================
# LOGIQUE PRINCIPALE
# ============================================================

def traiter_resultats_avec_csv(
    rows: list,
    phone: str,
    question: str,
    lang: str = "fr"
) -> tuple[str, bool]:
    if not rows or len(rows) <= SEUIL_CSV:
        return rows, False

    chemin_csv = generer_csv(rows, question)
    if chemin_csv:
        succes = envoyer_csv_whatsapp(phone, chemin_csv, question, lang)
        if succes:
            return rows[:5], True

    return rows, False


# ============================================================
# UTILITAIRES (Ajustés pour le .xlsx)
# ============================================================

def compter_lignes_csv(chemin: Path) -> int:
    """Compte le nombre de lignes dans le fichier Excel (hors en-tête)."""
    try:
        from openpyxl import load_workbook
        wb = load_workbook(chemin, read_only=True)
        ws = wb.active
        return ws.max_row - 1  # -1 pour l'en-tête
    except Exception:
        return 0


def _planifier_suppression(chemin: Path):
    def supprimer():
        time.sleep(CSV_TTL)
        try:
            chemin.unlink(missing_ok=True)
            print(f"🗑️ [Excel] Fichier supprimé : {chemin.name}")
        except Exception as e:
            print(f"⚠️ [Excel] Erreur suppression : {e}")

    t = threading.Thread(target=supprimer, daemon=True)
    t.start()


def nettoyer_exports_expires():
    """Nettoie les fichiers Excel expirés au démarrage."""
    now = time.time()
    supprimes = 0
    # On cherche les .xlsx à la place des .csv
    for fichier in EXPORT_DIR.glob("*.xlsx"):
        try:
            age = now - fichier.stat().st_mtime
            if age > CSV_TTL:
                fichier.unlink()
                supprimes += 1
        except Exception:
            pass
    if supprimes:
        print(f"🗑️ [Excel] {supprimes} fichier(s) expiré(s) nettoyé(s) au démarrage")