# Dictionnaire de donnees

**Projet :** Cadre de gouvernance et qualite des donnees - Hydro-Quebec

**Auteur :** Anthony MISSE

**Date :** 2026-05-10

**Version :** 0.1

**Statut :** Brouillon

---

## 1. Contexte

Ce dictionnaire de donnees decrit de maniere preliminaire les colonnes observees dans les fichiers sources
du projet Hydro-Quebec, a la suite de l'exploration effectuee dans le notebook `01_exploration.ipynb`.

Les informations ci-dessous sont basees sur les fichiers CSV bruts :

- hq_demande_electricite_raw.csv
- hq_consommation_secteur_raw.csv

Les noms de colonnes, types et observations pourront evoluer au fil de la mise en place des controles
de qualite et du pipeline Azure.

## 2. Table hq_demande_electricite (source CSV brute)

### 2.1 Description generale

- **Fichier :** hq_demande_electricite_raw.csv
- **Granularite :** horaire
- **Periode couverte :** 2019 a 2024
- **Nombre de lignes :** 43 824 lignes avant nettoyage

### 2.2 Colonnes

| Nom colonne source | Type observe | Description preliminaire                                                            | Observations                                                                            |
| ------------------ | ------------ | ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| date               | object       | Horodatage de la mesure de demande electrique. Format ISO 8601 avec fuseau horaire. | OBS-001 : format ISO 8601 avec decalage horaire -05:00. Conversion datetime necessaire. |
| demande (MW)       | float64      | Valeur de la demande electrique en megawatts (MW) a l'instant donne.                | OBS-002 : 45 valeurs nulles (0.10 %). Nom a renommer en demande_mw.                     |

### 2.3 Observations (OBS-001 a OBS-005)

- **OBS-001 :** La colonne date est de type object (string). Le format ISO 8601 inclut un decalage horaire
  de type -05:00 (ex. 2023-01-01T03:00:00-05:00). Une conversion en datetime sera necessaire.
- **OBS-002 :** La colonne demande (MW) contient 45 valeurs nulles sur 43 824 lignes, soit 0.10 %.
  Interpolation lineaire envisagee si le taux reste inferieur a 1 %.
- **OBS-003 :** Le nom de la colonne demande (MW) contient un espace et des parentheses.
  Renommage en demande_mw prevu pour SQL et ADF.
- **OBS-004 :** 6 doublons detectes sur la colonne date. Origines suspectees : passage de l'heure avancee
  a l'heure normale. A confirmer dans le notebook 02_quality_rules.ipynb.
- **OBS-005 :** Valeurs tres elevees observees dans demande (MW). Le seuil IQR superieur est 37 005.60 MW;
  94 valeurs depassent ce seuil. A analyser pour distinguer valeurs aberrantes et pics legitimes.

## 3. Table hq_consommation_secteur (source CSV brute)

### 3.1 Description generale

- **Fichier :** hq_consommation_secteur_raw.csv
- **Granularite :** mensuelle
- **Periode couverte :** 2016 a 2025
- **Nombre de lignes :** 10 200 lignes

### 3.2 Colonnes

| Nom colonne source | Type observe | Description preliminaire                                       | Observations                                                                 |
| ------------------ | ------------ | -------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| REGION_ADM_QC_TXT  | object       | Nom de la region administrative du Quebec.                     | OBS-006 : 17 regions distinctes, coherentes avec la nomenclature officielle. |
| ANNEE_MOIS         | object       | Date representant le premier jour du mois (format yyyy-MM-dd). | OBS-007 : type object, a convertir en date.                                  |
| SECTEUR            | object       | Secteur d'activite (ex. INDUSTRIEL, RESIDENTIEL).              | OBS-008 : valeurs en majuscules, distribution equlibree (2040 par secteur).  |
| Total (kWh)        | float64      | Consommation mensuelle en kilowattheures.                      | OBS-009 : type float64 correct. Nom a renommer en total_kwh.                 |

### 3.3 Observations (OBS-006 a OBS-009)

- **OBS-006 :** La colonne REGION_ADM_QC_TXT contient 17 regions distinctes, coherentes avec les regions
  administratives officielles du Quebec. Aucune valeur inconnue detectee.
- **OBS-007 :** La colonne ANNEE_MOIS est de type object (string), format yyyy-MM-dd.
  Conversion en date prevue dans le pipeline ADF.
- **OBS-008 :** Les valeurs de SECTEUR sont toutes en majuscules (AGRICOLE, COMMERCIAL, INDUSTRIEL,
  INSTITUTIONNEL, RESIDENTIEL). Distribution parfaitement equilibree : 2040 occurrences par secteur
  (17 regions x 120 mois). Normalisation en format titre necessaire.
- **OBS-009 :** La colonne Total (kWh) est de type float64 -- pandas l'a infere directement.
  Son nom contient un espace et des parentheses. Renommage en total_kwh prevu.

## 4. Coherence temporelle preliminaire

- hq_demande couvre 2019-01-01 a 2024-01-01 (granularite horaire).
- hq_secteur couvre 2016-01-01 a 2025-12-01 (granularite mensuelle).
- La periode de chevauchement est 2019-01-01 a 2024-01-01.
- Les analyses croisees devront se limiter a cette fenetre commune.

## 5. Limitations de cette version

- Les types sont observes a partir de l'inspection des CSV dans pandas, sans schema formel.
- Aucun controle de qualite n'est encore applique (correction des nulls, doublons, valeurs invalides).
- La correspondance cible (vers Azure SQL) n'est pas encore definie.

## 6. Prochaines etapes

- Confirmer les doublons et qualifier les valeurs extremes dans le notebook `02_quality_rules.ipynb`.
- Definir les noms standardises des colonnes en base SQL (demande_mw, region, total_kwh, etc.).
- Ajouter une section de mapping source-vers-cible dans la version 0.5.
