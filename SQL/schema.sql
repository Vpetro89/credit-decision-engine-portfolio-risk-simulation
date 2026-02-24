-- ============================================
-- CREDIT DECISION ENGINE & PORTFOLIO RISK SCHEMA
-- PostgreSQL Compatible
-- ============================================

DROP TABLE IF EXISTS fact_transactions CASCADE;
DROP TABLE IF EXISTS fact_account_snapshot CASCADE;
DROP TABLE IF EXISTS fact_accounts CASCADE;
DROP TABLE IF EXISTS fact_applications CASCADE;
DROP TABLE IF EXISTS dim_decision_rules CASCADE;
DROP TABLE IF EXISTS dim_fico_band CASCADE;
DROP TABLE IF EXISTS dim_applicant CASCADE;

-- ============================================
-- DIMENSION TABLES
-- ============================================

CREATE TABLE dim_applicant (
    applicant_id        SERIAL PRIMARY KEY,
    state               VARCHAR(50),
    employment_type     VARCHAR(50),
    tenure_years        NUMERIC(5,2),
    income_band         VARCHAR(50)
);

CREATE TABLE dim_fico_band (
    fico_band_id    SERIAL PRIMARY KEY,
    min_score       INT NOT NULL,
    max_score       INT NOT NULL,
    risk_tier       VARCHAR(50) NOT NULL
);

CREATE TABLE dim_decision_rules (
    rule_id             SERIAL PRIMARY KEY,
    min_fico            INT NOT NULL,
    max_fico            INT NOT NULL,
    max_dti             NUMERIC(5,2),
    decision_outcome    VARCHAR(50) NOT NULL,
    rule_version        INT NOT NULL,
    effective_date      DATE NOT NULL
);

-- ============================================
-- FACT TABLES
-- ============================================

CREATE TABLE fact_applications (
    application_id      SERIAL PRIMARY KEY,
    applicant_id        INT REFERENCES dim_applicant(applicant_id),
    application_date    DATE NOT NULL,
    requested_amount    NUMERIC(14,2),
    fico_score          INT NOT NULL,
    income              NUMERIC(14,2),
    dti_ratio           NUMERIC(5,2),
    decision_status     VARCHAR(50),
    decision_reason_code VARCHAR(100)
);

CREATE TABLE fact_accounts (
    account_id          SERIAL PRIMARY KEY,
    applicant_id        INT REFERENCES dim_applicant(applicant_id),
    origination_date    DATE NOT NULL,
    credit_limit        NUMERIC(14,2),
    current_balance     NUMERIC(14,2),
    utilization_ratio   NUMERIC(6,4)
);

CREATE TABLE fact_account_snapshot (
    snapshot_id         SERIAL PRIMARY KEY,
    account_id          INT REFERENCES fact_accounts(account_id),
    snapshot_date       DATE NOT NULL,
    delinquency_status  VARCHAR(50),
    days_past_due       INT,
    balance             NUMERIC(14,2)
);

CREATE TABLE fact_transactions (
    transaction_id      SERIAL PRIMARY KEY,
    account_id          INT REFERENCES fact_accounts(account_id),
    transaction_date    DATE NOT NULL,
    amount              NUMERIC(14,2),
    merchant_category   VARCHAR(100),
    fraud_flag          BOOLEAN DEFAULT FALSE
);

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================

CREATE INDEX idx_applications_fico ON fact_applications(fico_score);
CREATE INDEX idx_accounts_applicant ON fact_accounts(applicant_id);
CREATE INDEX idx_snapshot_account_date ON fact_account_snapshot(account_id, snapshot_date);
CREATE INDEX idx_transactions_account_date ON fact_transactions(account_id, transaction_date);

-- ============================================
-- END SCHEMA
-- ============================================