# Credit Decision Engine & Portfolio Risk Monitoring Simulation

This repository simulates a regulated banking credit decision and
portfolio risk monitoring environment. It demonstrates underwriting rule
evaluation, portfolio segmentation, delinquency roll analysis, fraud
anomaly detection, and audit-ready SQL logic.

The project is structured to reflect institutional-grade data modeling
and defensible decision frameworks used in regulated financial
environments.

------------------------------------------------------------------------

## 1. Business Objective

Design and implement a simulated credit lifecycle system that supports:

-   Underwriting decision logic
-   Risk tier segmentation
-   Portfolio exposure monitoring
-   Delinquency roll-rate analysis
-   Fraud anomaly detection
-   Expected loss simulation
-   Audit traceability and governance framing

The system emphasizes reproducible SQL transformations, transparent
decision rationale, and structured rule evaluation.

------------------------------------------------------------------------

## 2. Data Model Overview

### Fact Tables

fact_applications\
- application_id (PK)\
- applicant_id (FK)\
- application_date\
- requested_amount\
- fico_score\
- income\
- dti_ratio\
- decision_status\
- decision_reason_code

fact_accounts\
- account_id (PK)\
- applicant_id (FK)\
- origination_date\
- credit_limit\
- current_balance\
- utilization_ratio

fact_account_snapshot\
- account_id (FK)\
- snapshot_date\
- delinquency_status\
- days_past_due\
- balance

fact_transactions\
- transaction_id (PK)\
- account_id (FK)\
- transaction_date\
- amount\
- merchant_category\
- fraud_flag

------------------------------------------------------------------------

### Dimension Tables

dim_applicant\
- applicant_id (PK)\
- state\
- employment_type\
- tenure_years\
- income_band

dim_fico_band\
- fico_band_id (PK)\
- min_score\
- max_score\
- risk_tier

dim_decision_rules\
- rule_id\
- min_fico\
- max_fico\
- max_dti\
- decision_outcome\
- rule_version\
- effective_date

------------------------------------------------------------------------

## 3. Decision Rule Evaluation

Underwriting logic is externalized through a rule table to support audit
traceability and version control.

Example evaluation logic:

``` sql
SELECT a.application_id,
       r.decision_outcome
FROM fact_applications a
JOIN dim_decision_rules r
  ON a.fico_score BETWEEN r.min_fico AND r.max_fico
 AND a.dti_ratio <= r.max_dti;
```

Example policy simulation:

-   Auto decline if fico_score \< 580\
-   Refer if 580--640 and DTI \> 45%\
-   Approve if fico_score \> 680 and DTI \< 40%

Rules are versioned to simulate governance and model oversight
environments.

------------------------------------------------------------------------

## 4. Portfolio Monitoring Queries

### Approval Rate by Risk Tier

``` sql
WITH banded AS (
    SELECT a.application_id,
           f.risk_tier,
           a.decision_status
    FROM fact_applications a
    JOIN dim_fico_band f
      ON a.fico_score BETWEEN f.min_score AND f.max_score
)
SELECT risk_tier,
       COUNT(*) AS total_apps,
       SUM(CASE WHEN decision_status = 'Approved' THEN 1 ELSE 0 END) AS approvals,
       ROUND(
         100.0 * SUM(CASE WHEN decision_status = 'Approved' THEN 1 ELSE 0 END)
         / COUNT(*), 2
       ) AS approval_rate_pct
FROM banded
GROUP BY risk_tier;
```

------------------------------------------------------------------------

### Delinquency Roll-Rate Analysis

``` sql
SELECT account_id,
       snapshot_date,
       delinquency_status,
       LAG(delinquency_status)
           OVER (PARTITION BY account_id ORDER BY snapshot_date) AS prior_status
FROM fact_account_snapshot;
```

------------------------------------------------------------------------

### Fraud Anomaly Monitoring

``` sql
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
           WHEN amount > rolling_avg + 3 * rolling_stddev 
           THEN 1 ELSE 0 
       END AS anomaly_flag
FROM fact_transactions;
```

------------------------------------------------------------------------

## 5. Portfolio Risk KPIs

-   Total Exposure (EAD)
-   Utilization by Risk Tier
-   30/60/90+ Day Delinquency Rates
-   Roll-Rate Migration
-   Fraud Alert Volume
-   Approval Rate Stability Over Time
-   Vintage (Cohort) Analysis
-   Expected Loss Simulation (PD × LGD × EAD)

Example Expected Loss:

``` sql
SELECT account_id,
       current_balance AS ead,
       pd_rate,
       lgd_rate,
       current_balance * pd_rate * lgd_rate AS expected_loss
FROM portfolio_risk_view;
```

------------------------------------------------------------------------

## 6. Governance & Audit Framing

This simulation demonstrates:

-   Externalized rule logic
-   Version-controlled decision policy
-   Segmented risk tier reporting
-   Reproducible SQL transformations
-   Transparent decision reason codes
-   Lifecycle-based performance tracking

------------------------------------------------------------------------

## 7. Repository Structure

/sql\
/diagrams\
/dashboard\
README.md

------------------------------------------------------------------------

## 8. Technologies Used

-   PostgreSQL
-   Window Functions
-   Cohort Analysis
-   Risk Segmentation Logic
-   Statistical Anomaly Detection

------------------------------------------------------------------------

## 9. Intended Audience

-   Risk Analytics Teams
-   Credit Strategy Analysts
-   Fraud Monitoring Teams
-   Governance & Model Oversight
-   Data Engineering in Regulated Banking

------------------------------------------------------------------------

## 10. Future Enhancements

-   CECL multi-scenario stress testing
-   Behavioral score migration tracking
-   Automated model drift monitoring
-   Real-time decision engine simulation
