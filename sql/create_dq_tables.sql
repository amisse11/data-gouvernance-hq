/* ============================================================
Projet : Cadre de gouvernance et qualité des données - Hydro-Québec
Script : create_dq_tables.sql
Auteur : Anthony MISSE
Date : 2026-05-23
Statut : Validé
Description :
Création des tables de suivi de qualité :
- dbo.dq_error_log
- dbo.dq_quality_summary
============================================================ */

SET NOCOUNT ON;
GO

/* ============================================================
Table : dbo.dq_error_log
Rôle  : Journal détaillé des anomalies détectées
============================================================ */

IF OBJECT_ID ('dbo.dq_error_log', 'U') IS NULL
BEGIN
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

END;
GO

/* ============================================================
Table : dbo.dq_quality_summary
Rôle  : Synthèse des contrôles pour reporting / Power BI
============================================================ */

IF OBJECT_ID ('dbo.dq_quality_summary', 'U') IS NULL
BEGIN
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

END;
GO