import json
import os

class SchemaLoader:
    """
    Charge l'architecture de la base de données Orionis à partir de fichiers JSON.
    Charge les tables ET les procédures/fonctions pour le contexte LLM.
    Les triggers ne sont pas chargés : ils s'exécutent côté SGBD de façon transparente.
    """
    def __init__(self, global_config_path, procedures_path=None):
        self.config_path = global_config_path
        self.procedures_path = procedures_path  # Chemin vers procedures.json
        self.base_dir = os.path.dirname(os.path.abspath(global_config_path))
        self.full_schema = {
            "project_metadata": {},
            "tables": {},
            "relationships": [],
            "procedures": []
        }

    def load(self):
        """Lit l'index global, charge toutes les tables et les procédures."""
        if not os.path.exists(self.config_path):
            raise FileNotFoundError(f"L'index global est introuvable : {self.config_path}")

        with open(self.config_path, 'r', encoding='utf-8') as f:
            global_config = json.load(f)

        self.full_schema["project_metadata"] = {
            "name": global_config.get("project_name"),
            "db_type": global_config.get("database_type"),
            "version": global_config.get("version")
        }
        self.full_schema["relationships"] = global_config.get("relationships", [])

        # Chargement des tables
        for table_entry in global_config.get("tables", []):
            name = table_entry["name"]
            path = table_entry["path"]
            table_path = os.path.join(self.base_dir, path)
            try:
                with open(table_path, 'r', encoding='utf-8') as tf:
                    self.full_schema["tables"][name] = json.load(tf)
            except Exception as e:
                print(f"⚠️ Erreur chargement table '{name}' ({table_path}): {e}")

        # Chargement des procédures/fonctions
        self._load_procedures()

        return self.full_schema

    def _load_procedures(self):
        """Charge le fichier procedures.json si disponible."""
        # Résolution du chemin : paramètre explicite ou conventions par défaut
        candidates = []
        if self.procedures_path:
            candidates.append(self.procedures_path)
        candidates += [
            os.path.join(self.base_dir, "procedures.json"),
            os.path.join(self.base_dir, "Procédures", "procedures.json"),
        ]

        for path in candidates:
            if os.path.exists(path):
                try:
                    with open(path, 'r', encoding='utf-8') as f:
                        self.full_schema["procedures"] = json.load(f)
                    print(f"✅ Procédures chargées depuis : {path}")
                    return
                except Exception as e:
                    print(f"⚠️ Erreur chargement procédures ({path}): {e}")
                    return

        print("ℹ️ Aucun fichier procedures.json trouvé — procédures non injectées dans le contexte LLM.")