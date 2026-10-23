class PromptBuilder:
    def __init__(self, schema_data):
        self.schema = schema_data

    def generate_schema_description(self):
        """
        Transforme le JSON enrichi en description complète pour le LLM.
        Injecte : description, colonnes, synonymes, business_rules,
                  common_mistakes, flow_context et sample_queries.
        """
        prompt_parts = ["### ARCHITECTURE DE LA BASE DE DONNÉES ORIONIS\n"]

        for table_name, details in self.schema['tables'].items():
            prompt_parts.append(f"#### Table: {table_name}")
            prompt_parts.append(f"- **Description**: {details.get('description', 'N/A')}")

            # Colonnes
            cols = [f"{c['name']} ({c['type']})" for c in details.get('columns', [])]
            prompt_parts.append(f"- **Colonnes**: {', '.join(cols)}")

            # Synonymes — aide le LLM au schema linking
            synonyms = details.get('synonyms', [])
            if synonyms:
                prompt_parts.append(f"- **Synonymes**: {', '.join(synonyms)}")

            # Règles métier
            rules = details.get('business_rules', [])
            if rules:
                prompt_parts.append("- **Règles métier**:")
                for rule in rules:
                    prompt_parts.append(f"  * {rule}")

            # Erreurs fréquentes — guide le LLM sur les pièges
            mistakes = details.get('common_mistakes', [])
            if mistakes:
                prompt_parts.append("- **Erreurs fréquentes à éviter**:")
                for mistake in mistakes:
                    prompt_parts.append(f"  * {mistake}")

            # Contexte de flux — crucial pour les tables depense, credit, debit
            flow = details.get('flow_context')
            if flow:
                prompt_parts.append(f"- **Flux métier**: {flow.get('description', '')}")
                steps = flow.get('steps', [])
                if steps:
                    for step in steps:
                        prompt_parts.append(f"  {step}")
                note = flow.get('note')
                if note:
                    prompt_parts.append(f"  ⚠️ {note}")

            # Few-shot examples — on prend jusqu'à 3 exemples
            samples = details.get('sample_queries', [])
            if samples:
                prompt_parts.append("- **Exemples SQL (Few-Shot)**:")
                for s in samples[:3]:
                    prompt_parts.append(f"  * Question: {s['question']}")
                    prompt_parts.append(f"    SQL: `{s['sql']}`")

            prompt_parts.append("\n---\n")

        return "\n".join(prompt_parts)

    def generate_procedures_description(self):
        """
        Injecte les procédures/fonctions PostgreSQL dans le contexte LLM.
        Le LLM doit savoir utiliser CALL ou SELECT pour les appeler
        plutôt que de réécrire les CTEs manuellement.
        """
        procedures = self.schema.get('procedures', [])
        if not procedures:
            return ""

        parts = ["### PROCÉDURES ET FONCTIONS DISPONIBLES\n"]
        parts.append("⚠️ Privilégie toujours ces procédures/fonctions pour les opérations complexes.\n")

        for proc in procedures:
            name = proc.get('name')
            ptype = proc.get('type', 'PROCEDURE')
            description = proc.get('description', '')
            params = proc.get('parameters', [])
            samples = proc.get('sample_queries', [])
            mistakes = proc.get('common_mistakes', [])

            parts.append(f"#### {ptype}: {name}")
            parts.append(f"- **Description**: {description}")

            if params:
                param_str = ", ".join([f"{p['name']} ({p['type']}): {p['description']}" for p in params])
                parts.append(f"- **Paramètres**: {param_str}")

            if mistakes:
                parts.append("- **Erreurs fréquentes**:")
                for m in mistakes:
                    parts.append(f"  * {m}")

            if samples:
                parts.append("- **Exemples d'appel**:")
                for s in samples[:2]:
                    parts.append(f"  * Question: {s['question']}")
                    parts.append(f"    SQL: `{s['sql']}`")

            parts.append("")

        return "\n".join(parts)

    def generate_final_prompt(self, user_question, user_context, historique=None):
        """Assemble tout : schéma + procédures + sécurité + historique + question."""
        schema_text = self.generate_schema_description()
        procedures_text = self.generate_procedures_description()
        role = user_context.get('role', 'user').lower()
        id_entite = user_context.get('id_entite', 'Inconnu')

        # --- Règles de sécurité par rôle ---
        if role == "admin":
            security_rule = (
                "Tu es ADMINISTRATEUR. Tu as accès à TOUTES les données de toutes les entités. "
                "Tu peux faire SELECT, INSERT, UPDATE, DELETE sur toutes les tables. "
                "Ne filtre JAMAIS par id_entite sauf si l'utilisateur le demande explicitement."
            )
        elif role == "finance_admin":
            security_rule = (
                f"Tu es FINANCE ADMIN de l'entité ID {id_entite}. "
                "Tu as accès complet aux données financières (comptes, factures, dépenses, crédits, débits, transactions). "
                "SELECT, INSERT, UPDATE, DELETE autorisés sur les tables financières de ton entité uniquement. "
                "Accès en lecture seule sur les autres tables (personnel, projet, client, bureau). "
                f"Filtre systématiquement par id_entite = {id_entite} pour les tables qui le permettent."
            )
        elif role == "manager":
            security_rule = (
                f"Tu es MANAGER de l'entité ID {id_entite}. "
                "SELECT autorisé sur toutes les tables de ton entité. "
                "INSERT et UPDATE autorisés uniquement sur depense, depense_projet, projet. "
                "DELETE interdit. "
                f"Filtre systématiquement par id_entite = {id_entite}."
            )
        else:
            # Rôle 'user' ou inconnu — accès minimal
            security_rule = (
                f"Tu es UTILISATEUR simple de l'entité ID {id_entite}. "
                "SELECT uniquement, sur les données de ton entité. "
                "Aucune modification (INSERT, UPDATE, DELETE, CALL) autorisée. "
                f"Filtre systématiquement par id_entite = {id_entite}."
            )

        # --- Historique de conversation ---
        historique_text = ""
        if historique:
            historique_text = "### HISTORIQUE DE LA CONVERSATION (Contexte) :\n"
            for msg in historique[-3:]:
                historique_text += f"- {msg}\n"

        final_prompt = f"""
Tu es un expert SQL PostgreSQL pour le groupe Orionis.
Ta mission est de transformer la question de l'utilisateur en requête SQL valide,
ou de répondre directement si aucune donnée n'est nécessaire.

{schema_text}

{procedures_text}

### CONTEXTE ET SÉCURITÉ CRITIQUE :
1. Matricule utilisateur : {user_context.get('no_matricule', 'Inconnu')}
2. Entité ID : {id_entite}
3. Rôle : {role.upper()}
4. CONSIGNE DE SÉCURITÉ : {security_rule}
5. RÈGLE D'OR : Ne jamais accéder aux données d'une autre entité sans autorisation explicite du rôle.
6. COLONNE INTERDITE : Ne jamais inclure la colonne 'password' dans aucune requête SELECT.
7. PROCÉDURES : Pour les insertions complexes (dépense, crédit, transfert), utilise les procédures CALL disponibles plutôt que des CTEs manuels.
8. MODIFICATIONS depense_projet : Utilise BEGIN...DELETE...INSERT...COMMIT pour toute mise à jour de ventilation.

{historique_text}

### QUESTION ACTUELLE :
"{user_question}"

### CONSIGNES DE RÉPONSE :
- Si la question nécessite des données (employés, budgets, factures, etc.) → génère UNIQUEMENT le SQL, sans explication.
- Si le message est une salutation, remerciement ou question sur ton identité → réponds DIRECTEMENT en texte, sans SQL.
- Ne commence jamais par 'SQL:', 'Réponse:' ou des balises markdown.
- Si la question est hors-sujet (météo, sport, etc.) → réponds poliment que tu gères uniquement les données Orionis.
- Si la question est ambiguë → demande une précision courte.
- Si l'utilisateur semble avoir terminé (ex: 'Merci', 'C'est tout', 'Bonne journée') → commence ta réponse par [CLOSE_SESSION].

### PERSONNALITÉ :
- Ton nom est 'Orionis Bot'.
- Réponds toujours dans la langue de l'utilisateur (FR ou EN).
- Sois chaleureux pour les messages de courtoisie, concis pour les réponses techniques.
- Si l'utilisateur demande ce que tu peux faire, liste tes compétences :
    1. 👤 Trouver un collaborateur ou un client
    2. 🌍 Localiser une entité ou un bureau
    3. 💰 Consulter et gérer les budgets de projets
    4. 📊 Extraire des statistiques financières
    5. 💳 Enregistrer dépenses, factures et transferts
"""
        return final_prompt