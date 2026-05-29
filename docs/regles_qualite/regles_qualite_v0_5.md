# Règles de qualité des données

**Projet :** Cadre de gouvernance et qualité des données - Hydro-Québec

**Auteur :** Anthony MISSE

**Date :** 2026-05-14

**Version :** 0.5 (intermédiaire - après contrôles Python)

**Statut :** Intermédiaire

---

## 1. Contexte

Cette version des règles de qualité intègre les résultats des contrôles automatisés implémentés dans
`02_quality_rules.ipynb`. Les règles sont appliquées localement (Python, fichiers CSV) et documentées avec leurs
résultats réels. Les niveaux de sévérité (PASS, WARN, INFO, CRIT) sont appliqués dans le journal d'anomalies (
`reports/anomalies_log.csv`) mais ne sont pas encore alignés avec la gouvernance ADF de l'organisation.

---

## 2. Règles consolidées

### RQ-01 - Complétude de `demande_mw`

- **Seuil de blocage :** taux de valeurs nulles > 1 % (438 lignes).
- **Résultat :** 45 valeurs nulles détectées, soit 0.10 % - en dessous du seuil.
- **Action appliquée :** interpolation linéaire (`interpolate(method='linear', limit_direction='both')`).
- **Statut :** WARN puis **PASS après correction** (0 null restant).

### RQ-02 - Convertibilité de la colonne `date`

- **Seuil de blocage :** toute valeur non convertible en datetime.
- **Résultat :** 0 valeur non convertible détectée.
- **Format source :** ISO 8601 avec décalage horaire, ex. `2023-01-01T03:00:00-05:00`.
- **Transformation ADF prévue :** `toTimestamp(date, "yyyy-MM-dd'T'HH:mm:ssXXX")`.
- **Statut :** **PASS**.

### RQ-03 - Unicité des timestamps

- **Seuil de blocage :** tout doublon sur la colonne `date`.
- **Résultat :** 6 doublons identifiés, correspondant aux nuits du passage de l'heure avancée à l'heure normale (premier
  dimanche de novembre, 2019–2022) et au 1er janvier 2023.
- **Action appliquée :** `drop_duplicates(subset=['date'], keep='first')`.
- **Lignes après correction :** 43 818.
- **Statut :** WARN puis **PASS après correction**.

### RQ-04 - Valeurs extrêmes de `demande_mw`

- **Méthode :** détection par IQR (Q3 + 1.5 × IQR).
- **Seuil IQR supérieur calculé :** 37 005.60 MW.
- **Résultat :** 94 valeurs dépassent ce seuil. Toutes sont situées en janvier–février 2022 et 2023 (vagues de grand
  froid au Québec).
- **Seuil technique (valeurs impossibles) :** > 45 000 MW - 0 valeur détectée.
- **Action appliquée :** conservation de toutes les valeurs, documentation comme pics légitimes.
- **Statut :** **INFO** (valeurs conservées, aucune suppression).

### RQ-06 - Conformité des valeurs de `secteur`

- **Règle :** toute valeur de `secteur` doit appartenir à la liste de référence.
- **Valeurs distinctes observées :** AGRICOLE, COMMERCIAL, INDUSTRIEL, INSTITUTIONNEL, RESIDENTIEL (toutes en majuscules
  dans le fichier source).
- **Action appliquée :** normalisation via `str.lower().str.title()` - Agricole, Commercial, Industriel, Institutionnel,
  Résidentiel.
- **Distribution après normalisation :** 2 040 occurrences par secteur (parfaitement équilibrée).
- **Statut :** INFO  **PASS après normalisation**.

### RQ-07 - Complétude et validité de `total_kwh`

- **Règle :** toute valeur nulle ou ≤ 0 est invalide.
- **Résultat :** 0 valeur nulle, 0 valeur ≤ 0 détectée.
- **Action appliquée :** aucune correction nécessaire.
- **Statut :** **PASS**.

---

## 3. Journal d'anomalies

Le fichier `reports/anomalies_log.csv` centralise l'ensemble des contrôles avec le détail suivant :

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

## 4. Observations non encore formalisées en règles

- **Cohérence temporelle entre les deux tables :** la période de chevauchement (2019–2024) n'est pas encore traduite en
  règle formelle. Une règle RQ-08 (filtre temporel obligatoire) sera définie à la version 1.0.
- **Complétude mensuelle par région dans hq_secteur :** la distribution équilibrée (2 040 par secteur) confirme
  l'absence de mois manquants, mais aucun contrôle automatisé n'est encore en place.

---

## 5. Limitations de cette version

- Les sévérités (WARN, PASS, INFO) sont appliquées localement dans le journal d'anomalies, mais ne sont pas encore
  alignées avec la gouvernance de données de l'organisation.
- Aucune intégration avec Azure SQL ou ADF : les résultats sont limités aux fichiers CSV.
- Le journal d'anomalies n'est pas encore relié à un processus de suivi (ex. tickets Jira ou alertes ADF).

---

## 6. Prochaines étapes

- Aligner les niveaux de sévérité avec la gouvernance de données de l'organisation.
- Transposer les règles en SQL (`quality_checks.sql`) pour validation en base.
- Concevoir les contrôles de qualité dans le pipeline ADF (data flows, quality gates).
- Formaliser la règle RQ-08 (filtre de cohérence temporelle 2019–2024).
- Produire la version 1.0 après validation du pipeline ADF.
