# Regles de qualite des donnees

**Projet :** Cadre de gouvernance et qualite des donnees - Hydro-Quebec

**Auteur :** Anthony MISSE

**Date :** 2026-05-10

**Version :** 0.1

**Statut :** Brouillon

---

## 1. Contexte

Cette premiere version des regles de qualite est basee sur l'exploration effectuee dans le notebook
01_exploration.ipynb. Les constats proviennent de l'analyse directe des deux fichiers CSV sources.
Les seuils formels ([CRIT], [HIGH], [MED], etc.) et les actions correctives definitives seront
etablis dans la version 0.5, apres mise en place des controles Python.

## 2. Regles identifiees (brouillon)

### 2.1 Completude de demande_mw (RQ-01)

- **Problematique :** presence de valeurs nulles dans la colonne demande (MW).
- **Constat :** 45 valeurs nulles sur 43 824 lignes, soit 0.10 % (notebook 01_exploration.ipynb).
- **Impact :** sous-estimation possible de la demande horaire lors des agregations.
- **Hypothese de regle :** aucune valeur nulle n'est acceptable dans demande_mw.
- **Action envisagee :** interpolation lineaire si le taux reste inferieur a 1 % (438 lignes).

### 2.2 Format de la colonne date (RQ-02)

- **Problematique :** la colonne date est de type object (string).
- **Constat :** format ISO 8601 avec fuseau horaire (-05:00), ex. 2023-01-01T03:00:00-05:00.
- **Impact :** impossibilite d'effectuer des calculs ou des tris temporels sans conversion.
- **Hypothese de regle :** toute valeur non convertible en datetime2 doit etre signalee.
- **Action envisagee :** conversion dans le pipeline ADF via toTimestamp(..., "yyyy-MM-dd'T'HH:mm:ssXXX").

### 2.3 Unicite des timestamps (RQ-03)

- **Problematique :** doublons sur la colonne date.
- **Constat :** 6 doublons identifies dans le notebook 01_exploration.ipynb, correspondant aux nuits
  du premier dimanche de novembre (passage de l'heure avancee a l'heure normale au Quebec),
  plus une entree au 1er janvier 2023.
- **Hypothese de regle :** un seul enregistrement par horodatage; conserver la premiere occurrence.
- **Action envisagee :** drop_duplicates(subset=['date'], keep='first').
  Nombre de lignes apres correction : 43 818.

### 2.4 Plage de valeurs demande_mw (RQ-04)

- **Problematique :** presence de valeurs tres elevees dans demande (MW).
- **Constat :** seuil IQR superieur calcule a 37 005.60 MW; 94 valeurs depassent ce seuil.
  Ces valeurs sont concentrees en janvier-fevrier 2022 et 2023 (vagues de grand froid au Quebec).
- **Hypothese de regle :** les valeurs depassant le seuil IQR ne sont pas automatiquement aberrantes.
  Une distinction est necessaire entre valeurs hors plage technique et pics legitimes.
- **Action envisagee :**
    - Valeurs > plage technique (ex. > 45 000 MW) : exclusion.
    - Valeurs entre 37 005.60 MW et 45 000 MW : conserver et documenter.

### 2.5 Conformite des valeurs de SECTEUR (RQ-06)

- **Problematique :** valeurs en majuscules dans la colonne SECTEUR.
- **Constat :** 5 valeurs distinctes (AGRICOLE, COMMERCIAL, INDUSTRIEL, INSTITUTIONNEL, RESIDENTIEL),
  toutes en majuscules. Distribution equlibree : 2040 occurrences par secteur.
- **Hypothese de regle :** les valeurs doivent etre normalisees en format titre pour les analyses.
- **Action envisagee :** normalisation via str.title() en Python ou initCap(lower()) dans ADF.

### 2.6 Completude de Total (kWh) (RQ-07)

- **Problematique :** possibilite de valeurs nulles ou negatives dans Total (kWh).
- **Constat :** aucune valeur nulle ni valeur <= 0 detectee dans l'exploration initiale.
- **Hypothese de regle :** toute valeur nulle ou negative est invalide.
- **Action envisagee :** verification systematique dans le notebook 02_quality_rules.ipynb.

## 3. Observations non encore formalisees

Les points suivants sont notes mais ne sont pas encore traduits en regles formelles :

- Coherence temporelle entre les deux tables : periode de chevauchement 2019-01-01 a 2024-01-01.
  Impact sur les analyses croisees a definir.
- Completude mensuelle par region dans hq_secteur : la distribution equlibree observee (2040 par
  secteur) suggere qu'il n'y a pas de mois manquants, mais a confirmer formellement.

## 4. Prochaines etapes

- Formaliser les seuils de blocage et d'alerte ([CRIT], [HIGH], [MED], [LOW], [INFO]).
- Implanter les controles automatises dans le notebook 02_quality_rules.ipynb.
- Produire un journal d'anomalies (anomalies_log.csv) apres application des controles.
- Preparer la version 0.5 apres mise en place des scripts Python.
