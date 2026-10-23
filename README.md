# olist-logistics-sql-analysis
PostgreSQL analysis evaluating fulfillment latency, seller bottlenecks, and courier transit performance across 99k+ Olist e-commerce orders
# Olist E-Commerce Logistics & Seller Bottleneck Analysis

## Executive Summary
This project evaluates fulfillment and delivery latency across **Olist**, the largest Brazilian e-commerce marketplace. By analyzing order timestamp lifecycles across **99,000+ completed transactions**, this analysis answers a critical operational question: **Are delivery delays primarily driven by courier transit networks or merchant dispatch bottlenecks?**

Using PostgreSQL, the analysis reveals that while **courier transit accounts for ~70.5% of total customer wait time** on average (~9.3 days), merchant delays are not uniform. In **17.87% of all delivered orders**, sellers act as severe bottlenecks, consuming over 50% of the total order duration. By filtering out low-sample noise, this project isolates the top 10 highest-risk merchants for targeted operational intervention.

---

## Business Problem & Objectives
* **Marketplace Latency Allocation:** Dissect customer wait duration into two distinct operational phases:
  1. **Seller Dispatch Duration:** Purchase timestamp to courier handoff timestamp.
  2. **Courier Transit Duration:** Courier handoff timestamp to customer delivery timestamp.
* **Data Integrity & Sanitation:** Identify and eliminate data anomalies, empty fields, and illogical timestamp reversals before metric aggregation.
* **Macro Baseline:** Measure marketplace-wide averages to establish operational benchmarks.
* **Micro Cohort Identification:** Isolate specific high-volume merchants driving localized fulfillment failures to enable targeted operations over broad platform penalties.

---

## Tech Stack & Data Analytics Methods
* **Database Engine:** PostgreSQL
* **SQL Techniques Used:**
  * **Timestamp Arithmetic & Epoch Calculations:** `EXTRACT(EPOCH FROM ...)` for sub-day duration precision.
  * **Data Quality Engineering:** String sanitization, sequence constraint checks (`delivery > dispatch >= purchase`), and null/empty string handling.
  * **Common Table Expressions (CTEs):** Modularized data cleaning steps to optimize query efficiency and maintainability.
  * **Conditional Aggregation:** `COUNT(CASE WHEN ...)` to calculate percentage thresholds across order cohorts.
  * **Relational Multi-Table Joins:** Joining `olist_orders_dataset` with `olist_order_items_dataset` to map order lifecycles to individual merchant IDs.
  * **Statistical Noise Control:** Applying `HAVING COUNT(DISTINCT order_id) >= 10` to filter out low-volume outliers.

---

## Core Findings & Strategic Insights

### 1. Macro Marketplace Baseline
* **Courier Dominance:** On average, couriers account for **70.53%** of total order duration (~9.3 days), making transit networks the platform's primary overall delay factor[cite: 5].
* **Seller Baseline:** Sellers account for **29.47%** of total order duration (~3.2 days)[cite: 5].

### 2. Operational Bottleneck Frequency
* Despite couriers taking longer on average, **17.87% of all delivered orders** experience severe seller-side bottlenecks where the merchant holds the package for over 50% of the customer's total wait time.
* This proves that seller delays are a distinct, localized operational failure impacting nearly **1 in 5 orders**.

### 3. Problem Merchant Cohort (Top Bad Actors)
Applying a volume threshold of $\ge 10$ orders isolated high-volume sellers with chronic operational issues:
* **Worst Offender (`seller_id: 7fc87cc3...`):** Holds packages for an average of **76.97%** of total customer wait time across 14 orders.
* **Highest-Volume Bottleneck (`seller_id: 6fd52c...`):** Averages a **68.57% seller time share** across 67 orders, representing a systemic fulfillment failure.
* **Cohort Trend:** Every seller in the top 10 hitlist averages over **62% seller time share**, proving that fulfillment delays are concentrated among specific merchants.

---

## Data Cleaning & Logic Validation

Raw timestamp fields required multi-tiered sanitation before aggregation:
1. **Status Filtering:** Restricted analysis strictly to `order_status = 'delivered'`.
2. **Missing Data Removal:** Excluded records where timestamps were `NULL` or empty strings (`''`).
3. **Sequence Constraint Sanity Checks:**
   * `order_delivered_customer_date > order_delivered_carrier_date` (Customer delivery must occur after seller dispatch).
   * `order_delivered_carrier_date >= order_purchase_timestamp` (Seller dispatch must occur after order purchase).
   * *Impact:* Eliminated "time-travel" timestamp reversals that generated impossible metrics (>400% time share).

---

## Production SQL Script

The complete, sanitized PostgreSQL analysis script is available directly in this repository:
👉 **[View Full SQL Script (`olist_logistics_analysis.sql`)](./olist_logistics_analysis.sql)**

---

## Actionable Business Recommendations
1. **Targeted Fulfillment SLAs:** Implement strict dispatch windows (e.g., 48-hour limit) specifically for the identified top problem sellers rather than imposing blanket platform policies.
2. **Merchant Suspension Thresholds:** Automatically flag or temporarily downgrade marketplace visibility for merchants whose 30-day average seller time share exceeds **50%**.
3. **Courier Partner Optimization:** Renegotiate carrier agreements and regional transit routing to reduce the baseline **9.3-day courier transit duration**.
