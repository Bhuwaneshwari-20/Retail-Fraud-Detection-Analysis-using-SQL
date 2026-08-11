/* ============================================================================
   RETAIL FRAUD DETECTION ANALYSIS — COMPLETE MYSQL PROJECT
   ============================================================================
   Business Problem:
   A retail company is facing rising online transaction fraud. This project
   cleans raw transaction data, engineers behavioral risk features, and extracts business insights to help
   the company detect fraud faster and reduce financial losses.
   ============================================================================ */
   CREATE DATABASE IF NOT EXISTS Retail_Fraud;
   USE Retail_Fraud;
   
	/* ============================================================================
   PART 1 — CLEANING
   ============================================================================ */
   
   -- 1a. Missing values check
SELECT
    SUM(transaction_id IS NULL) AS null_id,
    SUM(customer_id IS NULL) AS null_cust,
    SUM(transaction_amount IS NULL) AS null_amount
FROM retail_fraud_raw;

-- 1b. Duplicate transaction IDs
SELECT transaction_id, COUNT(*) AS cnt
FROM retail_fraud_raw
GROUP BY transaction_id
HAVING cnt > 1;

-- 1c. Invalid amounts (0 or negative — not a real purchase)
SELECT transaction_id, transaction_amount
FROM retail_fraud_raw
WHERE transaction_amount <= 0;   

-- 1d. Build the clean table, dropping invalid rows
CREATE TABLE retail_fraud_clean AS
SELECT *
FROM retail_fraud_raw
WHERE transaction_amount > 0;

-- 1e. fixing the datatypes of columns
ALTER TABLE retail_fraud_clean MODIFY customer_id VARCHAR(20);
ALTER TABLE retail_fraud_clean MODIFY transaction_id VARCHAR(20);
ALTER TABLE retail_fraud_clean MODIFY payment_method VARCHAR(30);
ALTER TABLE retail_fraud_clean MODIFY device_type VARCHAR(20);
ALTER TABLE retail_fraud_clean MODIFY location VARCHAR(50);
ALTER TABLE retail_fraud_clean MODIFY merchant_category VARCHAR(30);

ALTER TABLE retail_fraud_clean ADD COLUMN transaction_timestamp_fixed DATETIME;
SET SQL_SAFE_UPDATES = 0; -- by deafault sql was running on safe mode, now safe mode is off
UPDATE retail_fraud_clean
SET transaction_timestamp_fixed = STR_TO_DATE(transaction_timestamp, '%d-%m-%Y %H:%i');

ALTER TABLE retail_fraud_clean DROP COLUMN transaction_timestamp;
ALTER TABLE retail_fraud_clean CHANGE transaction_timestamp_fixed transaction_timestamp DATETIME;

-- 1f. Index for performance — every derived feature below looks up
-- "this customer's other transactions near this time", so this index makes
-- those lookups fast instead of scanning the whole table
ALTER TABLE retail_fraud_clean ADD INDEX idx_cust_time (customer_id, transaction_timestamp);

/* ============================================================================
Part 2: "New behavioral & risk columns — derived from raw data to detect fraud patterns"
============================================================================*/

ALTER TABLE retail_fraud_clean
    ADD COLUMN transaction_frequency_24h INT DEFAULT 0,
    ADD COLUMN avg_transaction_amount_7d DECIMAL(10,2),
    ADD COLUMN unusual_amount_flag INT DEFAULT 0,
    ADD COLUMN multiple_transactions_short_time INT DEFAULT 0,
    ADD COLUMN velocity_flag INT DEFAULT 0,
    ADD COLUMN risk_score INT DEFAULT 0,
    ADD COLUMN fraud_risk VARCHAR(10);

-- 2a. transaction_frequency_24h
UPDATE retail_fraud_clean a
JOIN (
    SELECT a.transaction_id, COUNT(*) AS freq
    FROM retail_fraud_clean a
    JOIN retail_fraud_clean b
        ON a.customer_id = b.customer_id
       AND b.transaction_timestamp < a.transaction_timestamp
       AND b.transaction_timestamp >= a.transaction_timestamp - INTERVAL 1 DAY
    GROUP BY a.transaction_id
) f ON a.transaction_id = f.transaction_id
SET a.transaction_frequency_24h = f.freq;
    
-- 2b. avg_transaction_amount_7d (rounded to 2 decimals to avoid truncation warnings)
UPDATE retail_fraud_clean a
JOIN (
    SELECT a.transaction_id, ROUND(AVG(b.transaction_amount), 2) AS avg_amt
    FROM retail_fraud_clean a
    JOIN retail_fraud_clean b
        ON a.customer_id = b.customer_id
       AND b.transaction_timestamp < a.transaction_timestamp
       AND b.transaction_timestamp >= a.transaction_timestamp - INTERVAL 7 DAY
    GROUP BY a.transaction_id
) t ON a.transaction_id = t.transaction_id
SET a.avg_transaction_amount_7d = t.avg_amt;
 
-- 2c. unusual_amount_flag
UPDATE retail_fraud_clean
SET unusual_amount_flag = 1
WHERE avg_transaction_amount_7d IS NOT NULL
  AND transaction_amount > 2 * avg_transaction_amount_7d;
 
-- 2d. multiple_transactions_short_time
UPDATE retail_fraud_clean
SET multiple_transactions_short_time = 1
WHERE transaction_frequency_24h >= 2;
 
-- 2e. velocity_flag (fast AND unusually high spend together)
UPDATE retail_fraud_clean
SET velocity_flag = 1
WHERE multiple_transactions_short_time = 1
  AND unusual_amount_flag = 1;
 
-- 2f. risk_score (sum of the 3 flags, 0 to 3)
UPDATE retail_fraud_clean
SET risk_score = unusual_amount_flag + multiple_transactions_short_time + velocity_flag;
 
-- 2g. fraud_risk label
UPDATE retail_fraud_clean
SET fraud_risk = CASE
    WHEN risk_score >= 2 THEN 'High'
    WHEN risk_score = 1 THEN 'Medium'
    ELSE 'Low'
END;

/* ============================================================================
   PART 3 — VALIDATION
   Does our engineered fraud_risk actually track real fraud outcomes?
   ============================================================================ */
 
SELECT
    fraud_risk,
    COUNT(*) AS total_transactions,
    ROUND(AVG(fraud_flag) * 100, 2) AS actual_fraud_rate_pct
FROM retail_fraud_clean
GROUP BY fraud_risk
ORDER BY actual_fraud_rate_pct DESC;

/* ============================================================================
   PART 4 — BUSINESS INSIGHTS
   ============================================================================ */
 
-- 4.1 Overall fraud rate
SELECT
    COUNT(*) AS total_transactions,
    SUM(fraud_flag) AS fraud_transactions,
    ROUND(SUM(fraud_flag) * 100.0 / COUNT(*), 2) AS fraud_rate_pct
FROM retail_fraud_clean;
 
-- 4.2 Transactions by payment method
SELECT payment_method, COUNT(*) AS total_transactions
FROM retail_fraud_clean
GROUP BY payment_method;
 
-- 4.3 Average, highest, lowest transaction amount
SELECT
    ROUND(AVG(transaction_amount),2) AS avg_amount,
    MAX(transaction_amount) AS highest_amount,
    MIN(transaction_amount) AS lowest_amount
FROM retail_fraud_clean;
 
-- 4.4 Fraud rate by merchant category
SELECT
    merchant_category,
    COUNT(*) AS total_transactions,
    SUM(fraud_flag) AS fraud_transactions,
    ROUND(SUM(fraud_flag) * 100.0 / COUNT(*), 2) AS fraud_rate_pct
FROM retail_fraud_clean
GROUP BY merchant_category
ORDER BY fraud_rate_pct DESC;
 
-- 4.5 Fraud rate by payment method
SELECT
    payment_method,
    COUNT(*) AS total_transactions,
    SUM(fraud_flag) AS fraud_transactions,
    ROUND(SUM(fraud_flag) * 100.0 / COUNT(*), 2) AS fraud_rate_pct
FROM retail_fraud_clean
GROUP BY payment_method
ORDER BY fraud_rate_pct DESC;
 
-- 4.6 Country-wise fraud count
SELECT location AS country, COUNT(*) AS fraud_transactions
FROM retail_fraud_clean
WHERE fraud_flag = 1
GROUP BY location
ORDER BY fraud_transactions DESC;
 
-- 4.7 Day-wise fraud trend
SELECT
    DATE(transaction_timestamp) AS day,
    COUNT(*) AS fraud_transactions,
    ROUND(SUM(transaction_amount), 2) AS fraud_amount
FROM retail_fraud_clean
WHERE fraud_flag = 1
GROUP BY day
ORDER BY day;
 
-- 4.8 Repeat fraud customers (3+ confirmed fraud transactions) — blacklist
--     candidates for the risk team
SELECT
    customer_id,
    COUNT(*) AS fraud_transactions,
    ROUND(SUM(transaction_amount), 2) AS total_fraud_amount
FROM retail_fraud_clean
WHERE fraud_flag = 1
GROUP BY customer_id
HAVING COUNT(*) >= 3
ORDER BY total_fraud_amount DESC;
 
-- 4.9 High risk transactions (risk_score >= 2) — candidates for manual review
SELECT COUNT(*) AS high_risk_transactions
FROM retail_fraud_clean
WHERE risk_score >= 2;
 
-- 4.10 Dense rank of merchant categories by fraud volume
SELECT
    merchant_category,
    COUNT(*) AS fraud_transactions,
    DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS fraud_rank
FROM retail_fraud_clean
WHERE fraud_flag = 1
GROUP BY merchant_category;
 
-- 4.11 Monthly fraud growth rate (month-over-month % change)
WITH monthly_fraud AS (
    SELECT
        DATE_FORMAT(transaction_timestamp, '%Y-%m') AS month,
        COUNT(*) AS fraud_transactions
    FROM retail_fraud_clean
    WHERE fraud_flag = 1
    GROUP BY month
)
SELECT
    month,
    fraud_transactions,
    LAG(fraud_transactions) OVER (ORDER BY month) AS previous_month_fraud,
    ROUND(
        (fraud_transactions - LAG(fraud_transactions) OVER (ORDER BY month)) * 100.0
        / LAG(fraud_transactions) OVER (ORDER BY month), 2
    ) AS growth_rate_pct
FROM monthly_fraud
ORDER BY month;
 
/* ============================================================================
   END OF PROJECT
   ============================================================================ */
