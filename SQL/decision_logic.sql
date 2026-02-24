-- ============================================
-- DECISION & PORTFOLIO ANALYTICS LAYER
-- ============================================

-- --------------------------------------------
-- 1. Approval Rate by Risk Tier
-- --------------------------------------------

WITH banded AS (
    SELECT a.application_id,
           f.risk_tier,
           a.decision_status
    FROM fact_applications a
    JOIN dim_fico_band f
      ON a.fico_score BETWEEN f.min_score AND f.max_score
)
SELECT risk_tier,
       COUNT(*) AS total_applications,
       SUM(CASE WHEN decision_status = 'Approved' THEN 1 ELSE 0 END) AS approvals,
       ROUND(
         100.0 * SUM(CASE WHEN decision_status = 'Approved' THEN 1 ELSE 0 END)
         / COUNT(*), 2
       ) AS approval_rate_pct
FROM banded
GROUP BY risk_tier
ORDER BY risk_tier;

-- --------------------------------------------
-- 2. Portfolio Exposure by Risk Tier
-- --------------------------------------------

SELECT f.risk_tier,
       COUNT(a.account_id) AS account_count,
       SUM(a.current_balance) AS total_exposure,
       ROUND(AVG(a.utilization_ratio), 4) AS avg_utilization
FROM fact_accounts a
JOIN fact_applications fa
  ON a.applicant_id = fa.applicant_id
JOIN dim_fico_band f
  ON fa.fico_score BETWEEN f.min_score AND f.max_score
GROUP BY f.risk_tier
ORDER BY total_exposure DESC;

-- --------------------------------------------
-- 3. Delinquency Roll Analysis
-- --------------------------------------------

SELECT account_id,
       snapshot_date,
       delinquency_status,
       LAG(delinquency_status)
         OVER (PARTITION BY account_id ORDER BY snapshot_date) AS prior_status
FROM fact_account_snapshot
ORDER BY account_id, snapshot_date;

-- --------------------------------------------
-- 4. 30/60/90+ Delinquency Buckets (Latest Month)
-- --------------------------------------------

WITH latest_snapshot AS (
    SELECT *
    FROM fact_account_snapshot
    WHERE snapshot_date = (
        SELECT MAX(snapshot_date) FROM fact_account_snapshot
    )
)
SELECT delinquency_status,
       COUNT(*) AS account_count,
       ROUND(
         100.0 * COUNT(*) /
         (SELECT COUNT(*) FROM latest_snapshot),
         2
       ) AS percentage_of_portfolio
FROM latest_snapshot
GROUP BY delinquency_status
ORDER BY delinquency_status;

-- --------------------------------------------
-- 5. Fraud Anomaly Detection (Statistical Threshold)
-- --------------------------------------------

SELECT account_id,
       transaction_date,
       amount,
       AVG(amount) OVER (
           PARTITION BY account_id
           ORDER BY transaction_date
           ROWS BETWEEN 30 PRECEDING AND CURRENT ROW
       ) AS rolling_avg,
       STDDEV(amount) OVER (
           PARTITION BY account_id
           ORDER BY transaction_date
           ROWS BETWEEN 30 PRECEDING AND CURRENT ROW
       ) AS rolling_stddev,
       CASE
           WHEN amount >
                AVG(amount) OVER (
                    PARTITION BY account_id
                    ORDER BY transaction_date
                    ROWS BETWEEN 30 PRECEDING AND CURRENT ROW
                )
                + 3 * STDDEV(amount) OVER (
                    PARTITION BY account_id
                    ORDER BY transaction_date
                    ROWS BETWEEN 30 PRECEDING AND CURRENT ROW
                )
           THEN 1 ELSE 0
       END AS anomaly_flag
FROM fact_transactions
ORDER BY account_id, transaction_date;

-- --------------------------------------------
-- 6. Expected Loss Simulation (PD x LGD x EAD)
-- --------------------------------------------

WITH risk_mapping AS (
    SELECT fa.applicant_id,
           f.risk_tier,
           CASE
               WHEN f.risk_tier = 'High Risk' THEN 0.08
               WHEN f.risk_tier = 'Near Prime' THEN 0.05
               WHEN f.risk_tier = 'Prime' THEN 0.03
               WHEN f.risk_tier = 'Super Prime' THEN 0.01
           END AS pd_rate
    FROM fact_applications fa
    JOIN dim_fico_band f
      ON fa.fico_score BETWEEN f.min_score AND f.max_score
)
SELECT a.account_id,
       a.current_balance AS ead,
       r.pd_rate,
       0.45 AS lgd_rate,
       ROUND(a.current_balance * r.pd_rate * 0.45, 2) AS expected_loss
FROM fact_accounts a
JOIN risk_mapping r
  ON a.applicant_id = r.applicant_id
ORDER BY expected_loss DESC;

-- ============================================
-- END ANALYTICS LAYER
-- ============================================