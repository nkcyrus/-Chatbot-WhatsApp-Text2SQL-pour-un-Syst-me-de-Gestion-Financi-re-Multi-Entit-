-- ============================================================
-- ORIONIS FINANCE DB — Données de test
-- ============================================================
-- Ordre d'insertion respectant les contraintes FK :
--   1. entite_juridique
--   2. personnel
--   3. client
--   4. bureau
--   5. compte_bancaire
--   6. projet
--   7. facture_emise
--   8. depense
--   9. facture_reçue
--  10. depense_projet
--  11. debit
--  12. credit
--  13. transaction_interne
-- ============================================================


-- ============================================================
-- 1. ENTITÉS JURIDIQUES
-- ============================================================
INSERT INTO entite_juridique (nom, pays) VALUES
    ('Orionis France SAS',          'France'),
    ('Orionis Côte d''Ivoire SARL', 'Côte d''Ivoire'),
    ('Orionis Maroc SA',            'Maroc'),
    ('Orionis Sénégal SUARL',       'Sénégal'),
    ('Orionis Belgique SRL',        'Belgique');


-- ============================================================
-- 2. PERSONNEL
-- ============================================================
INSERT INTO personnel (nom, prenom, email, telephone, role, password, id_entite) VALUES
-- France (id_entite = 1)
('Dupont',    'Alice',    'alice.dupont@orionis.com',     '+33611223344', 'admin',         'hashed_pwd_01', 1),
('Martin',    'Bruno',    'bruno.martin@orionis.com',     '+33622334455', 'finance_admin', 'hashed_pwd_02', 1),
('Lefebvre',  'Claire',   'claire.lefebvre@orionis.com',  '+33633445566', 'manager',       'hashed_pwd_03', 1),
('Bernard',   'David',    'david.bernard@orionis.com',    '+33644556677', 'manager',       'hashed_pwd_04', 1),
('Petit',     'Emma',     'emma.petit@orionis.com',       '+33655667788', 'user',          'hashed_pwd_05', 1),
('Noukpozounkou', 'Cyrus', 'sandrincyr@outlook.fr',       '+33755741384', 'admin',         'hashed_pwd_05', 1),
-- Côte d'Ivoire (id_entite = 2)
('Koné',      'Fatou',    'fatou.kone@orionis.com',       '+22507111222', 'finance_admin', 'hashed_pwd_06', 2),
('Diallo',    'Ibrahima', 'ibrahima.diallo@orionis.com',  '+22507222333', 'manager',       'hashed_pwd_07', 2),
('Touré',     'Aminata',  'aminata.toure@orionis.com',    '+22507333444', 'user',          'hashed_pwd_08', 2),
-- Maroc (id_entite = 3)
('El Fassi',  'Karim',    'karim.elfassi@orionis.com',    '+212661112233','finance_admin', 'hashed_pwd_09', 3),
('Benali',    'Nadia',    'nadia.benali@orionis.com',     '+212662223344','manager',       'hashed_pwd_10', 3),
('Cherkaoui', 'Omar',     'omar.cherkaoui@orionis.com',   '+212663334455','user',          'hashed_pwd_11', 3),
-- Sénégal (id_entite = 4)
('Ndiaye',    'Pape',     'pape.ndiaye@orionis.com',      '+221771112233','manager',       'hashed_pwd_12', 4),
('Sow',       'Rokhaya',  'rokhaya.sow@orionis.com',      '+221772223344','user',          'hashed_pwd_13', 4),
-- Belgique (id_entite = 5)
('Dubois',    'Sophie',   'sophie.dubois@orionis.com',    '+32477111222', 'finance_admin', 'hashed_pwd_14', 5),
('Lecomte',   'Thomas',   'thomas.lecomte@orionis.com',   '+32477222333', 'manager',       'hashed_pwd_15', 5),
('Renard',    'Ulysse',   'ulysse.renard@orionis.com',    '+32477333444', 'user',          'hashed_pwd_16', 5);


-- ============================================================
-- 3. CLIENTS
-- ============================================================
INSERT INTO client (nom, prenom, adresse, email) VALUES
('TechCorp',       NULL,       '15 Rue de la Paix, Paris, France',              'contact@techcorp.fr'),
('DataSoft',       NULL,       '8 Avenue des Champs-Élysées, Paris, France',    'info@datasoft.fr'),
('BuildGroup',     NULL,       '22 Rue du Commerce, Lyon, France',              'hello@buildgroup.fr'),
('AgroInvest',     NULL,       'Plateau, Abidjan, Côte d''Ivoire',              'contact@agroinvest.ci'),
('FinancePlus',    NULL,       'Quartier Hassan, Casablanca, Maroc',             'contact@financeplus.ma'),
('LogiTrans',      NULL,       'Almadies, Dakar, Sénégal',                      'info@logitrans.sn'),
('EnergieBrux',    NULL,       'Avenue Louise 54, Bruxelles, Belgique',         'contact@energiebrux.be'),
('GlobalConsult',  NULL,       '101 Avenue Montaigne, Paris, France',           'gc@globalconsult.fr'),
('MediaHub',       NULL,       'Zone Industrielle, Abidjan, Côte d''Ivoire',    'media@mediahub.ci'),
('SmartBuild',     NULL,       'Hay Riad, Rabat, Maroc',                        'info@smartbuild.ma');


-- ============================================================
-- 4. BUREAUX
-- ============================================================
INSERT INTO bureau (nom, adresse, id_entite) VALUES
-- France
('Paris Siège',      '19 Rue de Rivoli, 75001 Paris, France',          1),
('Lyon',             '45 Rue de la République, 69002 Lyon, France',    1),
('Marseille',        '3 Rue Paradis, 13001 Marseille, France',         1),
-- Côte d'Ivoire
('Abidjan Plateau',  'Immeuble Alpha, Plateau, Abidjan, CI',           2),
('Abidjan Cocody',   'Rue des Jardins, Cocody, Abidjan, CI',           2),
-- Maroc
('Casablanca',       'Boulevard Zerktouni, Casablanca, Maroc',         3),
('Rabat',            'Avenue Mohammed V, Rabat, Maroc',                3),
-- Sénégal
('Dakar',            'Almadies Route de Ngor, Dakar, Sénégal',         4),
-- Belgique
('Bruxelles',        'Avenue Louise 54, 1050 Bruxelles, Belgique',     5),
('Liège',            'Rue Léopold 12, 4000 Liège, Belgique',           5);


-- ============================================================
-- 5. COMPTES BANCAIRES
-- ============================================================
INSERT INTO compte_bancaire (intitule, solde, devise, id_entite) VALUES
-- France
('Compte Courant EUR France',     850000.00, 'EUR', 1),
('Compte Épargne EUR France',     300000.00, 'EUR', 1),
('Compte USD France',              75000.00, 'USD', 1),
-- Côte d'Ivoire
('Compte Courant XOF CI',        180000000, 'XOF', 2),
('Compte Épargne XOF CI',         60000000, 'XOF', 2),
-- Maroc
('Compte Courant MAD Maroc',      950000.00, 'MAD', 3),
('Compte USD Maroc',               45000.00, 'USD', 3),
-- Sénégal
('Compte Courant XOF Sénégal',    90000000, 'XOF', 4),
-- Belgique
('Compte Courant EUR Belgique',   420000.00, 'EUR', 5),
('Compte USD Belgique',            30000.00, 'USD', 5);


-- ============================================================
-- 6. PROJETS
-- ============================================================
INSERT INTO projet (nom, description, budget, date_debut, date_fin, id_entite, id_client) VALUES
-- France
('Projet Alpha',        'Développement plateforme SaaS pour TechCorp',         120000.00, '2025-01-15', NULL,         1, 1),
('Projet Beta',         'Audit et migration données pour DataSoft',              45000.00, '2025-03-01', '2025-09-30', 1, 2),
('Projet Gamma',        'Construction entrepôt logistique pour BuildGroup',     200000.00, '2025-02-01', NULL,         1, 3),
('Projet Delta',        'Conseil stratégique GlobalConsult',                     30000.00, '2025-06-01', '2025-12-31', 1, 8),
-- Côte d'Ivoire
('Projet Ivoire 1',     'Développement app mobile AgroInvest',                25000000,   '2025-04-01', NULL,         2, 4),
('Projet Ivoire 2',     'Infrastructure réseau MediaHub',                     15000000,   '2025-05-15', '2026-03-31', 2, 9),
-- Maroc
('Projet Atlas 1',      'Système de gestion financière FinancePlus',           800000.00, '2025-03-15', NULL,         3, 5),
('Projet Atlas 2',      'BTP résidentiel SmartBuild Rabat',                   1200000.00, '2025-07-01', NULL,         3, 10),
-- Sénégal
('Projet Teranga',      'Solution logistique LogiTrans',                      60000000,   '2025-05-01', NULL,         4, 6),
-- Belgique
('Projet Europa 1',     'Plateforme énergie renouvelable EnergieBrux',         550000.00, '2025-02-15', NULL,         5, 7),
('Projet Europa 2',     'Consulting digital TechCorp Belgique',                 80000.00, '2025-08-01', '2026-06-30', 5, 1);


-- ============================================================
-- 7. FACTURES ÉMISES (créances clients)
-- ============================================================
INSERT INTO facture_emise (date, montant, id_client) VALUES
-- TechCorp
('2025-03-01',  25000.00, 1),
('2025-06-15',  30000.00, 1),
('2025-09-01',  20000.00, 1),
-- DataSoft
('2025-04-01',  15000.00, 2),
('2025-07-01',  18000.00, 2),
-- BuildGroup
('2025-05-01',  50000.00, 3),
('2025-08-01',  60000.00, 3),
-- AgroInvest
('2025-06-01', 8000000,   4),
('2025-10-01', 6000000,   4),
-- FinancePlus
('2025-05-15', 200000.00, 5),
('2025-09-15', 250000.00, 5),
-- LogiTrans
('2025-07-01', 15000000,  6),
-- EnergieBrux
('2025-04-15', 100000.00, 7),
('2025-08-15', 120000.00, 7),
-- GlobalConsult
('2025-07-15',  10000.00, 8),
-- MediaHub
('2025-08-01',  5000000,  9),
-- SmartBuild
('2025-09-01', 300000.00, 10);


-- ============================================================
-- 8. DÉPENSES
-- ============================================================
INSERT INTO depense (libelle, categorie, montant, devise, date, id_bureau) VALUES
-- Dépenses bureau Paris Siège (id_bureau = 1)
('Loyer bureau Paris Q1',        'bureau', 15000.00, 'EUR', '2025-01-05',  1),
('Fournitures bureau Paris',     'bureau',  1200.00, 'EUR', '2025-02-10',  1),
('Électricité Paris T1',         'bureau',   850.00, 'EUR', '2025-03-31',  1),
('Loyer bureau Paris Q2',        'bureau', 15000.00, 'EUR', '2025-04-05',  1),
('Internet et téléphonie Paris', 'bureau',   600.00, 'EUR', '2025-05-01',  1),
('Loyer bureau Paris Q3',        'bureau', 15000.00, 'EUR', '2025-07-05',  1),
-- Dépenses bureau Lyon (id_bureau = 2)
('Loyer bureau Lyon Q1',         'bureau',  6000.00, 'EUR', '2025-01-05',  2),
('Matériel informatique Lyon',   'bureau',  3500.00, 'EUR', '2025-02-20',  2),
('Loyer bureau Lyon Q2',         'bureau',  6000.00, 'EUR', '2025-04-05',  2),
-- Dépenses bureau Abidjan Plateau (id_bureau = 4)
('Loyer Abidjan Plateau Q1',     'bureau', 1500000, 'XOF', '2025-01-05',  4),
('Climatisation Abidjan',        'bureau',  450000, 'XOF', '2025-02-15',  4),
('Loyer Abidjan Plateau Q2',     'bureau', 1500000, 'XOF', '2025-04-05',  4),
-- Dépenses bureau Casablanca (id_bureau = 6)
('Loyer Casablanca Q1',          'bureau', 18000.00, 'MAD', '2025-01-05', 6),
('Loyer Casablanca Q2',          'bureau', 18000.00, 'MAD', '2025-04-05', 6),
-- Dépenses bureau Bruxelles (id_bureau = 9)
('Loyer Bruxelles Q1',           'bureau', 12000.00, 'EUR', '2025-01-05', 9),
('Loyer Bruxelles Q2',           'bureau', 12000.00, 'EUR', '2025-04-05', 9),
-- Dépenses projets (catégorie projet, id_bureau NULL)
('Développement backend Alpha',  'projet',  18000.00, 'EUR', '2025-02-01', NULL),
('Développement frontend Alpha', 'projet',  12000.00, 'EUR', '2025-03-15', NULL),
('Tests et QA Alpha',            'projet',   5000.00, 'EUR', '2025-05-01', NULL),
('Hébergement cloud Alpha',      'projet',   3600.00, 'EUR', '2025-06-01', NULL),
('Audit données Beta',           'projet',  10000.00, 'EUR', '2025-03-10', NULL),
('Migration BDD Beta',           'projet',  14000.00, 'EUR', '2025-05-20', NULL),
('Études Gamma Phase 1',         'projet',  35000.00, 'EUR', '2025-03-01', NULL),
('Travaux Gamma Phase 1',        'projet',  80000.00, 'EUR', '2025-05-01', NULL),
('Conseil Delta',                'projet',  12000.00, 'EUR', '2025-07-01', NULL),
('Développement app Ivoire 1',   'projet', 7500000,  'XOF', '2025-05-01', NULL),
('Infra réseau Ivoire 2',        'projet', 4000000,  'XOF', '2025-06-15', NULL),
('Dev système Atlas 1',          'projet', 150000.00, 'MAD','2025-04-15', NULL),
('Paramétrage Atlas 1',          'projet', 200000.00, 'MAD','2025-07-01', NULL),
('Fondations Atlas 2',           'projet', 300000.00, 'MAD','2025-08-15', NULL),
('Logistique Teranga Phase 1',   'projet',12000000,  'XOF', '2025-06-01', NULL),
('Plateforme Europa 1 Dev',      'projet',  90000.00, 'EUR', '2025-04-01', NULL),
('Infra Europa 1',               'projet',  60000.00, 'EUR', '2025-06-15', NULL),
('Consulting Europa 2',          'projet',  25000.00, 'EUR', '2025-09-01', NULL);


-- ============================================================
-- 9. FACTURES REÇUES
-- Liées aux dépenses (relation 1-to-1 via id_depense)
-- On insère en respectant l'ordre des dépenses ci-dessus
-- id_depense va de 1 à 38
-- ============================================================
INSERT INTO facture_reçue (montant, date, id_depense) VALUES
-- Bureaux
(15000.00, '2025-01-04',  1),
( 1200.00, '2025-02-09',  2),
(  850.00, '2025-03-30',  3),
(15000.00, '2025-04-04',  4),
(  600.00, '2025-04-30',  5),
(15000.00, '2025-07-04',  6),
( 6000.00, '2025-01-04',  7),
( 3500.00, '2025-02-19',  8),
( 6000.00, '2025-04-04',  9),
(1500000,  '2025-01-04', 10),
( 450000,  '2025-02-14', 11),
(1500000,  '2025-04-04', 12),
(18000.00, '2025-01-04', 13),
(18000.00, '2025-04-04', 14),
(12000.00, '2025-01-04', 15),
(12000.00, '2025-04-04', 16),
-- Projets
(18000.00, '2025-01-31', 17),
(12000.00, '2025-03-14', 18),
( 5000.00, '2025-04-30', 19),
( 3600.00, '2025-05-31', 20),
(10000.00, '2025-03-09', 21),
(14000.00, '2025-05-19', 22),
(35000.00, '2025-02-28', 23),
(80000.00, '2025-04-30', 24),
(12000.00, '2025-06-30', 25),
(7500000,  '2025-04-30', 26),
(4000000,  '2025-06-14', 27),
(150000.00,'2025-04-14', 28),
(200000.00,'2025-06-30', 29),
(300000.00,'2025-08-14', 30),
(12000000, '2025-05-31', 31),
(90000.00, '2025-03-31', 32),
(60000.00, '2025-06-14', 33),
(25000.00, '2025-08-31', 34);

-- La relation depense ↔ facture_reçue est portée par facture_reçue.id_depense
-- Aucun UPDATE nécessaire — pas de dépendance circulaire.


-- ============================================================
-- 10. DEPENSE_PROJET
-- Ventilation des dépenses projets (id_depense 17 à 34)
-- ============================================================
INSERT INTO depense_projet (id_depense, id_projet, pourcentage) VALUES
-- Projet Alpha (id_projet=1) : dépenses 17,18,19,20
(17, 1, 100),
(18, 1, 100),
(19, 1, 100),
(20, 1, 100),
-- Projet Beta (id_projet=2) : dépenses 21,22
(21, 2, 100),
(22, 2, 100),
-- Projet Gamma (id_projet=3) : dépenses 23,24
(23, 3, 100),
(24, 3, 100),
-- Projet Delta (id_projet=4) : dépense 25
(25, 4, 100),
-- Projet Ivoire 1 (id_projet=5) : dépense 26
(26, 5, 100),
-- Projet Ivoire 2 (id_projet=6) : dépense 27
(27, 6, 100),
-- Projet Atlas 1 (id_projet=7) : dépenses 28,29 — répartie aussi sur Atlas 2
(28, 7, 100),
(29, 7,  70),
(29, 8,  30),
-- Projet Atlas 2 (id_projet=8) : dépense 30
(30, 8, 100),
-- Projet Teranga (id_projet=9) : dépense 31
(31, 9, 100),
-- Projet Europa 1 (id_projet=10) : dépenses 32,33
(32, 10, 100),
(33, 10, 100),
-- Projet Europa 2 (id_projet=11) : dépense 34
(34, 11, 100);


-- ============================================================
-- 11. DÉBITS
-- Paiements des factures reçues depuis les comptes internes
-- NOTE : les triggers désactivent la vérification de cohérence
--        montant déjà validé par les factures_reçues
-- ============================================================
INSERT INTO debit (montant, reference, date, no_compte_debit, id_facture) VALUES
-- Paiements depuis Compte Courant EUR France (no_compte=1)
(15000.00, 'VIR-LOYER-PAR-0125',  '2025-01-07',  1, 1),
( 1200.00, 'VIR-FOUR-PAR-0225',   '2025-02-12',  1, 2),
(  850.00, 'VIR-ELEC-PAR-0325',   '2025-04-02',  1, 3),
(15000.00, 'VIR-LOYER-PAR-0425',  '2025-04-07',  1, 4),
(  600.00, 'VIR-TEL-PAR-0525',    '2025-05-03',  1, 5),
(15000.00, 'VIR-LOYER-PAR-0725',  '2025-07-07',  1, 6),
( 6000.00, 'VIR-LOYER-LYO-0125',  '2025-01-07',  1, 7),
( 3500.00, 'VIR-MAT-LYO-0225',    '2025-02-21',  1, 8),
( 6000.00, 'VIR-LOYER-LYO-0425',  '2025-04-07',  1, 9),
(12000.00, 'VIR-LOYER-BRX-0125',  '2025-01-07',  9, 15),
(12000.00, 'VIR-LOYER-BRX-0425',  '2025-04-07',  9, 16),
-- Paiements dépenses projets France (depuis compte 1)
(18000.00, 'VIR-DEV-ALP-0225',    '2025-02-05',  1, 17),
(12000.00, 'VIR-DEV-ALP-0325',    '2025-03-18',  1, 18),
( 5000.00, 'VIR-QA-ALP-0525',     '2025-05-05',  1, 19),
( 3600.00, 'VIR-CLO-ALP-0625',    '2025-06-05',  1, 20),
(10000.00, 'VIR-AUD-BET-0325',    '2025-03-12',  1, 21),
(14000.00, 'VIR-MIG-BET-0525',    '2025-05-23',  1, 22),
(35000.00, 'VIR-ETU-GAM-0325',    '2025-03-05',  1, 23),
(80000.00, 'VIR-TRV-GAM-0525',    '2025-05-07',  1, 24),
(12000.00, 'VIR-CON-DEL-0725',    '2025-07-05',  1, 25),
-- Paiements Côte d'Ivoire (depuis compte 4 XOF)
(1500000,  'VIR-LOY-ABJ-0125',    '2025-01-07',  4, 10),
( 450000,  'VIR-CLI-ABJ-0225',    '2025-02-17',  4, 11),
(1500000,  'VIR-LOY-ABJ-0425',    '2025-04-07',  4, 12),
(7500000,  'VIR-DEV-IVO1-0525',   '2025-05-05',  4, 26),
(4000000,  'VIR-INF-IVO2-0625',   '2025-06-18',  4, 27),
-- Paiements Maroc (depuis compte 6 MAD)
(18000.00, 'VIR-LOY-CAS-0125',    '2025-01-07',  6, 13),
(18000.00, 'VIR-LOY-CAS-0425',    '2025-04-07',  6, 14),
(150000.00,'VIR-DEV-ATL1-0425',   '2025-04-18',  6, 28),
(200000.00,'VIR-PAR-ATL1-0725',   '2025-07-05',  6, 29),
(300000.00,'VIR-FON-ATL2-0825',   '2025-08-18',  6, 30),
-- Paiements Sénégal (depuis compte 8 XOF)
(12000000, 'VIR-LOG-TER-0625',    '2025-06-05',  8, 31),
-- Paiements Belgique (depuis compte 9 EUR)
(90000.00, 'VIR-EUR1-DEV-0425',   '2025-04-05',  9, 32),
(60000.00, 'VIR-EUR1-INF-0625',   '2025-06-18',  9, 33),
(25000.00, 'VIR-EUR2-CON-0925',   '2025-09-05',  9, 34);


-- ============================================================
-- 12. CRÉDITS
-- Encaissements des factures émises
-- (certaines factures restent impayées intentionnellement)
-- ============================================================
INSERT INTO credit (montant, reference, date, no_compte_credit, id_facture) VALUES
-- TechCorp (factures 1, 2 payées — facture 3 impayée)
(25000.00, 'ENC-TCP-0325',    '2025-03-15', 1, 1),
(30000.00, 'ENC-TCP-0625',    '2025-06-25', 1, 2),
-- DataSoft (facture 4 payée — facture 5 impayée)
(15000.00, 'ENC-DSF-0425',    '2025-04-18', 1, 4),
-- BuildGroup (factures 6,7 payées)
(50000.00, 'ENC-BLG-0525',    '2025-05-20', 1, 6),
(60000.00, 'ENC-BLG-0825',    '2025-08-20', 1, 7),
-- AgroInvest (facture 8 payée — facture 9 impayée)
(8000000,  'ENC-AGR-0625',    '2025-06-20', 4, 8),
-- FinancePlus (factures 10,11 payées)
(200000.00,'ENC-FIN-0625',    '2025-06-01', 6, 10),
(250000.00,'ENC-FIN-0925',    '2025-10-01', 6, 11),
-- LogiTrans (facture 12 payée)
(15000000, 'ENC-LOG-0725',    '2025-07-20', 8, 12),
-- EnergieBrux (facture 13 payée — facture 14 impayée)
(100000.00,'ENC-ENE-0525',    '2025-05-01', 9, 13),
-- GlobalConsult (facture 15 payée)
(10000.00, 'ENC-GLC-0825',    '2025-08-01', 1, 15),
-- MediaHub (facture 16 impayée — pas de crédit)
-- SmartBuild (facture 17 payée)
(300000.00,'ENC-SMB-0925',    '2025-09-20', 6, 17);


-- ============================================================
-- 13. TRANSACTIONS INTERNES
-- Virements de trésorerie entre comptes internes
-- ============================================================
INSERT INTO transaction_interne (montant, reference, date, no_compte_expediteur, no_compte_recepteur) VALUES
-- France : du courant vers l'épargne
(50000.00,  'TRESO-FR-EPARG-0325',  '2025-03-31', 1, 2),
(30000.00,  'TRESO-FR-EPARG-0625',  '2025-06-30', 1, 2),
-- France : de l'épargne vers le courant (besoin de liquidités Gamma)
(40000.00,  'TRESO-FR-LIQ-0825',    '2025-08-01', 2, 1),
-- Côte d'Ivoire : rééquilibrage entre comptes
(20000000,  'TRESO-CI-REEQUIL-0425','2025-04-30', 4, 5),
-- Maroc : rééquilibrage
(100000.00, 'TRESO-MA-REEQUIL-0625','2025-06-30', 6, 7),
-- Sénégal → Côte d'Ivoire (support inter-entité via USD)
-- (pas possible directement, simulé par deux transactions)
-- Belgique : du courant vers l'USD
(20000.00,  'TRESO-BE-USD-0525',    '2025-05-15', 9, 10),
-- France → Belgique (soutien projet Europa)
(30000.00,  'TRESO-FR-BE-0725',     '2025-07-15', 3, 10);
