# Règles de qualité des données

**Projet :** Cadre de gouvernance et qualité des données - Hydro-Québec

**Auteur :** Anthony MISSE

**Date :** 2026-05-23

**Version :** 1.2

**Statut :** Validé

***

## 1. Contexte

Cette version des règles de qualité consolide l’ensemble des contrôles appliqués localement dans `02_quality_rules.ipynb`, puis transposés dans Azure Data Factory et SQL. Les règles couvrent les deux tables finales du projet, ainsi que leur couche de gouvernance constituée des tables de log et de synthèse qualité.

**Niveaux de sévérité :**

| Code | Signification               | Comportement                            |
| ---- | --------------------------- | --------------------------------------- |
| CRIT | Bloquant - pipeline arrêté  | Aucune donnée ingérée                   |
| HIGH | Anomalie grave - alerter    | Pipeline continue, anomalie journalisée |
| WARN | Anomalie mineure - corriger | Correction automatique appliquée        |
| INFO | Observation non bloquante   | Documenté, aucune action                |
| PASS | Contrôle réussi             | Aucune action requise                   |

***

## 2. Règles consolidées

### RQ-01 - Complétude de `demande_mw`

| Attribut          | Valeur                                       |
| ----------------- | -------------------------------------------- |
| Table             | `dbo.hq_demande`                             |
| Colonne           | `demande_mw`                                 |
| Seuil d’alerte    | > 0.5% de valeurs nulles                     |
| Seuil de blocage  | > 1% de valeurs nulles (≥ 438 lignes)        |
| Résultat observé  | 45 valeurs nulles (0.10%)                    |
| Sévérité          | WARN                                         |
| Action corrective | Interpolation linéaire dans le Data Flow ADF |
| Statut final      | **PASS après correction** (0 null restant)   |

> Implémentation SQL : voir `../sql/quality_check.sql`, section RQ-01.

***

### RQ-02 - Convertibilité de la colonne `date`

| Attribut           | Valeur                                          |
| ------------------ | ----------------------------------------------- |
| Table              | `dbo.hq_demande`                                |
| Colonne            | `date`                                          |
| Seuil de blocage   | Toute valeur non convertible en datetime        |
| Format source      | ISO 8601 avec décalage horaire `-05:00`         |
| Résultat observé   | 0 valeur non convertible                        |
| Sévérité           | PASS                                            |
| Action corrective  | Aucune                                          |
| Transformation ADF | `toTimestamp(date, "yyyy-MM-dd'T'HH:mm:ssXXX")` |
| Statut final       | **PASS**                                        |

> Implémentation SQL : voir `../sql/quality_check.sql`, section RQ-02.

***

### RQ-03 - Unicité des timestamps

| Attribut          | Valeur                                                                          |
| ----------------- | ------------------------------------------------------------------------------- |
| Table             | `dbo.hq_demande`                                                                |
| Colonne           | `date`                                                                          |
| Seuil de blocage  | Tout doublon sur la clé primaire                                                |
| Résultat observé  | 6 doublons liés au changement d’heure et à une duplication ponctuelle           |
| Sévérité          | WARN                                                                            |
| Action corrective | Déduplication dans le Data Flow ADF avec conservation de la première occurrence |
| Statut final      | **PASS après correction**                                                       |

> Implémentation SQL : voir `../sql/quality_check.sql`, section RQ-03.

***

### RQ-04 - Valeurs extrêmes de `demande_mw`

| Attribut             | Valeur                                                              |
| -------------------- | ------------------------------------------------------------------- |
| Table                | `dbo.hq_demande`                                                    |
| Colonne              | `demande_mw`                                                        |
| Méthode de détection | IQR : seuil = Q3 + 1.5 × IQR                                        |
| Seuil IQR calculé    | 37 005.60 MW                                                        |
| Résultat observé     | 94 valeurs dépassent le seuil IQR                                   |
| Contexte             | Concentrées en janvier–février 2022 et 2023 (vagues de grand froid) |
| Sévérité             | INFO                                                                |
| Action corrective    | Conservation, car valeurs physiquement légitimes                    |
| Statut final         | **INFO**                                                            |

> Implémentation SQL : voir `../sql/quality_check.sql`, section RQ-04.

***

### RQ-04b - Valeurs techniquement impossibles de `demande_mw`

| Attribut          | Valeur                   |
| ----------------- | ------------------------ |
| Table             | `dbo.hq_demande`         |
| Colonne           | `demande_mw`             |
| Seuil de blocage  | Toute valeur > 45 000 MW |
| Résultat observé  | 0 valeur détectée        |
| Sévérité          | PASS                     |
| Action corrective | Aucune                   |
| Statut final      | **PASS**                 |

> Implémentation SQL : voir `../sql/quality_check.sql`, section RQ-04b.

***

### RQ-06 - Conformité des valeurs de `secteur`

| Attribut           | Valeur                                                        |
| ------------------ | ------------------------------------------------------------- |
| Table              | `dbo.hq_secteur`                                              |
| Colonne            | `secteur`                                                     |
| Liste de référence | Agricole, Commercial, Industriel, Institutionnel, Résidentiel |
| Résultat observé   | 5 valeurs présentes, toutes conformes après normalisation     |
| Distribution       | 2 040 occurrences par secteur                                 |
| Sévérité           | INFO                                                          |
| Action corrective  | Normalisation via `initCap(lower(SECTEUR))` dans ADF          |
| Statut final       | **PASS après normalisation**                                  |

> Implémentation SQL : voir `../sql/quality_check.sql`, section RQ-06.

***

### RQ-07 - Complétude et validité de `total_kwh`

| Attribut          | Valeur                       |
| ----------------- | ---------------------------- |
| Table             | `dbo.hq_secteur`             |
| Colonne           | `total_kwh`                  |
| Seuil de blocage  | Toute valeur nulle ou ≤ 0    |
| Résultat observé  | 0 valeur nulle, 0 valeur ≤ 0 |
| Sévérité          | PASS                         |
| Action corrective | Aucune                       |
| Statut final      | **PASS**                     |

> Implémentation SQL : voir `../sql/quality_check.sql`, section RQ-07.

***

## 3. Règles de gouvernance

### RQ-09 - Journalisation des anomalies

| Attribut    | Valeur                                              |
| ----------- | --------------------------------------------------- |
| Table cible | `dbo.dq_error_log`                                  |
| Rôle        | Journal détaillé des anomalies détectées            |
| Déclencheur | Exécution des procédures stockées de qualité        |
| Principe    | Une ligne par anomalie ou observation à journaliser |
| Statut      | **ACTIF**                                           |

### RQ-10 - Synthèse qualité

| Attribut    | Valeur                                       |
| ----------- | -------------------------------------------- |
| Table cible | `dbo.dq_quality_summary`                     |
| Rôle        | Résumé consolidé des contrôles qualité       |
| Déclencheur | Exécution des procédures stockées de qualité |
| Principe    | Une ligne par règle et par exécution         |
| Statut      | **ACTIF**                                    |

### RQ-11 - Traçabilité des contrôles

| Attribut             | Valeur                                                               |
| -------------------- | -------------------------------------------------------------------- |
| Procédures associées | `dbo.sp_log_dq_checks_hq_demande`, `dbo.sp_log_dq_checks_hq_secteur` |
| Finalité             | Centraliser l’écriture des résultats qualité                         |
| Utilisation          | Alimentation des tables de gouvernance et du dashboard Power BI      |
| Statut               | **ACTIF**                                                            |

***

## 4. Journal d’anomalies

| Règle  | Champ      | Type d’anomalie       | Nb lignes | Sévérité | Action                   |
| ------ | ---------- | --------------------- | --------: | -------- | ------------------------ |
| RQ-01  | demande_mw | missing_value         |        45 | WARN     | interpolation_lineaire   |
| RQ-02  | date       | invalid_datetime      |         0 | PASS     | aucune                   |
| RQ-03  | date       | duplicate_timestamp   |         6 | WARN     | keep_first               |
| RQ-04  | demande_mw | outlier_iqr           |        94 | INFO     | conserver                |
| RQ-04b | demande_mw | outlier_tech_gt_45000 |         0 | PASS     | aucune                   |
| RQ-06  | secteur    | format_title_case     |         0 | PASS     | normalisation_title_case |
| RQ-07  | total_kwh  | null_or_non_positive  |         0 | PASS     | aucune                   |

***

## 5. Cohérence temporelle

### RQ-08 - Cohérence temporelle entre les deux tables

| Attribut    | Valeur                                                            |
| ----------- | ----------------------------------------------------------------- |
| Tables      | `dbo.hq_demande` et `dbo.hq_secteur`                              |
| Observation | Période de chevauchement : 2019-01-01 à 2024-01-01                |
| Impact      | Toute analyse croisée doit être filtrée sur cette fenêtre commune |
| Statut      | Règle documentaire de cohérence                                   |

***

## 6. Historique des versions

| Version | Date       | Statut        | Description                                                                                |
| ------- | ---------- | ------------- | ------------------------------------------------------------------------------------------ |
| 0.1     | 2026-05-10 | Brouillon     | Règles identifiées à partir de l’exploration initiale                                      |
| 0.5     | 2026-05-14 | Intermédiaire | Résultats réels intégrés, règles consolidées                                               |
| 1.0     | 2026-05-14 | Validé        | Seuils formalisés, extraits SQL ajoutés à chaque règle                                     |
| 1.1     | 2026-05-22 | Validé        | Noms de tables alignés sur les tables finales et corrections déplacées dans les Data Flows |
| 1.2     | 2026-05-23 | Validé        | Ajout des règles de gouvernance liées aux tables `dq_error_log` et `dq_quality_summary`    |