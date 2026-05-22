# Dictionnaire de données

**Projet :** Cadre de gouvernance et qualité des données - Hydro-Québec

**Auteur :** Anthony MISSE

**Date :** 2026-05-14

**Version :** 0.5 (intermédiaire - après contrôles Python)

**Statut :** Intermédiaire

---

## 1. Contexte

Cette version du dictionnaire de données intègre les résultats des contrôles implémentés dans `02_quality_rules.ipynb`.
Les colonnes ont été analysées de façon systématique (nulls, doublons, valeurs extrêmes, normalisation), et un premier
mapping source-vers-cible a été défini pour préparer l'intégration dans Azure SQL. Les noms cibles, types et contraintes
sont désormais stabilisés pour les deux tables.

---

## 2. Table hq_demande_electricite

### 2.1 Description générale

| Attribut               | Valeur                             |
| ---------------------- | ---------------------------------- |
| Fichier source         | `hq_demande_electricite_raw.csv`   |
| Fichier nettoyé        | `hq_demande_electricite_clean.csv` |
| Granularité            | Horaire                            |
| Période couverte       | 2019-01-01 à 2024-01-01            |
| Lignes brutes          | 43 824                             |
| Lignes après nettoyage | 43 818 (6 doublons supprimés)      |

### 2.2 Mapping source-vers-cible

| Nom source     | Nom cible    | Type source | Type cible (logique) | Description                                                                                    | Observations                                                                                                                                      |
| -------------- | ------------ | ----------- | -------------------- | ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `date`         | `date`       | object      | datetime             | Horodatage de la mesure de demande électrique. Format ISO 8601 avec décalage horaire (-05:00). | OBS-001 : 0 valeur non convertible. Conversion via `toTimestamp` dans ADF.                                                                        |
| `demande (MW)` | `demande_mw` | float64     | float                | Demande électrique en mégawatts (MW) à l'instant donné.                                        | OBS-002 : 45 valeurs nulles (0.10 %) corrigées par interpolation linéaire. 94 valeurs > 37 005.60 MW (seuil IQR) conservées comme pics légitimes. |

### 2.3 Qualité après correction

| Contrôle                                                     | Résultat                                    | Statut                |
| ------------------------------------------------------------ | ------------------------------------------- | --------------------- |
| Valeurs nulles dans `demande_mw`                             | 45 à 0 après interpolation                  | PASS après correction |
| Convertibilité de `date`                                     | 0 valeur invalide                           | PASS                  |
| Doublons sur `date`                                          | 6 à 0 après suppression                     | PASS après correction |
| Valeurs extrêmes (`demande_mw` > 37 005.60 MW)               | 94 valeurs conservées (pics de grand froid) | INFO                  |
| Valeurs techniquement impossibles (`demande_mw` > 45 000 MW) | 0 valeur détectée                           | PASS                  |

### 2.4 Schéma cible Azure SQL

| Nom colonne cible | Type SQL    | Contraintes                    |
| ----------------- | ----------- | ------------------------------ |
| `date`            | `datetime2` | Clé primaire, unique, NOT NULL |
| `demande_mw`      | `float`     | NOT NULL après correction      |

---

## 3. Table hq_consommation_secteur

### 3.1 Description générale

| Attribut         | Valeur                              |
| ---------------- | ----------------------------------- |
| Fichier source   | `hq_consommation_secteur_raw.csv`   |
| Fichier nettoyé  | `hq_consommation_secteur_clean.csv` |
| Granularité      | Mensuelle                           |
| Période couverte | 2016-01-01 à 2025-12-01             |
| Lignes           | 10 200 (aucune suppression)         |

### 3.2 Mapping source-vers-cible

| Nom source          | Nom cible   | Type source | Type cible (logique) | Description                                 | Observations                                                                                                                                                  |
| ------------------- | ----------- | ----------- | -------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `REGION_ADM_QC_TXT` | `region`    | object      | nvarchar             | Nom de la région administrative du Québec.  | OBS-006 : 17 régions distinctes, cohérentes avec la nomenclature officielle. Aucune valeur inconnue.                                                          |
| `ANNEE_MOIS`        | `date`      | object      | date                 | Premier jour du mois (format `yyyy-MM-dd`). | OBS-007 : 0 valeur non convertible. Conversion via `toDate(date, 'yyyy-MM-dd')` dans ADF.                                                                     |
| `SECTEUR`           | `secteur`   | object      | nvarchar             | Secteur d'activité économique.              | OBS-008 : normalisé en format titre (Agricole, Commercial, Industriel, Institutionnel, Résidentiel). Distribution équilibrée : 2 040 occurrences par secteur. |
| `Total (kWh)`       | `total_kwh` | float64     | float                | Consommation mensuelle en kilowattheures.   | OBS-009 : 0 valeur nulle, 0 valeur ≤ 0. Aucune correction nécessaire.                                                                                         |

### 3.3 Qualité après correction

| Contrôle                                                | Résultat                      | Statut                   |
| ------------------------------------------------------- | ----------------------------- | ------------------------ |
| Valeurs nulles dans `total_kwh`                         | 0 valeur nulle                | PASS                     |
| Valeurs négatives dans `total_kwh`                      | 0 valeur ≤ 0                  | PASS                     |
| Doublons sur la clé composite `(region, date, secteur)` | 0 doublon                     | PASS                     |
| Conformité des valeurs de `secteur`                     | Normalisées via `str.title()` | PASS après normalisation |

### 3.4 Schéma cible Azure SQL

| Nom colonne cible | Type SQL        | Contraintes                            |
| ----------------- | --------------- | -------------------------------------- |
| `region`          | `nvarchar(100)` | NOT NULL, inclus dans la clé composite |
| `date`            | `date`          | NOT NULL, inclus dans la clé composite |
| `secteur`         | `nvarchar(50)`  | NOT NULL, inclus dans la clé composite |
| `total_kwh`       | `float`         | NOT NULL, strictement positif          |

---

## 4. Cohérence temporelle entre les deux tables

La période de chevauchement entre `hq_demande` (2019–2024) et `hq_secteur` (2016–2025) est **2019-01-01 à 2024-01-01**.
Toute analyse croisée entre les deux tables devra se limiter à cette fenêtre commune. Ce filtre devra être appliqué dans
les requêtes SQL (`WHERE date BETWEEN '2019-01-01' AND '2024-01-01'`) et dans les mesures DAX de Power BI.

---

## 5. Liens avec les règles de qualité

| Règle  | Description courte                              | Table concernée |
| ------ | ----------------------------------------------- | --------------- |
| RQ-01  | Complétude de `demande_mw`                      | hq_demande      |
| RQ-02  | Convertibilité de `date`                        | hq_demande      |
| RQ-03  | Unicité des timestamps                          | hq_demande      |
| RQ-04  | Valeurs extrêmes de `demande_mw` (seuil IQR)    | hq_demande      |
| RQ-04b | Valeurs techniquement impossibles (> 45 000 MW) | hq_demande      |
| RQ-06  | Conformité des valeurs de `secteur`             | hq_secteur      |
| RQ-07  | Complétude et positivité de `total_kwh`         | hq_secteur      |

---

## 6. Limitations de cette version

- Les définitions sont basées sur les fichiers CSV et les notebooks Python locaux.
- Les transformations ADF (Data Flows, copy activities) ne sont pas encore implémentées.
- Les types SQL cibles sont logiques et devront être confirmés lors de la création physique des tables dans Azure SQL.

---

## 7. Prochaines étapes

- Implémenter les schémas physiques dans Azure SQL et confirmer les types réels.
- Documenter les transformations ADF (`initCap`, `toTimestamp`, `toDate`, `toDouble`).
- Intégrer le filtre temporel 2019–2024 dans les requêtes SQL et les mesures DAX.
- Produire la version 1.0 après validation du pipeline ADF.
