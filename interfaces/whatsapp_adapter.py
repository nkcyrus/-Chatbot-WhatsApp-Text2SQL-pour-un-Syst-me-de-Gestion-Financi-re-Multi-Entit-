from flask import request
from twilio.twiml.messaging_response import MessagingResponse
from twilio.rest import Client
import os

class WhatsAppAdapter:
    """
    S'occupe uniquement de l'interface avec Twilio.
    Respecte la Single Responsibility Principle (SRP).
    """

    @staticmethod
    def extract_data():
        """
        Extrait le message et le numéro de l'expéditeur de la requête HTTP.
        """
        # 'From' arrive sous la forme 'whatsapp:+33612345678'
        raw_phone = request.values.get('From', '')
        phone = raw_phone.replace('whatsapp:', '')
        
        message = request.values.get('Body', '')
        
        return phone, message


    # def create_response(text):
    #     """
    #     Formate une chaîne de caractères en réponse compatible Twilio (TwiML).
    #     """
    #     resp = MessagingResponse()
    #     # On peut ajouter du formatage WhatsApp ici (*bold*, _italic_)
    #     msg = resp.message()
    #     msg.body(text)
        
    #     return str(resp)

    @staticmethod
    def send_direct_message(to_phone, body):

        account_sid = os.getenv("TWILIO_ACCOUNT_SID")
        auth_token = os.getenv("TWILIO_AUTH_TOKEN")
        from_number = os.getenv("TWILIO_NUMBER")

        client = Client(account_sid, auth_token)
        client.messages.create(
            from_=f"whatsapp:{from_number}",
            body= body,
            to=f"whatsapp:{to_phone}"
        )