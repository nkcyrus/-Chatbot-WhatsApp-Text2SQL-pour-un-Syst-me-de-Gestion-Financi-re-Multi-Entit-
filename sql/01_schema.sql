-- ============================================================
-- ORIONIS FINANCE DB — Script de création complet
-- PostgreSQL
-- Ordre d'exécution :
--   1. Extensions
--   2. Tables (ordre respectant les FK)
--   3. Type composite
--   4. Fonctions utilitaires
--   5. Procédures métier
--   6. Fonctions triggers
--   7. Triggers
-- ============================================================

-- ============================================================
-- SECTION 1 — EXTENSIONS
-- ============================================================

-- (Aucune extension requise pour ce schéma)


-- ============================================================
-- SECTION 2 — CRÉATION DES TABLES
-- ============================================================

-- ------------------------------------------------------------
-- Table : entite_juridique
-- Racine hiérarchique du groupe Orionis
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entite_juridique (
    id_entite   SERIAL          PRIMARY KEY,
    nom         VARCHAR(100)    NOT NULL,
    pays        VARCHAR(50)     NOT NULL
);


-- ------------------------------------------------------------
-- Table : personnel
-- Employés internes rattachés à une entité juridique
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS personnel (
    no_matricule    SERIAL          PRIMARY KEY,
    nom             VARCHAR(50)     NOT NULL,
    prenom          VARCHAR(50)     NOT NULL,
    email           VARCHAR(100)    UNIQUE NOT NULL,
    telephone       VARCHAR(20),
    role            VARCHAR(20)     NOT NULL DEFAULT 'user',
    password        VARCHAR(255)    NOT NULL,
    id_entite       INTEGER         NOT NULL,
    CONSTRAINT fk_personnel_entite FOREIGN KEY (id_entite)
        REFERENCES entite_juridique(id_entite) ON DELETE RESTRICT
);


-- ------------------------------------------------------------
-- Table : client
-- Clients externes commanditaires de projets
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS client (
    id_client   SERIAL          PRIMARY KEY,
    nom         VARCHAR(100)    NOT NULL,
    prenom      VARCHAR(100),
    adresse     VARCHAR(255),
    email       VARCHAR(100)    UNIQUE
);


-- ------------------------------------------------------------
-- Table : bureau
-- Sites physiques rattachés à une entité juridique
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bureau (
    id_bureau   SERIAL          PRIMARY KEY,
    nom         VARCHAR(100)    NOT NULL,
    adresse     VARCHAR(255),
    id_entite   INTEGER         NOT NULL,
    CONSTRAINT fk_bureau_entite FOREIGN KEY (id_entite)
        REFERENCES entite_juridique(id_entite) ON DELETE RESTRICT
);


-- ------------------------------------------------------------
-- Table : compte_bancaire
-- Comptes bancaires internes par entité juridique
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS compte_bancaire (
    no_compte   SERIAL              PRIMARY KEY,
    intitule    VARCHAR(100)        NOT NULL,
    solde       DECIMAL(15,2)       NOT NULL DEFAULT 0.00,
    devise      VARCHAR(3)          NOT NULL DEFAULT 'EUR',
    id_entite   INTEGER             NOT NULL,
    CONSTRAINT fk_compte_entite FOREIGN KEY (id_entite)
        REFERENCES entite_juridique(id_entite) ON DELETE RESTRICT,
    CONSTRAINT chk_solde_positif CHECK (solde >= 0)
);


-- ------------------------------------------------------------
-- Table : projet
-- Missions commandées par des clients, réalisées par des entités
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS projet (
    id_projet   SERIAL          PRIMARY KEY,
    nom         VARCHAR(100)    NOT NULL,
    description TEXT,
    budget      DECIMAL(15,2)   NOT NULL DEFAULT 0.00,
    date_debut  DATE,
    date_fin    DATE,
    id_entite   INTEGER         NOT NULL,
    id_client   INTEGER,
    CONSTRAINT fk_projet_entite FOREIGN KEY (id_entite)
        REFERENCES entite_juridique(id_entite) ON DELETE RESTRICT,
    CONSTRAINT fk_projet_client FOREIGN KEY (id_client)
        REFERENCES client(id_client) ON DELETE SET NULL,
    CONSTRAINT chk_dates_projet CHECK (date_fin IS NULL OR date_fin >= date_debut)
);


-- ------------------------------------------------------------
-- Table : facture_emise
-- Factures émises aux clients (créances)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS facture_emise (
    id_facture  SERIAL          PRIMARY KEY,
    date        DATE            NOT NULL DEFAULT CURRENT_DATE,
    montant     DECIMAL(15,2)   NOT NULL,
    id_client   INTEGER         NOT NULL,
    CONSTRAINT fk_facture_emise_client FOREIGN KEY (id_client)
        REFERENCES client(id_client) ON DELETE RESTRICT,
    CONSTRAINT chk_montant_facture_emise CHECK (montant > 0)
);


-- ------------------------------------------------------------
-- Table : depense
-- Sorties d'argent opérationnelles (projet ou bureau)
-- La relation vers facture_reçue est portée par facture_reçue.id_depense
-- (pas de FK circulaire ici)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS depense (
    id_depense  SERIAL          PRIMARY KEY,
    libelle     VARCHAR(100)    NOT NULL,
    categorie   VARCHAR(100)    NOT NULL DEFAULT 'projet',
    montant     DECIMAL(15,2)   NOT NULL,
    devise      VARCHAR(3)      NOT NULL DEFAULT 'EUR',
    date        DATE            NOT NULL DEFAULT CURRENT_DATE,
    id_bureau   INTEGER,
    CONSTRAINT fk_depense_bureau FOREIGN KEY (id_bureau)
        REFERENCES bureau(id_bureau) ON DELETE SET NULL,
    CONSTRAINT chk_montant_depense CHECK (montant > 0),
    CONSTRAINT chk_categorie CHECK (categorie IN ('projet', 'bureau'))
);


-- ------------------------------------------------------------
-- Table : facture_recue
-- Factures fournisseurs justifiant chaque dépense
-- Relation 1-to-1 avec depense via id_depense (sens unique, pas de cycle)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS facture_reçue (
    id_facture  SERIAL          PRIMARY KEY,
    montant     DECIMAL(15,2)   NOT NULL,
    date        DATE            NOT NULL DEFAULT CURRENT_DATE,
    id_depense  INTEGER         NOT NULL UNIQUE,
    CONSTRAINT fk_facture_recue_depense FOREIGN KEY (id_depense)
        REFERENCES depense(id_depense) ON DELETE CASCADE,
    CONSTRAINT chk_montant_facture_recue CHECK (montant > 0)
);


-- ------------------------------------------------------------
-- Table : depense_projet
-- Table de liaison analytique : ventilation dépense/projet
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS depense_projet (
    id_depense_projet   SERIAL      PRIMARY KEY,
    id_depense          INTEGER     NOT NULL,
    id_projet           INTEGER     NOT NULL,
    pourcentage         INTEGER     NOT NULL,
    CONSTRAINT fk_dp_depense FOREIGN KEY (id_depense)
        REFERENCES depense(id_depense) ON DELETE CASCADE,
    CONSTRAINT fk_dp_projet FOREIGN KEY (id_projet)
        REFERENCES projet(id_projet) ON DELETE RESTRICT,
    CONSTRAINT chk_pourcentage CHECK (pourcentage BETWEEN 1 AND 100),
    CONSTRAINT uq_depense_projet UNIQUE (id_depense, id_projet)
);


-- ------------------------------------------------------------
-- Table : debit
-- Flux bancaires sortants (paiements fournisseurs)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS debit (
    id_transaction      SERIAL          PRIMARY KEY,
    montant             DECIMAL(15,2)   NOT NULL,
    reference           VARCHAR(50),
    date                DATE            NOT NULL DEFAULT CURRENT_DATE,
    no_compte           VARCHAR(34),    -- IBAN fournisseur (informatif)
    no_compte_debit     INTEGER         NOT NULL,
    id_facture          INTEGER         NOT NULL,
    CONSTRAINT fk_debit_compte FOREIGN KEY (no_compte_debit)
        REFERENCES compte_bancaire(no_compte) ON DELETE RESTRICT,
    CONSTRAINT fk_debit_facture FOREIGN KEY (id_facture)
        REFERENCES facture_reçue(id_facture) ON DELETE RESTRICT,
    CONSTRAINT chk_montant_debit CHECK (montant > 0)
);


-- ------------------------------------------------------------
-- Table : credit
-- Flux bancaires entrants (encaissements clients)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS credit (
    id_transaction      SERIAL          PRIMARY KEY,
    montant             DECIMAL(15,2)   NOT NULL,
    reference           VARCHAR(50),
    date                DATE            NOT NULL DEFAULT CURRENT_DATE,
    no_compte           INTEGER,        -- Compte externe client (informatif)
    no_compte_credit    INTEGER         NOT NULL,
    id_facture          INTEGER         NOT NULL,
    CONSTRAINT fk_credit_compte FOREIGN KEY (no_compte_credit)
        REFERENCES compte_bancaire(no_compte) ON DELETE RESTRICT,
    CONSTRAINT fk_credit_facture FOREIGN KEY (id_facture)
        REFERENCES facture_emise(id_facture) ON DELETE RESTRICT,
    CONSTRAINT chk_montant_credit CHECK (montant > 0)
);


-- ------------------------------------------------------------
-- Table : transaction_interne
-- Virements entre comptes bancaires internes
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transaction_interne (
    id_transaction          SERIAL          PRIMARY KEY,
    montant                 DECIMAL(15,2)   NOT NULL,
    reference               VARCHAR(50),
    date                    DATE            NOT NULL DEFAULT CURRENT_DATE,
    no_compte_recepteur     INTEGER         NOT NULL,
    no_compte_expediteur    INTEGER         NOT NULL,
    CONSTRAINT fk_ti_recepteur FOREIGN KEY (no_compte_recepteur)
        REFERENCES compte_bancaire(no_compte) ON DELETE RESTRICT,
    CONSTRAINT fk_ti_expediteur FOREIGN KEY (no_compte_expediteur)
        REFERENCES compte_bancaire(no_compte) ON DELETE RESTRICT,
    CONSTRAINT chk_montant_ti CHECK (montant > 0),
    CONSTRAINT chk_comptes_differents CHECK (no_compte_expediteur <> no_compte_recepteur)
);


-- ------------------------------------------------------------
-- Table : action
-- Journal d'audit centralisé
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS action (
    id_action       SERIAL          PRIMARY KEY,
    type            VARCHAR(50)     NOT NULL,
    description     TEXT,
    date_action     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    statut          VARCHAR(20)     NOT NULL DEFAULT 'SUCCES',
    no_matricule    INTEGER         NOT NULL,
    CONSTRAINT fk_action_personnel FOREIGN KEY (no_matricule)
        REFERENCES personnel(no_matricule) ON DELETE RESTRICT,
    CONSTRAINT chk_statut CHECK (statut IN ('SUCCES', 'ECHEC'))
);


-- ============================================================
-- SECTION 3 — TYPE COMPOSITE (requis avant les procédures)
-- ============================================================

DO $$ BEGIN
    CREATE TYPE ventilation_projet AS (
        id_projet   INTEGER,
        pourcentage INTEGER
    );
EXCEPTION
    WHEN duplicate_object THEN NULL; -- Ignore si déjà existant
END $$;


-- ============================================================
-- SECTION 4 — FONCTIONS UTILITAIRES
-- (référencées par les procédures et triggers)
-- ============================================================

-- ------------------------------------------------------------
-- FONCTION : get_budget_restant
-- Retourne le budget restant d'un projet
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_budget_restant(p_id_projet INTEGER)
RETURNS DECIMAL(15,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_budget        DECIMAL(15,2);
    v_total_depense DECIMAL(15,2);
BEGIN
    SELECT budget INTO v_budget
    FROM projet
    WHERE id_projet = p_id_projet;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Projet % introuvable.', p_id_projet;
    END IF;

    SELECT COALESCE(SUM(d.montant * dp.pourcentage / 100.0), 0)
    INTO v_total_depense
    FROM depense d
    JOIN depense_projet dp ON d.id_depense = dp.id_depense
    WHERE dp.id_projet = p_id_projet;

    RETURN v_budget - v_total_depense;
END;
$$;


-- ------------------------------------------------------------
-- FONCTION : get_solde_disponible
-- Retourne le solde actuel d'un compte bancaire
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_solde_disponible(p_no_compte INTEGER)
RETURNS DECIMAL(15,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_solde DECIMAL(15,2);
BEGIN
    SELECT solde INTO v_solde
    FROM compte_bancaire
    WHERE no_compte = p_no_compte;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Compte bancaire % introuvable.', p_no_compte;
    END IF;

    RETURN v_solde;
END;
$$;


-- ------------------------------------------------------------
-- FONCTION : is_facture_payee
-- Vérifie si une facture est réglée
-- p_type : 'emise' ou 'recue'
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION is_facture_payee(p_id_facture INTEGER, p_type VARCHAR(10))
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_existe BOOLEAN;
BEGIN
    IF p_type = 'emise' THEN
        SELECT EXISTS (
            SELECT 1 FROM credit WHERE id_facture = p_id_facture
        ) INTO v_existe;
    ELSIF p_type = 'recue' THEN
        SELECT EXISTS (
            SELECT 1 FROM debit WHERE id_facture = p_id_facture
        ) INTO v_existe;
    ELSE
        RAISE EXCEPTION 'Type de facture invalide : %. Utiliser ''emise'' ou ''recue''.', p_type;
    END IF;

    RETURN v_existe;
END;
$$;


-- ============================================================
-- SECTION 5 — PROCÉDURES MÉTIER
-- ============================================================

-- ------------------------------------------------------------
-- PROCÉDURE : inserer_depense_complete
-- Flux atomique : facture_reçue + depense + depense_projet + debit
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE inserer_depense_complete(
    p_libelle       VARCHAR(100),
    p_montant       DECIMAL(15,2),
    p_devise        VARCHAR(3),
    p_date          DATE,
    p_no_compte     INTEGER,
    p_ventilation   ventilation_projet[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_facture        INTEGER;
    v_id_depense        INTEGER;
    v_total_pct         INTEGER := 0;
    v_budget_restant    DECIMAL(15,2);
    v_item              ventilation_projet;
    v_solde             DECIMAL(15,2);
BEGIN
    IF array_length(p_ventilation, 1) IS NULL THEN
        RAISE EXCEPTION 'La ventilation projet est obligatoire.';
    END IF;

    FOREACH v_item IN ARRAY p_ventilation LOOP
        v_total_pct := v_total_pct + v_item.pourcentage;
    END LOOP;
    IF v_total_pct <> 100 THEN
        RAISE EXCEPTION 'La somme des pourcentages doit être égale à 100. Valeur reçue : %', v_total_pct;
    END IF;

    v_solde := get_solde_disponible(p_no_compte);
    IF v_solde < p_montant THEN
        RAISE EXCEPTION 'Solde insuffisant sur le compte %. Solde : %, Montant : %', p_no_compte, v_solde, p_montant;
    END IF;

    FOREACH v_item IN ARRAY p_ventilation LOOP
        v_budget_restant := get_budget_restant(v_item.id_projet);
        IF v_budget_restant < (p_montant * v_item.pourcentage / 100.0) THEN
            RAISE EXCEPTION 'Budget insuffisant pour le projet %. Budget restant : %, Montant imputé : %',
                v_item.id_projet, v_budget_restant, (p_montant * v_item.pourcentage / 100.0);
        END IF;
    END LOOP;

    -- 1. Insérer la dépense
    INSERT INTO depense (libelle, categorie, montant, devise, date)
    VALUES (p_libelle, 'projet', p_montant, p_devise, p_date)
    RETURNING id_depense INTO v_id_depense;

    -- 2. Insérer la facture reçue (liée à la dépense via id_depense)
    -- Pas de FK retour vers depense — la relation est portée par facture_reçue.id_depense
    INSERT INTO facture_reçue (montant, date, id_depense)
    VALUES (p_montant, p_date, v_id_depense)
    RETURNING id_facture INTO v_id_facture;

    -- 3. Insérer les ventilations projet
    FOREACH v_item IN ARRAY p_ventilation LOOP
        INSERT INTO depense_projet (id_depense, id_projet, pourcentage)
        VALUES (v_id_depense, v_item.id_projet, v_item.pourcentage);
    END LOOP;

    -- 4. Insérer le débit — trg_solde_debit met à jour le solde automatiquement
    INSERT INTO debit (montant, date, no_compte_debit, id_facture, reference)
    VALUES (p_montant, p_date, p_no_compte, v_id_facture, 'Dépense ' || p_libelle);

    RAISE NOTICE 'Dépense "%" de % % insérée avec succès (id_depense=%, id_facture=%).',
        p_libelle, p_montant, p_devise, v_id_depense, v_id_facture;
END;
$$;


-- ------------------------------------------------------------
-- PROCÉDURE : inserer_credit_complet
-- Enregistre un encaissement client
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE inserer_credit_complet(
    p_id_facture    INTEGER,
    p_no_compte     INTEGER,
    p_reference     VARCHAR(50),
    p_date          DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_montant_facture   DECIMAL(15,2);
    v_deja_payee        BOOLEAN;
BEGIN
    SELECT montant INTO v_montant_facture
    FROM facture_emise
    WHERE id_facture = p_id_facture;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Facture émise % introuvable.', p_id_facture;
    END IF;

    v_deja_payee := is_facture_payee(p_id_facture, 'emise');
    IF v_deja_payee THEN
        RAISE EXCEPTION 'La facture émise % est déjà réglée.', p_id_facture;
    END IF;

    PERFORM get_solde_disponible(p_no_compte);

    -- trg_solde_credit met à jour le solde automatiquement
    INSERT INTO credit (montant, date, no_compte_credit, id_facture, reference)
    VALUES (v_montant_facture, p_date, p_no_compte, p_id_facture, p_reference);

    RAISE NOTICE 'Encaissement de % enregistré pour la facture % sur le compte %.',
        v_montant_facture, p_id_facture, p_no_compte;
END;
$$;


-- ------------------------------------------------------------
-- PROCÉDURE : transfert_interne
-- Virement entre deux comptes internes
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE transfert_interne(
    p_no_compte_exp     INTEGER,
    p_no_compte_rec     INTEGER,
    p_montant           DECIMAL(15,2),
    p_reference         VARCHAR(50),
    p_date              DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_solde_exp DECIMAL(15,2);
BEGIN
    IF p_no_compte_exp = p_no_compte_rec THEN
        RAISE EXCEPTION 'Le compte expéditeur et le compte récepteur doivent être différents.';
    END IF;

    IF p_montant <= 0 THEN
        RAISE EXCEPTION 'Le montant doit être strictement supérieur à 0. Valeur reçue : %', p_montant;
    END IF;

    v_solde_exp := get_solde_disponible(p_no_compte_exp);
    IF v_solde_exp < p_montant THEN
        RAISE EXCEPTION 'Solde insuffisant sur le compte expéditeur %. Solde : %, Montant : %',
            p_no_compte_exp, v_solde_exp, p_montant;
    END IF;

    PERFORM get_solde_disponible(p_no_compte_rec);

    -- trg_solde_transaction_interne met à jour les deux soldes automatiquement
    INSERT INTO transaction_interne (montant, reference, date, no_compte_expediteur, no_compte_recepteur)
    VALUES (p_montant, p_reference, p_date, p_no_compte_exp, p_no_compte_rec);

    RAISE NOTICE 'Transfert de % effectué du compte % vers le compte % (ref: %).',
        p_montant, p_no_compte_exp, p_no_compte_rec, p_reference;
END;
$$;


-- ------------------------------------------------------------
-- PROCÉDURE : cloturer_projet
-- Marque un projet comme terminé
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE cloturer_projet(p_id_projet INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_nom       VARCHAR(100);
    v_date_fin  DATE;
BEGIN
    SELECT nom, date_fin INTO v_nom, v_date_fin
    FROM projet
    WHERE id_projet = p_id_projet;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Projet % introuvable.', p_id_projet;
    END IF;

    IF v_date_fin IS NOT NULL AND v_date_fin <= CURRENT_DATE THEN
        RAISE EXCEPTION 'Le projet "%" est déjà clôturé (date_fin = %).', v_nom, v_date_fin;
    END IF;

    UPDATE projet SET date_fin = CURRENT_DATE WHERE id_projet = p_id_projet;

    RAISE NOTICE 'Projet "%" clôturé avec succès (date_fin = %).', v_nom, CURRENT_DATE;
END;
$$;


-- ============================================================
-- SECTION 6 — FONCTIONS TRIGGERS
-- ============================================================

-- ------------------------------------------------------------
-- fn_solde_debit : décrémente solde après INSERT dans debit
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_solde_debit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_solde DECIMAL(15,2);
BEGIN
    SELECT solde INTO v_solde FROM compte_bancaire WHERE no_compte = NEW.no_compte_debit;
    IF v_solde < NEW.montant THEN
        RAISE EXCEPTION 'Solde insuffisant sur le compte %. Solde disponible : %, Montant du débit : %',
            NEW.no_compte_debit, v_solde, NEW.montant;
    END IF;
    UPDATE compte_bancaire SET solde = solde - NEW.montant WHERE no_compte = NEW.no_compte_debit;
    RETURN NEW;
END;
$$;


-- ------------------------------------------------------------
-- fn_solde_credit : incrémente solde après INSERT dans credit
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_solde_credit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE compte_bancaire SET solde = solde + NEW.montant WHERE no_compte = NEW.no_compte_credit;
    RETURN NEW;
END;
$$;


-- ------------------------------------------------------------
-- fn_solde_transaction_interne : met à jour les deux soldes
-- après INSERT dans transaction_interne
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_solde_transaction_interne()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_solde_exp DECIMAL(15,2);
BEGIN
    SELECT solde INTO v_solde_exp FROM compte_bancaire WHERE no_compte = NEW.no_compte_expediteur;
    IF v_solde_exp < NEW.montant THEN
        RAISE EXCEPTION 'Solde insuffisant sur le compte expéditeur %. Solde : %, Montant : %',
            NEW.no_compte_expediteur, v_solde_exp, NEW.montant;
    END IF;
    UPDATE compte_bancaire SET solde = solde - NEW.montant WHERE no_compte = NEW.no_compte_expediteur;
    UPDATE compte_bancaire SET solde = solde + NEW.montant WHERE no_compte = NEW.no_compte_recepteur;
    RETURN NEW;
END;
$$;


-- ------------------------------------------------------------
-- fn_check_budget : bloque INSERT si budget projet dépassé
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_budget()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_montant_depense   DECIMAL(15,2);
    v_montant_impute    DECIMAL(15,2);
    v_budget_restant    DECIMAL(15,2);
    v_nom_projet        VARCHAR(100);
BEGIN
    SELECT montant INTO v_montant_depense FROM depense WHERE id_depense = NEW.id_depense;
    v_montant_impute := v_montant_depense * NEW.pourcentage / 100.0;
    v_budget_restant := get_budget_restant(NEW.id_projet);
    SELECT nom INTO v_nom_projet FROM projet WHERE id_projet = NEW.id_projet;
    IF v_montant_impute > v_budget_restant THEN
        RAISE EXCEPTION 'Budget dépassé pour le projet "%" (id=%). Budget restant : %, Montant imputé : %',
            v_nom_projet, NEW.id_projet, v_budget_restant, v_montant_impute;
    END IF;
    RETURN NEW;
END;
$$;


-- ------------------------------------------------------------
-- fn_check_pourcentage : bloque si somme pourcentages > 100
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_pourcentage()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_total_existant INTEGER;
BEGIN
    SELECT COALESCE(SUM(pourcentage), 0) INTO v_total_existant
    FROM depense_projet WHERE id_depense = NEW.id_depense;
    IF v_total_existant + NEW.pourcentage > 100 THEN
        RAISE EXCEPTION 'La somme des pourcentages pour la dépense % dépasse 100. Total actuel : %, Ajout : %',
            NEW.id_depense, v_total_existant, NEW.pourcentage;
    END IF;
    RETURN NEW;
END;
$$;


-- ------------------------------------------------------------
-- fn_coherence_montant_debit : vérifie cohérence débit / facture_reçue
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_coherence_montant_debit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_montant_facture DECIMAL(15,2);
BEGIN
    SELECT montant INTO v_montant_facture FROM facture_reçue WHERE id_facture = NEW.id_facture;
    IF v_montant_facture IS NULL THEN
        RAISE EXCEPTION 'Facture reçue % introuvable.', NEW.id_facture;
    END IF;
    IF NEW.montant <> v_montant_facture THEN
        RAISE EXCEPTION 'Incohérence de montant : débit = %, facture reçue % = %',
            NEW.montant, NEW.id_facture, v_montant_facture;
    END IF;
    RETURN NEW;
END;
$$;


-- ------------------------------------------------------------
-- fn_coherence_montant_credit : vérifie cohérence crédit / facture_emise
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_coherence_montant_credit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_montant_facture DECIMAL(15,2);
BEGIN
    SELECT montant INTO v_montant_facture FROM facture_emise WHERE id_facture = NEW.id_facture;
    IF v_montant_facture IS NULL THEN
        RAISE EXCEPTION 'Facture émise % introuvable.', NEW.id_facture;
    END IF;
    IF NEW.montant <> v_montant_facture THEN
        RAISE EXCEPTION 'Incohérence de montant : crédit = %, facture émise % = %',
            NEW.montant, NEW.id_facture, v_montant_facture;
    END IF;
    RETURN NEW;
END;
$$;


-- ------------------------------------------------------------
-- fn_audit_action : journalise INSERT/UPDATE/DELETE sur tables métier
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_audit_action()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_type_action   VARCHAR(50);
    v_description   TEXT;
    v_no_matricule  INTEGER;
BEGIN
    v_type_action := TG_OP;

    BEGIN
        v_no_matricule := current_setting('app.current_matricule')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_no_matricule := NULL;
    END;

    IF TG_OP = 'DELETE' THEN
        v_description := TG_OP || ' sur ' || TG_TABLE_NAME;
    ELSE
        CASE TG_TABLE_NAME
            WHEN 'depense' THEN
                v_description := TG_OP || ' dépense "' || NEW.libelle || '" montant=' || NEW.montant;
            WHEN 'credit' THEN
                v_description := TG_OP || ' crédit montant=' || NEW.montant || ' facture=' || NEW.id_facture;
            WHEN 'debit' THEN
                v_description := TG_OP || ' débit montant=' || NEW.montant || ' facture=' || NEW.id_facture;
            WHEN 'transaction_interne' THEN
                v_description := TG_OP || ' transfert ' || NEW.montant
                    || ' compte ' || NEW.no_compte_expediteur || '→' || NEW.no_compte_recepteur;
            WHEN 'facture_emise' THEN
                v_description := TG_OP || ' facture émise montant=' || NEW.montant;
            WHEN 'facture_reçue' THEN
                v_description := TG_OP || ' facture reçue montant=' || NEW.montant;
            WHEN 'projet' THEN
                v_description := TG_OP || ' projet "' || NEW.nom || '"';
            ELSE
                v_description := TG_OP || ' sur ' || TG_TABLE_NAME;
        END CASE;
    END IF;

    IF v_no_matricule IS NOT NULL THEN
        INSERT INTO action (type, description, date_action, statut, no_matricule)
        VALUES (v_type_action, v_description, CURRENT_TIMESTAMP, 'SUCCES', v_no_matricule);
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;


-- ============================================================
-- SECTION 7 — CRÉATION DES TRIGGERS
-- ============================================================

-- Mise à jour des soldes
CREATE TRIGGER trg_solde_debit
    AFTER INSERT ON debit
    FOR EACH ROW EXECUTE FUNCTION fn_solde_debit();

CREATE TRIGGER trg_solde_credit
    AFTER INSERT ON credit
    FOR EACH ROW EXECUTE FUNCTION fn_solde_credit();

CREATE TRIGGER trg_solde_transaction_interne
    AFTER INSERT ON transaction_interne
    FOR EACH ROW EXECUTE FUNCTION fn_solde_transaction_interne();

-- Garde-fous métier
CREATE TRIGGER trg_check_budget
    BEFORE INSERT ON depense_projet
    FOR EACH ROW EXECUTE FUNCTION fn_check_budget();

CREATE TRIGGER trg_check_pourcentage
    BEFORE INSERT ON depense_projet
    FOR EACH ROW EXECUTE FUNCTION fn_check_pourcentage();

CREATE TRIGGER trg_coherence_montant_debit
    BEFORE INSERT ON debit
    FOR EACH ROW EXECUTE FUNCTION fn_coherence_montant_debit();

CREATE TRIGGER trg_coherence_montant_credit
    BEFORE INSERT ON credit
    FOR EACH ROW EXECUTE FUNCTION fn_coherence_montant_credit();

-- Audit
CREATE TRIGGER trg_audit_depense
    AFTER INSERT OR UPDATE OR DELETE ON depense
    FOR EACH ROW EXECUTE FUNCTION fn_audit_action();

CREATE TRIGGER trg_audit_credit
    AFTER INSERT OR UPDATE OR DELETE ON credit
    FOR EACH ROW EXECUTE FUNCTION fn_audit_action();

CREATE TRIGGER trg_audit_debit
    AFTER INSERT OR UPDATE OR DELETE ON debit
    FOR EACH ROW EXECUTE FUNCTION fn_audit_action();

CREATE TRIGGER trg_audit_transaction_interne
    AFTER INSERT OR UPDATE OR DELETE ON transaction_interne
    FOR EACH ROW EXECUTE FUNCTION fn_audit_action();

CREATE TRIGGER trg_audit_facture_emise
    AFTER INSERT OR UPDATE OR DELETE ON facture_emise
    FOR EACH ROW EXECUTE FUNCTION fn_audit_action();

CREATE TRIGGER trg_audit_facture_recue
    AFTER INSERT OR UPDATE OR DELETE ON facture_reçue
    FOR EACH ROW EXECUTE FUNCTION fn_audit_action();

CREATE TRIGGER trg_audit_projet
    AFTER INSERT OR UPDATE OR DELETE ON projet
    FOR EACH ROW EXECUTE FUNCTION fn_audit_action();
-- ============================================================
-- ORIONIS FINANCE DB — Procédures Analytiques PostgreSQL
-- ============================================================
-- Ces procédures retournent des jeux de résultats via REFCURSOR
-- pour être exploitables côté Python (psycopg2).
-- ============================================================


-- ------------------------------------------------------------
-- 1. PROCÉDURE : stats_depenses_mois
--    Total des dépenses d'un mois donné pour une entité
--    (ou toutes les entités si p_id_entite IS NULL)
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE stats_depenses_mois(
    p_mois      INTEGER,
    p_annee     INTEGER,
    p_id_entite INTEGER DEFAULT NULL,
    INOUT p_result REFCURSOR DEFAULT 'result'
)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN p_result FOR
        SELECT
            e.nom                           AS entite,
            e.pays                          AS pays,
            COUNT(d.id_depense)             AS nb_depenses,
            SUM(d.montant)                  AS total_depenses,
            d.devise                        AS devise,
            SUM(d.montant) FILTER (WHERE d.categorie = 'projet')  AS total_projets,
            SUM(d.montant) FILTER (WHERE d.categorie = 'bureau')  AS total_bureaux
        FROM depense d
        JOIN bureau b       ON d.id_bureau = b.id_bureau
        JOIN entite_juridique e ON b.id_entite = e.id_entite
        WHERE
            EXTRACT(MONTH FROM d.date) = p_mois
            AND EXTRACT(YEAR FROM d.date) = p_annee
            AND (p_id_entite IS NULL OR e.id_entite = p_id_entite)
        GROUP BY e.id_entite, e.nom, e.pays, d.devise
        ORDER BY total_depenses DESC;
END;
$$;


-- ------------------------------------------------------------
-- 2. PROCÉDURE : stats_depenses_projet
--    Suivi budgétaire complet d'un projet :
--    budget alloué, dépensé, restant, % consommé,
--    détail des dépenses par catégorie et par mois
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE stats_depenses_projet(
    p_id_projet INTEGER,
    INOUT p_result REFCURSOR DEFAULT 'result'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_nom_projet    VARCHAR(100);
BEGIN
    -- Vérifier que le projet existe
    SELECT nom INTO v_nom_projet FROM projet WHERE id_projet = p_id_projet;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Projet % introuvable.', p_id_projet;
    END IF;

    OPEN p_result FOR
        SELECT
            p.nom                                                       AS projet,
            p.budget                                                    AS budget_alloue,
            COALESCE(SUM(d.montant * dp.pourcentage / 100.0), 0)       AS total_depense,
            p.budget - COALESCE(SUM(d.montant * dp.pourcentage / 100.0), 0) AS budget_restant,
            ROUND(
                COALESCE(SUM(d.montant * dp.pourcentage / 100.0), 0)
                / NULLIF(p.budget, 0) * 100, 2
            )                                                           AS pct_consomme,
            p.date_debut,
            p.date_fin,
            CASE
                WHEN p.date_fin IS NULL OR p.date_fin > CURRENT_DATE THEN 'En cours'
                ELSE 'Clôturé'
            END                                                         AS statut
        FROM projet p
        LEFT JOIN depense_projet dp ON p.id_projet = dp.id_projet
        LEFT JOIN depense d         ON dp.id_depense = d.id_depense
        WHERE p.id_projet = p_id_projet
        GROUP BY p.id_projet, p.nom, p.budget, p.date_debut, p.date_fin;
END;
$$;


-- ------------------------------------------------------------
-- 3. PROCÉDURE : stats_depenses_bureau
--    Dépenses d'un bureau sur une période (mois/année)
--    Si p_mois IS NULL → toute l'année p_annee
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE stats_depenses_bureau(
    p_id_bureau INTEGER,
    p_annee     INTEGER,
    p_mois      INTEGER DEFAULT NULL,
    INOUT p_result REFCURSOR DEFAULT 'result'
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM bureau WHERE id_bureau = p_id_bureau) THEN
        RAISE EXCEPTION 'Bureau % introuvable.', p_id_bureau;
    END IF;

    OPEN p_result FOR
        SELECT
            b.nom                               AS bureau,
            e.nom                               AS entite,
            EXTRACT(MONTH FROM d.date)::INTEGER AS mois,
            EXTRACT(YEAR FROM d.date)::INTEGER  AS annee,
            COUNT(d.id_depense)                 AS nb_depenses,
            SUM(d.montant)                      AS total_depenses,
            d.devise                            AS devise,
            d.libelle                           AS libelle_depense
        FROM depense d
        JOIN bureau b           ON d.id_bureau = b.id_bureau
        JOIN entite_juridique e ON b.id_entite = e.id_entite
        WHERE
            d.id_bureau = p_id_bureau
            AND EXTRACT(YEAR FROM d.date) = p_annee
            AND (p_mois IS NULL OR EXTRACT(MONTH FROM d.date) = p_mois)
        GROUP BY b.nom, e.nom, EXTRACT(MONTH FROM d.date), EXTRACT(YEAR FROM d.date), d.devise, d.libelle
        ORDER BY annee, mois, total_depenses DESC;
END;
$$;


-- ------------------------------------------------------------
-- 4. PROCÉDURE : stats_revenus_mois
--    Total encaissé + factures en attente pour un mois donné
--    (ou toutes les entités si p_id_entite IS NULL)
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE stats_revenus_mois(
    p_mois      INTEGER,
    p_annee     INTEGER,
    p_id_entite INTEGER DEFAULT NULL,
    INOUT p_result REFCURSOR DEFAULT 'result'
)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN p_result FOR
        SELECT
            EXTRACT(MONTH FROM fe.date)::INTEGER    AS mois,
            EXTRACT(YEAR FROM fe.date)::INTEGER     AS annee,
            COUNT(fe.id_facture)                    AS nb_factures_emises,
            SUM(fe.montant)                         AS total_facture,
            SUM(fe.montant) FILTER (
                WHERE EXISTS (SELECT 1 FROM credit c WHERE c.id_facture = fe.id_facture)
            )                                       AS total_encaisse,
            SUM(fe.montant) FILTER (
                WHERE NOT EXISTS (SELECT 1 FROM credit c WHERE c.id_facture = fe.id_facture)
            )                                       AS total_en_attente,
            COUNT(fe.id_facture) FILTER (
                WHERE NOT EXISTS (SELECT 1 FROM credit c WHERE c.id_facture = fe.id_facture)
            )                                       AS nb_factures_impayees
        FROM facture_emise fe
        JOIN client cl      ON fe.id_client = cl.id_client
        LEFT JOIN projet pr ON cl.id_client = pr.id_client
        WHERE
            EXTRACT(MONTH FROM fe.date) = p_mois
            AND EXTRACT(YEAR FROM fe.date) = p_annee
            AND (p_id_entite IS NULL OR pr.id_entite = p_id_entite)
        GROUP BY EXTRACT(MONTH FROM fe.date), EXTRACT(YEAR FROM fe.date)
        ORDER BY annee, mois;
END;
$$;


-- ------------------------------------------------------------
-- 5. PROCÉDURE : stats_revenus_client
--    CA total par client + détail des factures payées/impayées
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE stats_revenus_client(
    p_id_client INTEGER,
    INOUT p_result REFCURSOR DEFAULT 'result'
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM client WHERE id_client = p_id_client) THEN
        RAISE EXCEPTION 'Client % introuvable.', p_id_client;
    END IF;

    OPEN p_result FOR
        SELECT
            cl.nom                                  AS client_nom,
            cl.prenom                               AS client_prenom,
            COUNT(fe.id_facture)                    AS nb_factures_total,
            SUM(fe.montant)                         AS ca_total,
            SUM(fe.montant) FILTER (
                WHERE EXISTS (SELECT 1 FROM credit c WHERE c.id_facture = fe.id_facture)
            )                                       AS ca_encaisse,
            SUM(fe.montant) FILTER (
                WHERE NOT EXISTS (SELECT 1 FROM credit c WHERE c.id_facture = fe.id_facture)
            )                                       AS ca_en_attente,
            COUNT(fe.id_facture) FILTER (
                WHERE NOT EXISTS (SELECT 1 FROM credit c WHERE c.id_facture = fe.id_facture)
            )                                       AS nb_factures_impayees,
            MAX(fe.date)                            AS derniere_facture
        FROM client cl
        JOIN facture_emise fe ON cl.id_client = fe.id_client
        WHERE cl.id_client = p_id_client
        GROUP BY cl.id_client, cl.nom, cl.prenom;
END;
$$;


-- ------------------------------------------------------------
-- 6. PROCÉDURE : stats_tableau_de_bord
--    Synthèse globale pour une entité :
--    trésorerie, dépenses du mois, revenus du mois,
--    projets actifs, alertes budget
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE stats_tableau_de_bord(
    p_id_entite INTEGER,
    INOUT p_tresorerie  REFCURSOR DEFAULT 'tresorerie',
    INOUT p_depenses    REFCURSOR DEFAULT 'depenses',
    INOUT p_revenus     REFCURSOR DEFAULT 'revenus',
    INOUT p_projets     REFCURSOR DEFAULT 'projets'
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM entite_juridique WHERE id_entite = p_id_entite) THEN
        RAISE EXCEPTION 'Entité % introuvable.', p_id_entite;
    END IF;

    -- Curseur 1 : Trésorerie par compte
    OPEN p_tresorerie FOR
        SELECT
            cb.no_compte,
            cb.intitule,
            cb.solde,
            cb.devise
        FROM compte_bancaire cb
        WHERE cb.id_entite = p_id_entite
        ORDER BY cb.solde DESC;

    -- Curseur 2 : Dépenses du mois en cours
    OPEN p_depenses FOR
        SELECT
            COUNT(d.id_depense)             AS nb_depenses,
            SUM(d.montant)                  AS total_depenses,
            d.devise,
            SUM(d.montant) FILTER (WHERE d.categorie = 'projet') AS depenses_projets,
            SUM(d.montant) FILTER (WHERE d.categorie = 'bureau') AS depenses_bureaux
        FROM depense d
        JOIN bureau b ON d.id_bureau = b.id_bureau
        WHERE
            b.id_entite = p_id_entite
            AND date_trunc('month', d.date) = date_trunc('month', CURRENT_DATE)
        GROUP BY d.devise;

    -- Curseur 3 : Revenus du mois en cours
    OPEN p_revenus FOR
        SELECT
            COUNT(fe.id_facture)            AS nb_factures,
            SUM(fe.montant)                 AS total_facture,
            SUM(fe.montant) FILTER (
                WHERE EXISTS (SELECT 1 FROM credit c WHERE c.id_facture = fe.id_facture)
            )                               AS total_encaisse,
            SUM(fe.montant) FILTER (
                WHERE NOT EXISTS (SELECT 1 FROM credit c WHERE c.id_facture = fe.id_facture)
            )                               AS total_en_attente
        FROM facture_emise fe
        JOIN client cl  ON fe.id_client = cl.id_client
        JOIN projet pr  ON cl.id_client = pr.id_client
        WHERE
            pr.id_entite = p_id_entite
            AND date_trunc('month', fe.date) = date_trunc('month', CURRENT_DATE);

    -- Curseur 4 : Projets actifs avec alertes budget (>= 80% consommé)
    OPEN p_projets FOR
        SELECT
            p.nom                                                           AS projet,
            p.budget                                                        AS budget_alloue,
            COALESCE(SUM(d.montant * dp.pourcentage / 100.0), 0)           AS total_depense,
            p.budget - COALESCE(SUM(d.montant * dp.pourcentage / 100.0), 0) AS budget_restant,
            ROUND(
                COALESCE(SUM(d.montant * dp.pourcentage / 100.0), 0)
                / NULLIF(p.budget, 0) * 100, 2
            )                                                               AS pct_consomme,
            CASE
                WHEN COALESCE(SUM(d.montant * dp.pourcentage / 100.0), 0)
                     >= p.budget THEN '🔴 Budget dépassé'
                WHEN COALESCE(SUM(d.montant * dp.pourcentage / 100.0), 0)
                     >= p.budget * 0.8 THEN '🟠 Alerte budget (>80%)'
                ELSE '🟢 OK'
            END                                                             AS alerte
        FROM projet p
        LEFT JOIN depense_projet dp ON p.id_projet = dp.id_projet
        LEFT JOIN depense d         ON dp.id_depense = d.id_depense
        WHERE
            p.id_entite = p_id_entite
            AND (p.date_fin IS NULL OR p.date_fin >= CURRENT_DATE)
        GROUP BY p.id_projet, p.nom, p.budget
        ORDER BY pct_consomme DESC NULLS LAST;
END;
$$;