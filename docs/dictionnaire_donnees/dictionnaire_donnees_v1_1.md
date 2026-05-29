# Dictionnaire de données

**Projet :** Cadre de gouvernance et qualité des données - Hydro-Québec

**Auteur :** Anthony MISSE

**Date :** 2026-05-23

**Version :** 1.1

**Statut :** Validé

***

## 1. Contexte

Ce dictionnaire documente les tables finales du projet Hydro-Québec, depuis leur format brut jusqu’à leur schéma physique dans Azure SQL. Il intègre les contrôles de qualité du notebook `02_quality_rules.ipynb`, les transformations implémentées dans les Data Flows Azure Data Factory, ainsi que les tables de suivi utilisées pour le journal des anomalies et la synthèse qualité.

**Fichiers sources :**
- `hq_demande_electricite_raw.csv`
- `hq_consommation_secteur_raw.csv`

**Tables Azure SQL finales :**
- `dbo.hq_demande`
- `dbo.hq_secteur`

**Tables Azure SQL de gouvernance :**
- `dbo.dq_error_log`
- `dbo.dq_quality_summary`

**Procédures stockées associées :**
- `dbo.sp_log_dq_checks_hq_demande`
- `dbo.sp_log_dq_checks_hq_secteur`

***

## 2. Table `hq_demande`

### 2.1 Description générale

| Attribut               | Valeur                           |
| ---------------------- | -------------------------------- |
| Fichier source         | `hq_demande_electricite_raw.csv` |
| Table Azure SQL        | `dbo.hq_demande`                 |
| Granularité            | Horaire                          |
| Période couverte       | 2019-01-01 à 2024-01-01          |
| Lignes brutes          | 43 824                           |
| Lignes après nettoyage | 43 818                           |
| Clé primaire           | `date`                           |

### 2.2 Colonnes

| Nom source     | Nom cible    | Type source (pandas) | Type cible (Azure SQL) | Nullable | Description                                                                                  | Transformation ADF                              |
| -------------- | ------------ | -------------------- | ---------------------- | -------- | -------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `date`         | `date`       | `object`             | `datetime2`            | NON      | Horodatage de la demande électrique au pas horaire.                                          | `toTimestamp(date, "yyyy-MM-dd'T'HH:mm:ssXXX")` |
| `demande (MW)` | `demande_mw` | `float64`            | `float`                | NON      | Demande électrique en mégawatts. Les valeurs manquantes ont été corrigées dans le Data Flow. | Renommage + interpolation                       |

### 2.3 Résultats des contrôles de qualité

| Règle  | Contrôle                                        | Résultat                                   | Statut                |
| ------ | ----------------------------------------------- | ------------------------------------------ | --------------------- |
| RQ-02  | Convertibilité de `date`                        | 0 valeur invalide détectée                 | PASS                  |
| RQ-03  | Unicité des timestamps                          | 6 doublons supprimés (`keep='first'`)      | PASS après correction |
| RQ-01  | Valeurs nulles dans `demande_mw`                | 45 nulls corrigés par interpolation        | PASS après correction |
| RQ-04  | Valeurs extrêmes (seuil IQR : 37 005.60 MW)     | 94 valeurs conservées comme pics légitimes | INFO                  |
| RQ-04b | Valeurs techniquement impossibles (> 45 000 MW) | 0 valeur détectée                          | PASS                  |

### 2.4 Schéma physique Azure SQL

```sql
CREATE TABLE dbo.hq_demande (
    [date] datetime2 NOT NULL,
    demande_mw float NOT NULL,
    CONSTRAINT PK_hq_demande PRIMARY KEY ([date])
);
```

***

## 3. Table `hq_secteur`

### 3.1 Description générale

| Attribut         | Valeur                            |
| ---------------- | --------------------------------- |
| Fichier source   | `hq_consommation_secteur_raw.csv` |
| Table Azure SQL  | `dbo.hq_secteur`                  |
| Granularité      | Mensuelle                         |
| Période couverte | 2016-01-01 à 2025-12-01           |
| Lignes           | 10 200                            |
| Clé primaire     | `(region, date, secteur)`         |

### 3.2 Colonnes

| Nom source          | Nom cible   | Type source (pandas) | Type cible (Azure SQL) | Nullable | Description                           | Transformation ADF                 |
| ------------------- | ----------- | -------------------- | ---------------------- | -------- | ------------------------------------- | ---------------------------------- |
| `REGION_ADM_QC_TXT` | `region`    | `object`             | `nvarchar(100)`        | NON      | Région administrative du Québec.      | `trim(region)` + renommage         |
| `ANNEE_MOIS`        | `date`      | `object`             | `date`                 | NON      | Premier jour du mois représenté.      | `toDate(ANNEE_MOIS, 'yyyy-MM-dd')` |
| `SECTEUR`           | `secteur`   | `object`             | `nvarchar(50)`         | NON      | Secteur d’activité économique.        | `initCap(lower(SECTEUR))`          |
| `Total (kWh)`       | `total_kwh` | `float64`            | `float`                | NON      | Consommation mensuelle totale en kWh. | Renommage uniquement               |

### 3.3 Résultats des contrôles de qualité

| Règle | Contrôle                               | Résultat                                             | Statut                   |
| ----- | -------------------------------------- | ---------------------------------------------------- | ------------------------ |
| RQ-07 | Valeurs nulles dans `total_kwh`        | 0 valeur nulle                                       | PASS                     |
| RQ-07 | Valeurs non positives dans `total_kwh` | 0 valeur ≤ 0                                         | PASS                     |
| RQ-06 | Conformité de `secteur`                | 5 valeurs normalisées, 2 040 occurrences par secteur | PASS après normalisation |
| -     | Unicité de la clé composite            | 0 doublon                                            | PASS                     |

### 3.4 Schéma physique Azure SQL

```sql
CREATE TABLE dbo.hq_secteur (
    region nvarchar (100) NOT NULL,
    [date] date NOT NULL,
    secteur nvarchar (50) NOT NULL,
    total_kwh float NOT NULL,
    CONSTRAINT PK_hq_secteur PRIMARY KEY (region, [date], secteur),
    CONSTRAINT CHK_total_kwh CHECK (total_kwh > 0)
);
```

***

## 4. Tables de gouvernance

### 4.1 `dq_error_log`

| Attribut    | Valeur                                         |
| ----------- | ---------------------------------------------- |
| Rôle        | Journal détaillé des anomalies détectées       |
| Table SQL   | `dbo.dq_error_log`                             |
| Granularité | Une ligne par anomalie/règle/exécution         |
| Utilisation | Suivi opérationnel, audit, base pour reporting |

### 4.2 Colonnes

| Colonne         | Type SQL            | Nullable | Description               |
| --------------- | ------------------- | -------- | ------------------------- |
| `log_id`        | `int identity(1,1)` | NON      | Clé technique du log      |
| `rule_id`       | `varchar(10)`       | NON      | Identifiant de la règle   |
| `table_name`    | `sysname`           | NON      | Nom de la table contrôlée |
| `column_name`   | `sysname`           | OUI      | Colonne concernée         |
| `anomaly_type`  | `varchar(50)`       | NON      | Type d’anomalie détectée  |
| `anomaly_count` | `int`               | NON      | Nombre d’occurrences      |
| `severity`      | `varchar(10)`       | NON      | Niveau de sévérité        |
| `action_taken`  | `varchar(100)`      | OUI      | Action appliquée          |
| `log_date`      | `datetime2`         | NON      | Date d’enregistrement     |
| `details`       | `nvarchar(4000)`    | OUI      | Détails complémentaires   |

### 4.3 Schéma physique Azure SQL

```sql
CREATE TABLE dbo.dq_error_log (
    log_id int IDENTITY (1, 1) NOT NULL,
    rule_id varchar(10) NOT NULL,
    table_name sysname NOT NULL,
    column_name sysname NULL,
    anomaly_type varchar(50) NOT NULL,
    anomaly_count int NOT NULL,
    severity varchar(10) NOT NULL,
    action_taken varchar(100) NULL,
    log_date datetime2 NOT NULL CONSTRAINT DF_dq_error_log_log_date DEFAULT SYSUTCDATETIME (),
    details nvarchar (4000) NULL,
    CONSTRAINT PK_dq_error_log PRIMARY KEY (log_id),
    CONSTRAINT CK_dq_error_log_anomaly_count CHECK (anomaly_count >= 0)
);
```

***

### 4.4 `dq_quality_summary`

| Attribut    | Valeur                                 |
| ----------- | -------------------------------------- |
| Rôle        | Résumé consolidé des contrôles qualité |
| Table SQL   | `dbo.dq_quality_summary`               |
| Granularité | Une ligne par règle/exécution          |
| Utilisation | Alimentation du dashboard Power BI     |

### 4.5 Colonnes

| Colonne         | Type SQL            | Nullable | Description                      |
| --------------- | ------------------- | -------- | -------------------------------- |
| `summary_id`    | `int identity(1,1)` | NON      | Clé technique du résumé          |
| `rule_id`       | `varchar(10)`       | NON      | Identifiant de la règle          |
| `table_name`    | `sysname`           | NON      | Nom de la table contrôlée        |
| `total_rows`    | `int`               | NON      | Nombre total de lignes analysées |
| `anomaly_count` | `int`               | NON      | Nombre d’anomalies détectées     |
| `pct_anomalies` | `decimal(5,2)`      | NON      | Pourcentage d’anomalies          |
| `severity`      | `varchar(10)`       | NON      | Niveau de sévérité               |
| `status`        | `varchar(30)`       | NON      | Statut final du contrôle         |
| `run_date`      | `datetime2`         | NON      | Date d’exécution                 |

### 4.6 Schéma physique Azure SQL

```sql
CREATE TABLE dbo.dq_quality_summary (
    summary_id int IDENTITY (1, 1) NOT NULL,
    rule_id varchar(10) NOT NULL,
    table_name sysname NOT NULL,
    total_rows int NOT NULL,
    anomaly_count int NOT NULL,
    pct_anomalies decimal(5, 2) NOT NULL,
    severity varchar(10) NOT NULL,
    status varchar(30) NOT NULL,
    run_date datetime2 NOT NULL CONSTRAINT DF_dq_quality_summary_run_date DEFAULT SYSUTCDATETIME (),
    CONSTRAINT PK_dq_quality_summary PRIMARY KEY (summary_id),
    CONSTRAINT CK_dq_quality_summary_total_rows CHECK (total_rows >= 0),
    CONSTRAINT CK_dq_quality_summary_anomaly_count CHECK (anomaly_count >= 0),
    CONSTRAINT CK_dq_quality_summary_pct CHECK (
        pct_anomalies >= 0
        AND pct_anomalies <= 100
    )
);
```

***

## 5. Valeurs de référence - colonne `secteur`

| Valeur normalisée | Valeur source  | Occurrences |
| ----------------- | -------------- | ----------- |
| Agricole          | AGRICOLE       | 2 040       |
| Commercial        | COMMERCIAL     | 2 040       |
| Industriel        | INDUSTRIEL     | 2 040       |
| Institutionnel    | INSTITUTIONNEL | 2 040       |
| Résidentiel       | RÉSIDENTIEL    | 2 040       |

***

## 6. Cohérence temporelle entre les tables

| Table                    | Début          | Fin            | Granularité |
| ------------------------ | -------------- | -------------- | ----------- |
| `hq_demande`             | 2019-01-01     | 2024-01-01     | Horaire     |
| `hq_secteur`             | 2016-01-01     | 2025-12-01     | Mensuelle   |
| **Chevauchement commun** | **2019-01-01** | **2024-01-01** | -           |

Toute analyse croisée entre les deux tables doit être filtrée sur la période commune.

```sql
WHERE [date] BETWEEN '2019-01-01' AND '2024-01-01'
```

***

## 7. Liens avec les règles de qualité

| Règle  | Objet                                           | Table        |
| ------ | ----------------------------------------------- | ------------ |
| RQ-01  | Complétude de `demande_mw`                      | `hq_demande` |
| RQ-02  | Convertibilité de `date`                        | `hq_demande` |
| RQ-03  | Unicité des timestamps                          | `hq_demande` |
| RQ-04  | Valeurs extrêmes de `demande_mw`                | `hq_demande` |
| RQ-04b | Valeurs techniquement impossibles (> 45 000 MW) | `hq_demande` |
| RQ-06  | Conformité des valeurs de `secteur`             | `hq_secteur` |
| RQ-07  | Complétude et positivité de `total_kwh`         | `hq_secteur` |

***

## 8. Historique des versions

| Version | Date       | Statut        | Description                                                                                                        |
| ------- | ---------- | ------------- | ------------------------------------------------------------------------------------------------------------------ |
| 0.1     | 2026-05-10 | Brouillon     | Exploration initiale, types observés dans pandas, premières observations                                           |
| 0.5     | 2026-05-14 | Intermédiaire | Mapping source-vers-cible défini, résultats des contrôles Python intégrés                                          |
| 1.0     | 2026-05-22 | Validé        | Schémas physiques Azure SQL et transformations ADF alignés sur les tables finales                                  |
| 1.1     | 2026-05-23 | Validé        | Ajout des tables de gouvernance `dq_error_log` et `dq_quality_summary` ainsi que des procédures stockées associées |