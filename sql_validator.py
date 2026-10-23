"""
sql_validator.py
================
Validation statique du SQL généré par le LLM avant exécution.

Étapes de validation :
  1. Parsing AST via sqlglot (dialecte PostgreSQL)
  2. Blocage des commandes dangereuses (liste noire)
  3. Vérification des tables accédées (liste blanche)
  4. Vérification des colonnes accédées (liste blanche)
  5. Contrôle du périmètre par rôle (tables financières pour finance_admin, etc.)

Retourne un objet ValidationResult avec :
  - valid (bool)
  - error (str | None) — message d'erreur lisible par l'utilisateur
  - sql_clean (str) — SQL nettoyé et normalisé si valide
"""

import sqlglot
import sqlglot.expressions as exp
from dataclasses import dataclass
from typing import Optional


# ============================================================
# CONFIGURATION : LISTES BLANCHE / NOIRE
# ============================================================

# Commandes SQL interdites — détectées par nom de classe AST
# Approche par nom (string) compatible avec toutes les versions de sqlglot
# car certains attributs (ex: Truncate) varient selon la version installée
NOMS_COMMANDES_INTERDITES = {
    "drop", "droptable", "dropview", "dropindex",
    "create", "createtable", "createview", "createindex",
    "alter", "altertable",
    "truncate", "truncatetable",
    "grant", "revoke",
    "command",
}

# Tables autorisées du schéma Orionis
TABLES_AUTORISEES = {
    "entite_juridique",
    "personnel",
    "client",
    "bureau",
    "compte_bancaire",
    "projet",
    "depense",
    "facture_recue",
    "facture_emise",
    "depense_projet",
    "debit",
    "credit",
    "transaction_interne",
    "action",
    # Alias courants acceptés (avec accents ou sans)
    "facture_reçue",
}

# Colonnes interdites — ne doivent jamais apparaître dans un SELECT
COLONNES_INTERDITES = {"password"}

# Tables accessibles par rôle pour les opérations d'écriture (INSERT/UPDATE/DELETE)
TABLES_ECRITURE_PAR_ROLE = {
    "admin": TABLES_AUTORISEES,
    "finance_admin": {
        "compte_bancaire", "depense", "facture_recue", "facture_reçue",
        "facture_emise", "debit", "credit", "transaction_interne",
        "depense_projet"
    },
    "manager": {
        "depense", "depense_projet", "projet", "facture_recue", "facture_reçue"
    },
    "user": set()  # Aucune écriture autorisée
}

# Procédures/fonctions autorisées (CALL)
PROCEDURES_AUTORISEES = {
    "inserer_depense_complete",
    "inserer_credit_complet",
    "transfert_interne",
    "cloturer_projet",
    "stats_depenses_mois",
    "stats_depenses_projet",
    "stats_depenses_bureau",
    "stats_revenus_mois",
    "stats_revenus_client",
    "stats_tableau_de_bord",
}


# ============================================================
# RÉSULTAT DE VALIDATION
# ============================================================

@dataclass
class ValidationResult:
    valid: bool
    error: Optional[str] = None
    sql_clean: Optional[str] = None
    warning: Optional[str] = None


# ============================================================
# VALIDATEUR PRINCIPAL
# ============================================================

class SQLValidator:
    """
    Validateur AST basé sur sqlglot.
    Instancier avec le rôle de l'utilisateur courant.
    """

    def __init__(self, role: str = "user"):
        self.role = role.lower()

    def validate(self, sql: str) -> ValidationResult:
        """
        Point d'entrée principal.
        Retourne un ValidationResult.
        """
        sql = sql.strip()
        if not sql:
            return ValidationResult(valid=False, error="La requête SQL est vide.")

        # ── Étape 1 : Parsing AST ────────────────────────────────
        try:
            statements = sqlglot.parse(sql, dialect="postgres")
        except sqlglot.errors.ParseError as e:
            return ValidationResult(
                valid=False,
                error=f"Syntaxe SQL invalide : {str(e)}"
            )

        if not statements or statements[0] is None:
            return ValidationResult(valid=False, error="Impossible de parser la requête SQL.")

        # Traiter chaque statement (BEGIN...COMMIT peut en contenir plusieurs)
        for stmt in statements:
            if stmt is None:
                continue
            result = self._valider_statement(stmt, sql)
            if not result.valid:
                return result

        # ── Étape finale : normalisation ─────────────────────────
        try:
            sql_normalise = sqlglot.transpile(sql, read="postgres", write="postgres")[0]
        except Exception:
            sql_normalise = sql  # En cas d'échec, on garde le SQL original

        return ValidationResult(valid=True, sql_clean=sql_normalise)

    def _valider_statement(self, stmt, sql_original: str) -> ValidationResult:
        """Valide un statement individuel."""

        # ── Étape 2 : Commandes dangereuses ──────────────────────
        nom_classe = type(stmt).__name__.lower()
        if nom_classe in NOMS_COMMANDES_INTERDITES:
            return ValidationResult(
                valid=False,
                error=f"La commande {type(stmt).__name__.upper()} est interdite pour des raisons de sécurité."
            )

        # ── Gestion des transactions BEGIN/COMMIT ────────────────
        # sqlglot parse BEGIN comme Transaction — on l'autorise
        if isinstance(stmt, exp.Transaction):
            return ValidationResult(valid=True, sql_clean=sql_original)

        # ── Étape 3 : CALL — vérification procédure ──────────────
        if isinstance(stmt, exp.Anonymous) or "CALL" in sql_original.upper()[:10]:
            return self._valider_call(sql_original)

        # ── Étape 3 : Tables accédées ────────────────────────────
        tables_utilisees = self._extraire_tables(stmt)
        tables_inconnues = tables_utilisees - TABLES_AUTORISEES
        if tables_inconnues:
            return ValidationResult(
                valid=False,
                error=f"Table(s) inconnue(s) dans le schéma Orionis : {', '.join(tables_inconnues)}."
            )

        # ── Étape 4 : Colonnes interdites ─────────────────────────
        colonnes = self._extraire_colonnes(stmt)
        colonnes_interdites_trouvees = colonnes & COLONNES_INTERDITES
        if colonnes_interdites_trouvees:
            return ValidationResult(
                valid=False,
                error=f"Accès interdit à la colonne sensible : {', '.join(colonnes_interdites_trouvees)}."
            )

        # ── Étape 5 : Contrôle d'écriture par rôle ───────────────
        if isinstance(stmt, (exp.Insert, exp.Update, exp.Delete)):
            result = self._valider_ecriture(stmt, tables_utilisees)
            if not result.valid:
                return result

        return ValidationResult(valid=True, sql_clean=sql_original)

    def _valider_call(self, sql: str) -> ValidationResult:
        """Vérifie que la procédure appelée est dans la liste blanche."""
        sql_upper = sql.upper()
        if "CALL" not in sql_upper:
            return ValidationResult(valid=True, sql_clean=sql)

        # Extraire le nom de la procédure
        import re
        match = re.search(r'CALL\s+([a-zA-Z_][a-zA-Z0-9_]*)', sql, re.IGNORECASE)
        if match:
            nom_proc = match.group(1).lower()
            if nom_proc not in PROCEDURES_AUTORISEES:
                return ValidationResult(
                    valid=False,
                    error=f"Procédure inconnue ou non autorisée : {nom_proc}."
                )

        return ValidationResult(valid=True, sql_clean=sql)

    def _valider_ecriture(self, stmt, tables: set) -> ValidationResult:
        """Vérifie que le rôle peut écrire sur les tables accédées."""
        tables_autorisees_role = TABLES_ECRITURE_PAR_ROLE.get(self.role, set())

        if not tables_autorisees_role:
            return ValidationResult(
                valid=False,
                error="Votre rôle ne vous permet pas d'effectuer des modifications."
            )

        tables_non_autorisees = tables - tables_autorisees_role
        if tables_non_autorisees:
            return ValidationResult(
                valid=False,
                error=(
                    f"Votre rôle ({self.role.upper()}) ne vous permet pas de modifier "
                    f"la(les) table(s) : {', '.join(tables_non_autorisees)}."
                )
            )

        return ValidationResult(valid=True)

    @staticmethod
    def _extraire_tables(stmt) -> set:
        """Extrait tous les noms de tables référencées dans le statement."""
        tables = set()
        for table in stmt.find_all(exp.Table):
            if table.name:
                tables.add(table.name.lower())
        return tables

    @staticmethod
    def _extraire_colonnes(stmt) -> set:
        """Extrait tous les noms de colonnes référencées dans le statement."""
        colonnes = set()
        for col in stmt.find_all(exp.Column):
            if col.name:
                colonnes.add(col.name.lower())
        return colonnes


# ============================================================
# FONCTION UTILITAIRE (appelée depuis db_manager.py)
# ============================================================

def valider_sql(sql: str, role: str = "user") -> ValidationResult:
    """
    Point d'entrée simplifié pour valider un SQL généré par le LLM.

    Usage dans db_manager.py :
        from sql_validator import valider_sql
        result = valider_sql(sql_clean, role=session["role"])
        if not result.valid:
            return f"VALIDATION_ERROR:{result.error}"
        sql_clean = result.sql_clean
    """
    validator = SQLValidator(role=role)
    return validator.validate(sql)


# ============================================================
# TESTS UNITAIRES INTÉGRÉS
# ============================================================

if __name__ == "__main__":
    print("=== Tests SQLValidator ===\n")

    cas = [
        # (description, sql, role, attendu_valide)
        ("SELECT simple valide",
         "SELECT nom, budget FROM projet WHERE nom ILIKE '%Alpha%';",
         "user", True),

        ("DROP TABLE interdit",
         "DROP TABLE personnel;",
         "admin", False),

        ("Accès colonne password interdit",
         "SELECT nom, password FROM personnel WHERE no_matricule = 1;",
         "admin", False),

        ("Table inconnue",
         "SELECT * FROM salaires;",
         "user", False),

        ("INSERT autorisé pour manager",
         "INSERT INTO depense (libelle, montant, devise, date, categorie) VALUES ('Test', 100, 'EUR', CURRENT_DATE, 'projet');",
         "manager", True),

        ("INSERT interdit pour user",
         "INSERT INTO depense (libelle, montant) VALUES ('Test', 100);",
         "user", False),

        ("CALL procédure autorisée",
         "CALL inserer_depense_complete('Expertise', 500, 'EUR', CURRENT_DATE, 3, NULL);",
         "finance_admin", True),

        ("CALL procédure inconnue",
         "CALL drop_all_tables();",
         "admin", False),

        ("Requête multi-tables valide",
         "SELECT d.libelle, d.montant, p.nom FROM depense d JOIN depense_projet dp ON d.id_depense = dp.id_depense JOIN projet p ON dp.id_projet = p.id_projet;",
         "user", True),

        ("Truncate interdit",
         "TRUNCATE TABLE action;",
         "admin", False),
    ]

    ok = 0
    for desc, sql, role, attendu in cas:
        result = valider_sql(sql, role=role)
        statut = "✅" if result.valid == attendu else "❌"
        if result.valid == attendu:
            ok += 1
        msg = result.error if not result.valid else "OK"
        print(f"{statut} [{role.upper():14}] {desc}")
        print(f"   → {msg}\n")

    print(f"Résultat : {ok}/{len(cas)} tests passés")