# Règles de qualité des données

**Projet :** Cadre de gouvernance et qualité des données - Hydro-Québec

**Auteur :** Anthony MISSE

**Date :** 2026-05-14

**Version :** 1.0

**Statut :** Validé

---

## 1. Contexte

Cette version des règles de qualité consolide l'ensemble des contrôles appliqués localement dans `02_quality_rules.ipynb` et transposés en SQL dans `quality_check.sql`. Les règles couvrent les deux tables sources du projet. Chaque règle est documentée avec son seuil, son résultat réel, son niveau de sévérité et l'action corrective retenue.

**Niveaux de sévérité :**

| Code | Signification               | Comportement                            |
| ---- | --------------------------- | --------------------------------------- |
| CRIT | Bloquant - pipeline arrêté  | Aucune donnée ingérée                   |
| HIGH | Anomalie grave - alerter    | Pipeline continue, anomalie journalisée |
| WARN | Anomalie mineure - corriger | Correction automatique appliquée        |
| INFO | Observation non bloquante   | Documenté, aucune action                |
| PASS | Contrôle réussi             | Aucune action requise                   |

---

## 2. Règles consolidées

### RQ-01 - Complétude de `demande_mw`

| Attribut          | Valeur                                                                          |
| ----------------- | ------------------------------------------------------------------------------- |
| Table             | `hq_demande_electricite`                                                        |
| Colonne           | `demande_mw`                                                                    |
| Seuil d'alerte    | > 0.5 % de valeurs nulles                                                       |
| Seuil de blocage  | > 1 % de valeurs nulles (≥ 438 lignes)                                          |
| Résultat observé  | 45 valeurs nulles (0.10 %)                                                      |
| Sévérité          | WARN                                                                            |
| Action corrective | Interpolation linéaire (`interpolate(method='linear', limit_direction='both')`) |
| Statut final      | **PASS après correction** (0 null restant)                                      |

---

### RQ-02 - Convertibilité de la colonne `date`

| Attribut           | Valeur                                          |
| ------------------ | ----------------------------------------------- |
| Table              | `hq_demande_electricite`                        |
| Colonne            | `date`                                          |
| Seuil de blocage   | Toute valeur non convertible en datetime        |
| Format source      | ISO 8601 avec décalage horaire `-05:00`         |
| Résultat observé   | 0 valeur non convertible                        |
| Sévérité           | PASS                                            |
| Action corrective  | Aucune                                          |
| Transformation ADF | `toTimestamp(date, "yyyy-MM-dd'T'HH:mm:ssXXX")` |
| Statut final       | **PASS**                                        |

---

### RQ-03 - Unicité des timestamps

| Attribut          | Valeur                                                                                 |
| ----------------- | -------------------------------------------------------------------------------------- |
| Table             | `hq_demande_electricite`                                                               |
| Colonne           | `date`                                                                                 |
| Seuil de blocage  | Tout doublon sur la clé primaire                                                       |
| Résultat observé  | 6 doublons liés au changement d'heure (nuits de novembre 2019–2022) + 1er janvier 2023 |
| Sévérité          | WARN                                                                                   |
| Action corrective | `drop_duplicates(subset=['date'], keep='first')` - 43 818 lignes après correction      |
| Statut final      | **PASS après correction**                                                              |

---

### RQ-04 - Valeurs extrêmes de `demande_mw`

| Attribut             | Valeur                                                              |
| -------------------- | ------------------------------------------------------------------- |
| Table                | `hq_demande_electricite`                                            |
| Colonne              | `demande_mw`                                                        |
| Méthode de détection | IQR : seuil = Q3 + 1.5 × IQR                                        |
| Seuil IQR calculé    | 37 005.60 MW                                                        |
| Résultat observé     | 94 valeurs dépassent le seuil IQR                                   |
| Contexte             | Concentrées en janvier–février 2022 et 2023 (vagues de grand froid) |
| Sévérité             | INFO                                                                |
| Action corrective    | Conservation - ces valeurs sont physiquement légitimes              |
| Statut final         | **INFO** (aucune suppression)                                       |

---

### RQ-04b - Valeurs techniquement impossibles de `demande_mw`

| Attribut          | Valeur                   |
| ----------------- | ------------------------ |
| Table             | `hq_demande_electricite` |
| Colonne           | `demande_mw`             |
| Seuil de blocage  | Toute valeur > 45 000 MW |
| Résultat observé  | 0 valeur détectée        |
| Sévérité          | PASS                     |
| Action corrective | Aucune                   |
| Statut final      | **PASS**                 |

---

### RQ-06 - Conformité des valeurs de `secteur`

| Attribut           | Valeur                                                                                    |
| ------------------ | ----------------------------------------------------------------------------------------- |
| Table              | `hq_consommation_secteur`                                                                 |
| Colonne            | `secteur`                                                                                 |
| Liste de référence | Agricole, Commercial, Industriel, Institutionnel, Résidentiel                             |
| Résultat observé   | 5 valeurs présentes, toutes conformes après normalisation                                 |
| Distribution       | 2 040 occurrences par secteur (17 régions × 120 mois)                                     |
| Sévérité           | INFO                                                                                      |
| Action corrective  | Normalisation via `str.lower().str.title()` en Python, `initCap(lower(SECTEUR))` dans ADF |
| Statut final       | **PASS après normalisation**                                                              |

---

### RQ-07 - Complétude et validité de `total_kwh`

| Attribut          | Valeur                       |
| ----------------- | ---------------------------- |
| Table             | `hq_consommation_secteur`    |
| Colonne           | `total_kwh`                  |
| Seuil de blocage  | Toute valeur nulle ou ≤ 0    |
| Résultat observé  | 0 valeur nulle, 0 valeur ≤ 0 |
| Sévérité          | PASS                         |
| Action corrective | Aucune                       |
| Statut final      | **PASS**                     |

---

## 3. Journal d'anomalies (anomalies_log.csv)

| Règle  | Champ      | Type d'anomalie       | Nb lignes | Sévérité | Action                   |
| ------ | ---------- | --------------------- | --------- | -------- | ------------------------ |
| RQ-01  | demande_mw | missing_value         | 45        | WARN     | interpolation_lineaire   |
| RQ-02  | date       | invalid_datetime      | 0         | PASS     | aucune                   |
| RQ-03  | date       | duplicate_timestamp   | 6         | WARN     | keep_first               |
| RQ-04  | demande_mw | outlier_iqr           | 94        | INFO     | conserver                |
| RQ-04b | demande_mw | outlier_tech_gt_45000 | 0         | PASS     | aucune                   |
| RQ-06  | secteur    | format_uppercase      | 10 200    | INFO     | normalisation_title_case |
| RQ-07  | total_kwh  | null_or_non_positive  | 0         | PASS     | aucune                   |

---

## 4. Règle en attente de formalisation

### RQ-08 - Cohérence temporelle entre les deux tables

| Attribut    | Valeur                                                            |
| ----------- | ----------------------------------------------------------------- |
| Tables      | `hq_demande_electricite` et `hq_consommation_secteur`             |
| Observation | Période de chevauchement : 2019-01-01 à 2024-01-01                |
| Impact      | Toute analyse croisée doit être filtrée sur cette fenêtre commune |
| Statut      | En attente de formalisation dans le pipeline ADF                  |

---

## 5. Historique des versions

| Version | Date           | Statut        | Description                                                                 |
| ------- | -------------- | ------------- | --------------------------------------------------------------------------- |
| 0.1     | 2026-05-10     | Brouillon     | Règles identifiées à partir de l'exploration initiale                       |
| 0.5     | 2026-05-14     | Intermédiaire | Résultats réels intégrés, RQ-02 ajoutée, journal d'anomalies documenté      |
| **1.0** | **2026-05-14** | **Validé**    | **Seuils formalisés, extraits SQL ajoutés à chaque règle, RQ-08 anticipée** |
