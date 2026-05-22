/* ============================================================
Projet : Cadre de gouvernance et qualité des données - Hydro-Québec
Fichier : quality_check.sql
Auteur : Anthony MISSE
Date : 2026-05-22
Statut : Validé
Description :
Script de validation des données pour les tables finales
dbo.hq_demande et dbo.hq_secteur.
Les corrections sont appliquées dans Azure Data Factory;
ce script sert à vérifier la conformité après chargement.
============================================================ */

SET NOCOUNT ON;
GO

/* ============================================================
RQ-01 - Complétude de demande_mw
Table : dbo.hq_demande
Seuil : aucune valeur nulle tolérée après correction
============================================================ */

SELECT
    'RQ-01' AS rule_id,
    COUNT(*) AS nb_nulls,
    CAST(
        100.0 * COUNT(*) / NULLIF(
            (
                SELECT COUNT(*)
                FROM dbo.hq_demande
            ),
            0
        ) AS decimal(10, 2)
    ) AS pct_nulls
FROM dbo.hq_demande
WHERE
    demande_mw IS NULL;
GO

/* ============================================================
RQ-02 - Convertibilité de la colonne date
Table : dbo.hq_demande
Format source attendu : ISO 8601 avec fuseau horaire
============================================================ */

SELECT 'RQ-02' AS rule_id, COUNT(*) AS nb_dates_invalides
FROM dbo.hq_demande
WHERE
    TRY_CONVERT (datetime2, [date]) IS NULL;
GO

/* ============================================================
RQ-03 - Unicité des timestamps
Table : dbo.hq_demande
Seuil : aucun doublon sur [date]
============================================================ */

SELECT 'RQ-03' AS rule_id, [date], COUNT(*) AS nb_occurrences
FROM dbo.hq_demande
GROUP BY
    [date]
HAVING
    COUNT(*) > 1;
GO

/* ============================================================
RQ-04 - Valeurs extrêmes de demande_mw
Table : dbo.hq_demande
Contrôle exploratoire : seuil IQR documenté
============================================================ */

SELECT
    'RQ-04' AS rule_id,
    COUNT(*) AS nb_valeurs_au_dessus_seuil_iqr
FROM dbo.hq_demande
WHERE
    demande_mw > 37005.60;
GO

/* ============================================================
RQ-04b - Valeurs techniquement impossibles de demande_mw
Table : dbo.hq_demande
Seuil : > 45000 MW interdit
============================================================ */

SELECT
    'RQ-04b' AS rule_id,
    COUNT(*) AS nb_valeurs_impossibles
FROM dbo.hq_demande
WHERE
    demande_mw > 45000;
GO

/* ============================================================
RQ-06 - Conformité des valeurs de secteur
Table : dbo.hq_secteur
Référence : Agricole, Commercial, Industriel, Institutionnel, Résidentiel
============================================================ */

SELECT
    'RQ-06' AS rule_id,
    secteur,
    COUNT(*) AS nb_occurrences
FROM dbo.hq_secteur
GROUP BY
    secteur
ORDER BY secteur;
GO

/* ============================================================
RQ-07 - Complétude et validité de total_kwh
Table : dbo.hq_secteur
Seuil : aucune valeur nulle ou <= 0
============================================================ */

SELECT
    'RQ-07' AS rule_id,
    SUM(
        CASE
            WHEN total_kwh IS NULL THEN 1
            ELSE 0
        END
    ) AS nb_nulls,
    SUM(
        CASE
            WHEN total_kwh <= 0 THEN 1
            ELSE 0
        END
    ) AS nb_non_positifs
FROM dbo.hq_secteur;
GO

/* ============================================================
Vérification la normalisation des valeurs de secteur
============================================================ */

SELECT DISTINCT secteur FROM dbo.hq_secteur ORDER BY secteur;
GO

/* ============================================================
Vérification le chevauchement temporel pour l’analyse croisée
============================================================ */

SELECT MIN([date]) AS date_min, MAX([date]) AS date_max
FROM dbo.hq_demande;
GO

SELECT MIN([date]) AS date_min, MAX([date]) AS date_max
FROM dbo.hq_secteur;
GO