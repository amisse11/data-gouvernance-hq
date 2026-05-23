/* ============================================================
Procédure : dbo.sp_log_dq_checks_hq_secteur
Rôle      : Journaliser les contrôles qualité pour dbo.hq_secteur
============================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_log_dq_checks_hq_secteur
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @total_rows int;

    SELECT @total_rows = COUNT(*)
    FROM dbo.hq_secteur;

    /* RQ-06 : Conformité de secteur */
    DECLARE @nb_secteur_non_conformes int;
    SELECT @nb_secteur_non_conformes = COUNT(*)
    FROM dbo.hq_secteur
    WHERE secteur NOT IN ('Agricole', 'Commercial', 'Industriel', 'Institutionnel', 'Résidentiel');

    IF @nb_secteur_non_conformes > 0
    BEGIN
        INSERT INTO dbo.dq_error_log
        (
            rule_id, table_name, column_name, anomaly_type, anomaly_count,
            severity, action_taken, details
        )
        VALUES
        (
            'RQ-06', 'dbo.hq_secteur', 'secteur', 'invalid_domain', @nb_secteur_non_conformes,
            'WARN', 'normalisation_title_case', 'Valeurs de secteur non conformes'
        );
    END;

    INSERT INTO dbo.dq_quality_summary
    (
        rule_id, table_name, total_rows, anomaly_count, pct_anomalies,
        severity, status
    )
    VALUES
    (
        'RQ-06', 'dbo.hq_secteur', @total_rows, @nb_secteur_non_conformes,
        CASE WHEN @total_rows = 0 THEN 0 ELSE CAST(100.0 * @nb_secteur_non_conformes / @total_rows AS decimal(5,2)) END,
        CASE WHEN @nb_secteur_non_conformes > 0 THEN 'WARN' ELSE 'PASS' END,
        CASE WHEN @nb_secteur_non_conformes > 0 THEN 'PASS après normalisation' ELSE 'PASS' END
    );

    /* RQ-07 : Complétude et positivité de total_kwh */
    DECLARE @nb_total_kwh_bad int;
    SELECT @nb_total_kwh_bad = COUNT(*)
    FROM dbo.hq_secteur
    WHERE total_kwh IS NULL OR total_kwh <= 0;

    IF @nb_total_kwh_bad > 0
    BEGIN
        INSERT INTO dbo.dq_error_log
        (
            rule_id, table_name, column_name, anomaly_type, anomaly_count,
            severity, action_taken, details
        )
        VALUES
        (
            'RQ-07', 'dbo.hq_secteur', 'total_kwh', 'null_or_non_positive', @nb_total_kwh_bad,
            'CRIT', 'aucune', 'Valeurs nulles ou non positives détectées'
        );
    END;

    INSERT INTO dbo.dq_quality_summary
    (
        rule_id, table_name, total_rows, anomaly_count, pct_anomalies,
        severity, status
    )
    VALUES
    (
        'RQ-07', 'dbo.hq_secteur', @total_rows, @nb_total_kwh_bad,
        CASE WHEN @total_rows = 0 THEN 0 ELSE CAST(100.0 * @nb_total_kwh_bad / @total_rows AS decimal(5,2)) END,
        CASE WHEN @nb_total_kwh_bad > 0 THEN 'CRIT' ELSE 'PASS' END,
        CASE WHEN @nb_total_kwh_bad > 0 THEN 'FAIL' ELSE 'PASS' END
    );
END;
GO