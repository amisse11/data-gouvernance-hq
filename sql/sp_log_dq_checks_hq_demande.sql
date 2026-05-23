/* ============================================================
Procédure : dbo.sp_log_dq_checks_hq_demande
Rôle      : Journaliser les contrôles qualité pour dbo.hq_demande
============================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_log_dq_checks_hq_demande
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @total_rows int;

    SELECT @total_rows = COUNT(*)
    FROM dbo.hq_demande;

    /* RQ-01 : Complétude de demande_mw */
    DECLARE @nb_nulls int;
    SELECT @nb_nulls = COUNT(*)
    FROM dbo.hq_demande
    WHERE demande_mw IS NULL;

    IF @nb_nulls > 0
    BEGIN
        INSERT INTO dbo.dq_error_log
        (
            rule_id, table_name, column_name, anomaly_type, anomaly_count,
            severity, action_taken, details
        )
        VALUES
        (
            'RQ-01', 'dbo.hq_demande', 'demande_mw', 'missing_value', @nb_nulls,
            'WARN', 'interpolation_lineaire', 'Valeurs nulles détectées sur demande_mw'
        );
    END;

    INSERT INTO dbo.dq_quality_summary
    (
        rule_id, table_name, total_rows, anomaly_count, pct_anomalies,
        severity, status
    )
    VALUES
    (
        'RQ-01', 'dbo.hq_demande', @total_rows, @nb_nulls,
        CASE WHEN @total_rows = 0 THEN 0 ELSE CAST(100.0 * @nb_nulls / @total_rows AS decimal(5,2)) END,
        CASE WHEN @nb_nulls > 0 THEN 'WARN' ELSE 'PASS' END,
        CASE WHEN @nb_nulls > 0 THEN 'PASS après correction' ELSE 'PASS' END
    );

    /* RQ-02 : Convertibilité de date */
    DECLARE @nb_dates_invalides int;
    SELECT @nb_dates_invalides = COUNT(*)
    FROM dbo.hq_demande
    WHERE TRY_CONVERT(datetime2, [date]) IS NULL;

    IF @nb_dates_invalides > 0
    BEGIN
        INSERT INTO dbo.dq_error_log
        (
            rule_id, table_name, column_name, anomaly_type, anomaly_count,
            severity, action_taken, details
        )
        VALUES
        (
            'RQ-02', 'dbo.hq_demande', 'date', 'invalid_datetime', @nb_dates_invalides,
            'CRIT', 'aucune', 'Dates non convertibles détectées'
        );
    END;

    INSERT INTO dbo.dq_quality_summary
    (
        rule_id, table_name, total_rows, anomaly_count, pct_anomalies,
        severity, status
    )
    VALUES
    (
        'RQ-02', 'dbo.hq_demande', @total_rows, @nb_dates_invalides,
        CASE WHEN @total_rows = 0 THEN 0 ELSE CAST(100.0 * @nb_dates_invalides / @total_rows AS decimal(5,2)) END,
        CASE WHEN @nb_dates_invalides > 0 THEN 'CRIT' ELSE 'PASS' END,
        CASE WHEN @nb_dates_invalides > 0 THEN 'FAIL' ELSE 'PASS' END
    );

    /* RQ-03 : Unicité des timestamps */
    DECLARE @nb_dup_rows int;
    SELECT @nb_dup_rows = COUNT(*)
    FROM (
        SELECT [date]
        FROM dbo.hq_demande
        GROUP BY [date]
        HAVING COUNT(*) > 1
    ) d;

    IF @nb_dup_rows > 0
    BEGIN
        INSERT INTO dbo.dq_error_log
        (
            rule_id, table_name, column_name, anomaly_type, anomaly_count,
            severity, action_taken, details
        )
        VALUES
        (
            'RQ-03', 'dbo.hq_demande', 'date', 'duplicate_timestamp', @nb_dup_rows,
            'WARN', 'keep_first', 'Doublons de timestamp détectés'
        );
    END;

    INSERT INTO dbo.dq_quality_summary
    (
        rule_id, table_name, total_rows, anomaly_count, pct_anomalies,
        severity, status
    )
    VALUES
    (
        'RQ-03', 'dbo.hq_demande', @total_rows, @nb_dup_rows,
        CASE WHEN @total_rows = 0 THEN 0 ELSE CAST(100.0 * @nb_dup_rows / @total_rows AS decimal(5,2)) END,
        CASE WHEN @nb_dup_rows > 0 THEN 'WARN' ELSE 'PASS' END,
        CASE WHEN @nb_dup_rows > 0 THEN 'PASS après correction' ELSE 'PASS' END
    );

    /* RQ-04 : Valeurs extrêmes */
    DECLARE @nb_outliers_iqr int;
    SELECT @nb_outliers_iqr = COUNT(*)
    FROM dbo.hq_demande
    WHERE demande_mw > 37005.60;

    IF @nb_outliers_iqr > 0
    BEGIN
        INSERT INTO dbo.dq_error_log
        (
            rule_id, table_name, column_name, anomaly_type, anomaly_count,
            severity, action_taken, details
        )
        VALUES
        (
            'RQ-04', 'dbo.hq_demande', 'demande_mw', 'outlier_iqr', @nb_outliers_iqr,
            'INFO', 'conserver', 'Valeurs au-dessus du seuil IQR'
        );
    END;

    INSERT INTO dbo.dq_quality_summary
    (
        rule_id, table_name, total_rows, anomaly_count, pct_anomalies,
        severity, status
    )
    VALUES
    (
        'RQ-04', 'dbo.hq_demande', @total_rows, @nb_outliers_iqr,
        CASE WHEN @total_rows = 0 THEN 0 ELSE CAST(100.0 * @nb_outliers_iqr / @total_rows AS decimal(5,2)) END,
        CASE WHEN @nb_outliers_iqr > 0 THEN 'INFO' ELSE 'PASS' END,
        CASE WHEN @nb_outliers_iqr > 0 THEN 'INFO' ELSE 'PASS' END
    );

    /* RQ-04b : Valeurs techniquement impossibles */
    DECLARE @nb_too_high int;
    SELECT @nb_too_high = COUNT(*)
    FROM dbo.hq_demande
    WHERE demande_mw > 45000;

    IF @nb_too_high > 0
    BEGIN
        INSERT INTO dbo.dq_error_log
        (
            rule_id, table_name, column_name, anomaly_type, anomaly_count,
            severity, action_taken, details
        )
        VALUES
        (
            'RQ-04b', 'dbo.hq_demande', 'demande_mw', 'outlier_tech_gt_45000', @nb_too_high,
            'CRIT', 'aucune', 'Valeurs > 45000 MW détectées'
        );
    END;

    INSERT INTO dbo.dq_quality_summary
    (
        rule_id, table_name, total_rows, anomaly_count, pct_anomalies,
        severity, status
    )
    VALUES
    (
        'RQ-04b', 'dbo.hq_demande', @total_rows, @nb_too_high,
        CASE WHEN @total_rows = 0 THEN 0 ELSE CAST(100.0 * @nb_too_high / @total_rows AS decimal(5,2)) END,
        CASE WHEN @nb_too_high > 0 THEN 'CRIT' ELSE 'PASS' END,
        CASE WHEN @nb_too_high > 0 THEN 'FAIL' ELSE 'PASS' END
    );
END;
GO