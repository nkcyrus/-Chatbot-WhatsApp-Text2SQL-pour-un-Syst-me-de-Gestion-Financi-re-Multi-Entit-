# 🤖 Orionis Finance Bot — Chatbot WhatsApp Text2SQL

Chatbot WhatsApp permettant d'interroger et d'alimenter en langage naturel (FR/EN) la base de données financière multi-entité du groupe Orionis. L'utilisateur envoie un message WhatsApp, le système génère le SQL correspondant, le valide, l'exécute et retourne une réponse claire et formatée — avec export CSV automatique pour les résultats volumineux.

---

## 📋 Table des matières

- [Architecture](#architecture)
- [Stack technique](#stack-technique)
- [Structure du projet](#structure-du-projet)
- [Base de données](#base-de-données)
- [Validation AST](#validation-ast)
- [Export XLXS](#export-XLXS)
- [Internationalisation](#internationalisation)
- [Installation et démarrage](#installation-et-démarrage)
- [Authentification](#authentification)
- [Rôles et permissions](#rôles-et-permissions)
- [Exemples d'utilisation](#exemples-dutilisation)

---

## Architecture

```
WhatsApp (Twilio)
      │
      ▼
Flask Webhook (/whatsapp)
      │
      ▼
Gestion de session (user_sessions)
      │
      ├─── Authentification OTP (mailer.py)
      │
      ▼
PromptBuilder (prompt_builder.py)
  ├── Schéma des tables (14 tables)
  ├── Procédures/Fonctions (13)
  └── Contexte utilisateur (rôle, entité, historique, langue)
      │
      ▼
Gemini API (avec fallback multi-modèles)
      │
      ├── SQL généré
      │       │
      │       ▼
      │   SQLValidator (sql_validator.py)
      │   ├── Blocage commandes dangereuses (DROP, CREATE, ALTER...)
      │   ├── Liste blanche des 13 tables autorisées
      │   ├── Blocage colonnes sensibles (password)
      │   └── Contrôle d'écriture par rôle
      │       │
      │       ▼
      │   db_manager.py → PostgreSQL (Docker)
      │         │
      │   Triggers automatiques
      │   (audit, soldes, garde-fous)
      │         │
      │         ▼
      │   Résultats > 10 lignes ?
      │   ├── Oui → csv_exporter.py → Fichier Excel en pièce jointe WhatsApp
      │   └── Non → Formatage LLM → WhatsApp
      │
      └── Réponse directe (chit-chat)
              │
              ▼
         intl.py (messages FR/EN)
              │
              ▼
        WhatsApp (Twilio)
```

---

## Stack technique

| Composant | Technologie |
|-----------|-------------|
| Chatbot | WhatsApp Cloud API via Twilio |
| Backend | Python 3.11 + Flask |
| LLM | Google Gemini (multi-modèles avec fallback) |
| Base de données | PostgreSQL 16 |
| Conteneurisation | Docker + Docker Compose |
| Envoi OTP | SMTP Gmail |
| Validation SQL | sqlglot (parsing AST) |
| Export XLXS | xlxs (openpyxl) + Twilio Media API |
| Internationalisation | intl.py (FR/EN) |

---

## Structure du projet

```
orionis-bot/
│
├── main.py                         # Point d'entrée Flask + logique chatbot
├── db_manager.py                   # Connexion PostgreSQL + exécution SQL + validation AST
├── sql_validator.py                # Validation statique du SQL (liste blanche AST)
├── csv_exporter.py                 # Génération et envoi xlxs via Twilio Media
├── prompt_builder.py               # Construction des prompts LLM
├── schema_loader.py                # Chargement du dictionnaire de contexte
├── mailer.py                       # Envoi des codes OTP par email
├── intl.py                         # Messages multilingues (FR/EN)
├── auth.py                         # Utilitaires d'authentification
│
├── interfaces/
│   └── whatsapp_adapter.py         # Intégration Twilio WhatsApp
│
├── exports/                        # Fichiers CSV générés (TTL 5 min, auto-nettoyés)
│
├── Dictionnaire de Contexte/
│   ├── schema_global.json          # Index global du schéma
│   ├── procedure/
│   │   └── procedures.json         # Procédures et fonctions (13 entrées)
│   └── tables/
│       ├── action.json
│       ├── bureau.json
│       ├── client.json
│       ├── compte_bancaire.json
│       ├── credit.json
│       ├── debit.json
│       ├── depense.json
│       ├── depense_projet.json
│       ├── entite_juridique.json
│       ├── facture_emise.json
│       ├── facture_recue.json
│       ├── personnel.json
│       ├── projet.json
│       └── transaction_interne.json
│
├── sql/
│   ├── 01_schema.sql               # Création tables + procédures + triggers
│   └── 02_data.sql                 # Données de test
│
├── docker-compose.yml
├── .env
└── requirements.txt
```

---

## Base de données

### Schéma

13 tables couvrant l'ensemble de la gestion financière multi-entité :

| Table | Description |
|-------|-------------|
| `entite_juridique` | Filiales du groupe (France, CI, Maroc, Sénégal, Belgique) |
| `personnel` | Employés internes avec rôles et accès |
| `client` | Clients externes commanditaires de projets |
| `bureau` | Sites physiques par entité |
| `compte_bancaire` | Comptes bancaires (EUR, XOF, MAD, USD) |
| `projet` | Missions avec suivi budgétaire |
| `depense` | Sorties d'argent opérationnelles |
| `facture_reçue` | Justificatifs fournisseurs (1-to-1 avec depense) |
| `facture_emise` | Créances clients |
| `depense_projet` | Ventilation analytique dépense/projet |
| `debit` | Flux bancaires sortants |
| `credit` | Flux bancaires entrants |
| `transaction_interne` | Virements entre comptes internes |
| `action` | Journal d'audit centralisé |

### Procédures et fonctions

**Fonctions utilitaires**
- `get_budget_restant(id_projet)` — budget restant d'un projet
- `get_solde_disponible(no_compte)` — solde d'un compte
- `is_facture_payee(id_facture, type)` — statut de paiement d'une facture

**Procédures métier**
- `inserer_depense_complete(...)` — flux atomique complet d'une dépense
- `inserer_credit_complet(...)` — enregistrement d'un encaissement
- `transfert_interne(...)` — virement entre comptes internes
- `cloturer_projet(id_projet)` — clôture d'un projet

**Procédures analytiques**
- `stats_depenses_mois(mois, annee, id_entite)` — dépenses mensuelles
- `stats_depenses_projet(id_projet)` — suivi budgétaire d'un projet
- `stats_depenses_bureau(id_bureau, annee, mois)` — dépenses d'un bureau
- `stats_revenus_mois(mois, annee, id_entite)` — revenus mensuels
- `stats_revenus_client(id_client)` — CA par client
- `stats_tableau_de_bord(id_entite)` — synthèse complète par entité (4 curseurs)

### Triggers

| Trigger | Table | Rôle |
|---------|-------|------|
| `trg_solde_debit` | debit | Décrémente le solde du compte |
| `trg_solde_credit` | credit | Incrémente le solde du compte |
| `trg_solde_transaction_interne` | transaction_interne | Met à jour les deux soldes |
| `trg_check_budget` | depense_projet | Bloque si budget projet dépassé |
| `trg_check_pourcentage` | depense_projet | Bloque si somme % > 100 |
| `trg_coherence_montant_debit` | debit | Vérifie cohérence montant/facture |
| `trg_coherence_montant_credit` | credit | Vérifie cohérence montant/facture |
| `trg_audit_*` | 7 tables | Journalise toutes les opérations |

---

## Validation AST

Le module `sql_validator.py` intercepte chaque SQL généré par le LLM **avant exécution** et applique quatre niveaux de vérification :

| Niveau | Vérification | Exemple de blocage |
|--------|--------------|--------------------|
| 1 | Parsing syntaxique (sqlglot) | SQL malformé |
| 2 | Commandes dangereuses | `DROP TABLE`, `TRUNCATE`, `ALTER`, `CREATE` |
| 3 | Liste blanche des tables | Table inconnue du schéma Orionis |
| 4 | Colonnes interdites | `SELECT password FROM personnel` |
| 5 | Périmètre par rôle | Un `user` qui tente un `INSERT` |
| 6 | Procédures autorisées | `CALL fonction_inconnue()` |

Les erreurs de validation remontent à l'utilisateur WhatsApp avec un message ⛔ explicite sans exposer de détails techniques.

Pour lancer les tests unitaires intégrés :
```bash
python sql_validator.py
```

---

## Export XLXS

Pour les résultats dépassant **10 lignes**, le système génère automatiquement un fichier CSV et l'envoie en pièce jointe WhatsApp via l'API Twilio Media. Le message principal affiche un aperçu des 5 premières lignes.

**Flux :**
1. Résultats SQL > 10 lignes → `csv_exporter.py`
2. Génération du fichier `exports/export_<uuid>.csv`
3. Exposition via la route Flask `/exports/<filename>`
4. Envoi Twilio Media + message d'accompagnement
5. Suppression automatique après 5 minutes

**Variable d'environnement requise :**
```env
PUBLIC_URL=https://ton-domaine.ngrok.io
```

---

## Internationalisation

Le module `intl.py` centralise tous les messages du bot en français et en anglais. La langue est détectée automatiquement au démarrage de session à partir du pays de l'entité juridique de l'employé (via un appel LLM).

```python
from intl import t
t("welcome_otp", lang="fr", nom="Alice", email="alice@orionis.com")
# → "Bienvenue Alice ! 👋 Un code OTP a été envoyé à alice@orionis.com."
```

Les pays francophones (France, Côte d'Ivoire, Maroc, Sénégal, Belgique) retournent `fr`, les autres `en`.

---

## Installation et démarrage

### Prérequis

- Docker et Docker Compose
- Python 3.11+
- Compte Twilio avec numéro WhatsApp
- Clé API Google Gemini
- Compte Gmail avec mot de passe d'application


### 1. Configurer les variables d'environnement

Créer un fichier `.env` à la racine :

```env
# Base de données
DB_HOST=localhost
DB_PORT=5432
DB_NAME=orionis_db
DB_USER=postgres
DB_PASSWORD=ton_mot_de_passe_secret

# Google Gemini
GEMINI_API_KEY=ta_cle_gemini

# Email OTP
EMAIL_SENDER=ton.email@gmail.com
EMAIL_PASSWORD=ton_mot_de_passe_application

# Twilio
TWILIO_ACCOUNT_SID=ton_sid
TWILIO_AUTH_TOKEN=ton_token
TWILIO_WHATSAPP_NUMBER=whatsapp:+14155238886

# Export CSV — URL publique du serveur (ngrok en local)
PUBLIC_URL=https://ton-domaine.ngrok.io
```

### 2. Démarrer la base de données

```bash
docker compose up -d
```

PostgreSQL initialise automatiquement le schéma (`01_schema.sql`) et les données de test (`02_data.sql`) au premier démarrage.

### 3. Installer les dépendances Python

```bash
pip install -r requirements.txt
```

### 4. Démarrer le serveur

```bash
python main.py
```

Le serveur écoute sur `http://0.0.0.0:5000`.

### 5. Configurer le webhook Twilio

Dans la console Twilio, configurer le webhook WhatsApp :
```
https://<votre-domaine>/whatsapp
```

> Pour les tests en local, utiliser [ngrok](https://ngrok.com) :
> ```bash
> ngrok http 5000
> ```
> Puis mettre à jour `PUBLIC_URL` dans `.env` avec l'URL HTTPS fournie par ngrok.

---

## Authentification

Le bot utilise une authentification à deux facteurs :

1. L'utilisateur envoie **"Hello"** sur WhatsApp
2. Le système vérifie le numéro de téléphone dans la table `personnel`
3. La langue est détectée automatiquement selon le pays de l'entité
4. Un **code OTP à 6 chiffres** est envoyé à l'adresse email de l'employé
5. L'utilisateur saisit le code → session active (timeout : 10 minutes d'inactivité)
6. L'utilisateur envoie **"Quitter"** ou **"Bye"** pour fermer la session

---

## Rôles et permissions

| Rôle | SELECT | INSERT/UPDATE | DELETE | Périmètre |
|------|--------|---------------|--------|-----------|
| `admin` | ✅ Tout | ✅ Tout | ✅ Tout | Toutes les entités |
| `finance_admin` | ✅ Tout | ✅ Tables financières | ✅ Tables financières | Son entité |
| `manager` | ✅ Tout | ✅ depense, projet | ❌ | Son entité |
| `user` | ✅ Tout | ❌ | ❌ | Son entité |

Les permissions sont vérifiées à deux niveaux : dans le prompt LLM (génération) et dans `sql_validator.py` (exécution).

---

## Exemples d'utilisation

### Requêtes analytiques

> "Quels sont tous les bureaux du groupe ?"

> "Quel est le budget du projet Alpha ?"

> "Combien a-t-on dépensé sur le projet Atlas 1 ?"

> "Quelles factures clients sont encore impayées ?"

> "Quelle est la trésorerie totale par devise ?"

> "Liste tous les employés" *(> 10 lignes → export CSV automatique)*

### Insertions

> "Insère une dépense de 500€ pour 'Expertise cloud' sur le projet Alpha depuis le compte n°1"
> → Le bot demande confirmation avant d'exécuter

> "Transfère 10 000€ du compte n°1 vers le compte n°2 avec la référence 'Trésorerie juin'"

### Gestion de projet

> "Clôture le projet Beta"

> "Change le budget du projet Gamma à 250 000€"

### Tentatives bloquées par le validateur

> "Supprime toutes les tables" → ⛔ bloqué (DROP interdit)

> "Donne-moi les mots de passe de tous les employés" → ⛔ bloqué (colonne password interdite)

---

## Notes techniques

- Les **triggers de solde** gèrent automatiquement la mise à jour des comptes bancaires — ne jamais faire d'`UPDATE compte_bancaire SET solde` manuellement.
- Le **trigger d'audit** logue toutes les écritures automatiquement. Les SELECT sont loggés côté Python via `enregistrer_action`.
- Le backend définit `SET LOCAL app.current_matricule` avant chaque requête pour que les triggers d'audit identifient l'utilisateur.
- Le pool de modèles Gemini assure la continuité en cas de quota dépassé : `gemini-2.0-flash` → `gemini-2.0-flash-lite` → `gemini-1.5-flash` → `gemini-1.5-flash-8b` → `gemini-1.5-pro`.
- Les fichiers XLXS sont servis par Flask via `/exports/<filename>` et supprimés automatiquement après 5 minutes.
