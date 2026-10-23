import smtplib
from email.message import EmailMessage
import os

def envoyer_otp(email_destinataire, code_otp):
    # Récupération des identifiants dans le .env
    SMTP_SERVER = "smtp.gmail.com" # Ou celui de ton université
    SMTP_PORT = 465
    SENDER_EMAIL = os.getenv("EMAIL_SENDER") 
    SENDER_PASSWORD = os.getenv("EMAIL_PASSWORD") # Mot de passe d'application

    msg = EmailMessage()
    msg.set_content(f"""
Votre code de sécurité Orionis est : {code_otp}\nCe code expire dans 10 minutes.\n
Your Orionis security code is :  {code_otp}\nIt will expire within 10 minutes.
                    """)
    msg['Subject'] = f"Code de connexion Orionis / Orionis Authentication code- {code_otp}"
    msg['From'] = SENDER_EMAIL
    msg['To'] = email_destinataire

    try:
        with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT) as smtp:
            smtp.login(SENDER_EMAIL, SENDER_PASSWORD)
            smtp.send_message(msg)
        return True
    except Exception as e:
        print(f"Erreur d'envoi mail : {e}")
        return False