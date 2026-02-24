-- ============================================
-- DATA GENERATION SCRIPT
-- PostgreSQL Compatible
-- ============================================

-- --------------------------------------------
-- Seed FICO Bands
-- --------------------------------------------

INSERT INTO dim_fico_band (min_score, max_score, risk_tier) VALUES
(300, 579, 'High Risk'),
(580, 639, 'Near Prime'),
(640, 679, 'Prime'),
(680, 850, 'Super Prime');

-- --------------------------------------------
-- Seed Decision Rules (Version 1)
-- --------------------------------------------

INSERT INTO dim_decision_rules
(min_fico, max_fico, max_dti, decision_outcome, rule_version, effective_date)
VALUES
(300, 579, 100.00, 'Declined', 1, CURRENT_DATE),
(580, 640, 45.00, 'Refer', 1, CURRENT_DATE),
(641, 679, 50.00, 'Approved', 1, CURRENT_DATE),
(680, 850, 40.00, 'Approved', 1, CURRENT_DATE);

-- --------------------------------------------
-- Generate Applicants
-- --------------------------------------------

INSERT INTO dim_applicant (state, employment_type, tenure_years, income_band)
SELECT
    (ARRAY['LA','TX','FL','GA','AL'])[floor(random()*5)+1],
    (ARRAY['Salaried','Self-Employed','Contract','Unemployed'])[floor(random()*4)+1],
    ROUND((random()*15)::numeric,2),
    (ARRAY['Low','Moderate','High','Very High'])[floor(random()*4)+1]
FROM generate_series(1,500);

-- --------------------------------------------
-- Generate Applications
-- --------------------------------------------

INSERT INTO fact_applications
(applicant_id, application_date, requested_amount, fico_score, income, dti_ratio)
SELECT
    applicant_id,
    CURRENT_DATE - (random()*365)::int,
    ROUND((random()*25000 + 5000)::numeric,2),
    (random()*550 + 300)::int,
    ROUND((random()*90000 + 20000)::numeric,2),
    ROUND((random()*60)::numeric,2)
FROM dim_applicant;

-- --------------------------------------------
-- Apply Decision Logic
-- --------------------------------------------

UPDATE fact_applications a
SET decision_status = r.decision_outcome,
    decision_reason_code = CONCAT('RULE_V', r.rule_version)
FROM dim_decision_rules r
WHERE a.fico_score BETWEEN r.min_fico AND r.max_fico
AND a.dti_ratio <= r.max_dti;

-- --------------------------------------------
-- Generate Accounts (Approved Only)
-- --------------------------------------------

INSERT INTO fact_accounts
(applicant_id, origination_date, credit_limit, current_balance, utilization_ratio)
SELECT
    applicant_id,
    application_date,
    ROUND((random()*20000 + 5000)::numeric,2),
    ROUND((random()*15000)::numeric,2),
    ROUND((random())::numeric,4)
FROM fact_applications
WHERE decision_status = 'Approved';

-- --------------------------------------------
-- Generate Monthly Snapshots (12 Months)
-- --------------------------------------------

INSERT INTO fact_account_snapshot
(account_id, snapshot_date, delinquency_status, days_past_due, balance)
SELECT
    a.account_id,
    date_trunc('month', CURRENT_DATE) - (interval '1 month' * gs.month_offset),
    (ARRAY['Current','30','60','90+'])[floor(random()*4)+1],
    (random()*120)::int,
    ROUND((a.current_balance * (1 + random()*0.1))::numeric,2)
FROM fact_accounts a
CROSS JOIN generate_series(0,11) AS gs(month_offset);

-- --------------------------------------------
-- Generate Transactions (Per Account)
-- --------------------------------------------

INSERT INTO fact_transactions
(account_id, transaction_date, amount, merchant_category)
SELECT
    a.account_id,
    CURRENT_DATE - (random()*180)::int,
    ROUND((random()*500 + 10)::numeric,2),
    (ARRAY['Retail','Travel','Food','Electronics','Utilities'])[floor(random()*5)+1]
FROM fact_accounts a,
generate_series(1,50);

-- --------------------------------------------
-- Inject Fraud Spikes
-- --------------------------------------------

UPDATE fact_transactions
SET amount = amount * 5,
    fraud_flag = TRUE
WHERE transaction_id IN (
    SELECT transaction_id
    FROM fact_transactions
    ORDER BY random()
    LIMIT 50
);

-- ============================================
-- END DATA GENERATION
-- ============================================