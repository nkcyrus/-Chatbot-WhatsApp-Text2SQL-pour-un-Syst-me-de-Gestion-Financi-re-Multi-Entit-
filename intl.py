translations = {
    "fr": {
        "welcome_otp":        "Bienvenue {nom} ! 👋 Un code OTP a été envoyé à {email}.",
        "otp_mail_error":     "❌ Impossible d'envoyer le mail de sécurité. Contactez votre administrateur.",
        "unknown_number":     "❌ Numéro non reconnu. Contactez votre administrateur Orionis.",
        "session_validated":  "✅ Session validée ! Bonjour {nom}, posez votre question sur les données Orionis.",
        "otp_wrong":          "❌ Code incorrect. Réessayez.",
        "session_expired":    "⚠️ Votre session a expiré après 10 minutes d'inactivité. Tapez 'Hello' pour vous reconnecter.",
        "confirm_request":    "📝 *Confirmation requise*\n\nVous demandez : \"{msg}\"\n\nConfirmez-vous cette opération ? (Répondez *Oui* ou *Non*)",
        "action_cancelled":   "❌ *Action annulée.* Aucune modification effectuée. Que souhaitez-vous faire ?",
        "session_closed":     "👋 Session fermée. À bientôt !",
        "quota_error":        "⏳ *Orionis Bot* : Nos services sont momentanément surchargés. Réessayez dans un instant.",
        "session_closed_suffix": "👋 *Session Orionis fermée.*",
        "no_response":        "⏳ Désolé, je n'ai pas pu générer de réponse. Réessayez dans un instant.",
        "start_prompt":       "Tapez 'Hello' pour commencer.",
        "action_refused":     "⚠️ *Action refusée* : {message}",
        "sql_error":          "❌ Une erreur technique s'est produite lors de l'exécution. Veuillez reformuler votre demande.",
        "unexpected_error":   "❌ Désolé, une erreur inattendue s'est produite. Réessayez dans un instant.",
        "overloaded":         "⏳ Désolé, mes services sont momentanément surchargés. Réessayez dans un instant.",
        "async_error":        "⚠️ Une erreur inattendue s'est produite. Réessayez.",
    },
    "en": {
        "welcome_otp":        "Welcome {nom}! 👋 A security code has been sent to {email}.",
        "otp_mail_error":     "❌ Unable to send the security email. Please contact your administrator.",
        "unknown_number":     "❌ Unrecognized number. Please contact your Orionis administrator.",
        "session_validated":  "✅ Session validated! Hello {nom}, you can now ask questions about Orionis data.",
        "otp_wrong":          "❌ Incorrect code. Please try again.",
        "session_expired":    "⚠️ Your session expired after 10 minutes of inactivity. Type 'Hello' to reconnect.",
        "confirm_request":    "📝 *Confirmation required*\n\nYou requested: \"{msg}\"\n\nDo you confirm this operation? (Reply *Yes* or *No*)",
        "action_cancelled":   "❌ *Action cancelled.* No changes were made. What would you like to do?",
        "session_closed":     "👋 Session closed. See you soon!",
        "quota_error":        "⏳ *Orionis Bot*: Our services are temporarily overloaded. Please try again in a moment.",
        "session_closed_suffix": "👋 *Orionis session closed.*",
        "no_response":        "⏳ Sorry, I could not generate a response. Please try again in a moment.",
        "start_prompt":       "Type 'Hello' to get started.",
        "action_refused":     "⚠️ *Action refused*: {message}",
        "sql_error":          "❌ A technical error occurred during execution. Please rephrase your request.",
        "unexpected_error":   "❌ Sorry, an unexpected error occurred. Please try again in a moment.",
        "overloaded":         "⏳ Sorry, my services are temporarily overloaded. Please try again in a moment.",
        "async_error":        "⚠️ An unexpected error occurred. Please try again.",
    },
}

DEFAULT_LANG = "fr"

def t(key: str, lang: str = DEFAULT_LANG, **kwargs) -> str:
    """Retourne la traduction d'une clé, avec interpolation optionnelle."""
    template = translations.get(lang, translations[DEFAULT_LANG]).get(key, key)
    return template.format(**kwargs) if kwargs else template