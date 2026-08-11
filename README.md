# Retail-Fraud-Detection-Analysis-using-SQL

A complete SQL-based fraud detection pipeline - from raw transaction data to a validated, explainable risk-scoring system and business insights.

---

## 📌 Business Problem

An online retail company is facing rising transaction fraud. This project analyzes transaction-level data to:
- Detect suspicious transactions and high-risk customers
- Identify unusual spending and behavioral patterns
- Build a simple, explainable risk score to flag transactions for review
- Turn raw data into actionable insights for a fraud/risk team

---

## 📂 Dataset

- **Source:** [Retail Intelligence: Fraud Detection Dataset](https://www.kaggle.com/datasets/noopurbhatt/retail-intelligence-fraud-detection-dataset) (Kaggle)
- **Size:** ~100,000 transactions
- **Note:** This is a **synthetic/practice dataset** (fraud rate ≈ 47%, unlike real-world fraud which is typically <2%). It's used here to demonstrate the analysis workflow, not real production data.

Only the following **raw** columns were kept — everything else (frequency, averages, risk flags, risk labels) was intentionally dropped and **rebuilt from scratch using SQL**, to demonstrate real feature engineering rather than reading pre-computed columns:

| Column | Description |
|---|---|
| `transaction_id` | Unique ID for each transaction |
| `customer_id` | Links transactions to a customer |
| `transaction_timestamp` | Date & time of the transaction |
| `transaction_amount` | Amount spent |
| `payment_method` | Credit Card, Debit Card, PayPal, etc. |
| `device_type` | Mobile, Tablet, Desktop |
| `location` | Country of transaction |
| `merchant_category` | Fashion, Electronics, Travel, etc. |
| `is_international` | Whether the transaction is cross-border |
| `account_age_days` | Age of the customer account |
| `fraud_flag` | Ground truth — confirmed fraud (1) or not (0) |

---

## 🛠️ Tools Used

- **MySQL** (window functions, self-joins, CASE logic, UPDATE...JOIN)
- MySQL Workbench

---

## 🔄 Project Workflow

**1. Data Cleaning**
- Checked for and handled null values and duplicate transaction IDs
- Removed invalid transactions (₹0 / negative amounts)
- Fixed column data types (VARCHAR, DATETIME, DECIMAL)
- Added indexes for query performance

**2. Feature Engineering (derived from raw data using SQL — not pre-given)**

| Derived Column | Logic |
|---|---|
| `transaction_frequency_24h` | Self-join: count of the same customer's transactions in the prior 24 hours |
| `avg_transaction_amount_7d` | Self-join: average of the same customer's spend in the prior 7 days (personal baseline) |
| `unusual_amount_flag` | Today's amount is more than 2x the customer's own 7-day average |
| `multiple_transactions_short_time` | Multiple transactions by the same customer in a short time window |
| `velocity_flag` | Fast transactions **and** unusually high spend occurring together |
| `risk_score` / `fraud_risk` | Combined score from the flags above, converted into a Low / Medium / High label |

**3. Validation**

Rather than assuming the risk score works, it was checked against the real `fraud_flag` outcome:

| Risk Tier | Actual Fraud Rate |
|---|---|
| Medium | 54.2% |
| Low | 47.4% |

The engineered risk score meaningfully separates higher-risk transactions from lower-risk ones — confirmed against ground truth, not just assumed.

**4. Key Business Insights**

- Overall fraud rate in the dataset: **~47.5%**
- Fraud rate is nearly flat across merchant categories (~47–48%), consistent with this being a synthetic dataset with limited real-world correlation
- Top repeat offender: **9 confirmed fraud transactions**, ~₹1,804 total — a clear blacklist candidate
- The engineered `fraud_risk` label successfully separates transactions with a higher actual fraud rate (Medium: 54.2%) from the rest (Low: 47.4%)

---

## 💡 Key SQL Concepts Demonstrated

- Self-joins for behavioral feature engineering (no external ML/Python needed)
- Window functions: `LAG()`, `DENSE_RANK()`, `ROW_NUMBER()`
- `UPDATE ... JOIN` for efficient bulk updates on derived columns
- `CASE` statements for business-rule-based classification
- `CTE`s (Common Table Expressions) for readable multi-step logic
- Index optimization for join-heavy queries
- Data validation — testing engineered features against ground truth

---

## 📁 Repository Structure

```
retail-fraud-detection-sql/
├── README.md
├── sql/
│   └── Retail_Fraud_Detection_Final.sql
├── data/
│   ├── retail_fraud_raw.csv
│   └── retail_fraud_clean_final.csv
└── screenshots/
    ├── validation_result.png
    ├── fraud_by_category.png
    └── repeat_offenders.png
```

---

## ▶️ How to Run

1. Create the database and raw table (schema included at the top of the SQL script)
2. Import `data/retail_fraud_raw.csv` into `retail_fraud_raw`
3. Run `sql/Retail_Fraud_Detection_Final.sql` in MySQL Workbench (or CLI) — it runs cleaning, feature engineering, validation, and insights in sequence

---

## 🎯 What This Project Demonstrates

Rather than just running pre-built queries, this project focuses on:
1. Treating the dataset as raw input and rebuilding behavioral features from scratch
2. Building a transparent, explainable risk score instead of a black-box output
3. **Validating** that engineered features actually work, instead of assuming they do
4. Translating SQL output into concrete business actions (review queues, blacklists, category focus areas)

---

## 👤 Author

*(Bhuwaneshwari Pilare, www.linkedin.com/in/bhuwaneshwari-pilare)*
