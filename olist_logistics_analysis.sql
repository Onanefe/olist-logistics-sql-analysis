-- ====================================================================
-- OLIST MARKETPLACE LOGISTICS & BOTTLENECK ANALYSIS
-- Objective: Evaluate delivery latency across sellers vs. couriers
-- ====================================================================

-- 1. BASELINE VOLUME
SELECT COUNT(DISTINCT customer_id) AS completed_orders
FROM olist_orders_dataset ood
WHERE order_status = 'delivered';


-- 2. ROW-LEVEL DURATION CALCULATIONS (DAYS)
SELECT 
    EXTRACT(EPOCH FROM (order_delivered_carrier_date::timestamp - order_purchase_timestamp::timestamp)) / 86400.0 AS seller_dispatch_days,
    EXTRACT(EPOCH FROM (order_delivered_customer_date::timestamp - order_delivered_carrier_date::timestamp)) / 86400.0 AS courier_days,
    EXTRACT(EPOCH FROM (order_delivered_customer_date::timestamp - order_purchase_timestamp::timestamp)) / 86400.0 AS total_delivery_days
FROM olist_orders_dataset ood
WHERE order_status = 'delivered'
  AND order_delivered_carrier_date IS NOT NULL 
  AND order_delivered_customer_date IS NOT NULL;

--these lines of codes show the average seller time vs the average courier time 
select 
	avg(extract(epoch from (order_delivered_carrier_date::timestamp - order_purchase_timestamp::timestamp)/86400.0)) as avg_seller_dispatch_days,
	avg(extract(epoch from (order_delivered_customer_date::timestamp - order_delivered_carrier_date::timestamp)/86400.0)) as avg_courier_days
from olist_orders_dataset ood
WHERE order_status = 'delivered'
  AND order_delivered_carrier_date IS NOT NULL AND order_delivered_carrier_date != ''
  AND order_delivered_customer_date IS NOT NULL AND order_delivered_customer_date != ''
  -- Sanity Check: Customer delivery MUST be after seller dispatch
  AND order_delivered_customer_date::timestamp > order_delivered_carrier_date::timestamp
  -- Sanity Check: Seller dispatch MUST be after purchase
  AND order_delivered_carrier_date::timestamp >= order_purchase_timestamp::timestamp
;


-- 3. SANITIZED ROW-LEVEL METRIC MODELING
-- Applies sequence constraints to eliminate data anomalies (e.g. timestamp reversals)
SELECT 
    order_id,
    order_purchase_timestamp,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    ROUND(
        EXTRACT(EPOCH FROM (order_delivered_carrier_date::timestamp - order_purchase_timestamp::timestamp)) /
        EXTRACT(EPOCH FROM (order_delivered_customer_date::timestamp - order_purchase_timestamp::timestamp)) * 100, 
        2
    ) AS seller_time_share
FROM olist_orders_dataset ood
WHERE order_status = 'delivered'
  AND order_delivered_carrier_date IS NOT NULL AND order_delivered_carrier_date != ''
  AND order_delivered_customer_date IS NOT NULL AND order_delivered_customer_date != ''
  AND order_delivered_customer_date::timestamp > order_delivered_carrier_date::timestamp
  AND order_delivered_carrier_date::timestamp >= order_purchase_timestamp::timestamp
ORDER BY seller_time_share DESC;


-- 4. EXECUTIVE MACRO AGGREGATIONS (MARKETPLACE BASELINE)
-- Averages dispatch vs courier durations, and measures overall % of bottlenecked orders
WITH cleaned_orders AS (
    SELECT 
        (
            EXTRACT(EPOCH FROM (order_delivered_carrier_date::timestamp - order_purchase_timestamp::timestamp)) /
            EXTRACT(EPOCH FROM (order_delivered_customer_date::timestamp - order_purchase_timestamp::timestamp))
        ) * 100 AS seller_time_share
    FROM olist_orders_dataset
    WHERE order_status = 'delivered'
      AND order_delivered_carrier_date IS NOT NULL AND order_delivered_carrier_date != ''
      AND order_delivered_customer_date IS NOT NULL AND order_delivered_customer_date != ''
      AND order_delivered_customer_date::timestamp > order_delivered_carrier_date::timestamp
      AND order_delivered_carrier_date::timestamp >= order_purchase_timestamp::timestamp
)
SELECT 
    ROUND(AVG(seller_time_share), 2) AS avg_seller_time_share,
    ROUND(100.0 * COUNT(CASE WHEN seller_time_share > 50 THEN 1 END) / COUNT(*), 2) AS pct_orders_seller_bottleneck
FROM cleaned_orders;


-- 5. TARGETED COHORT ANALYSIS (TOP 10 PROBLEM SELLERS)
-- Filters for sellers with >= 10 orders to flag systemic fulfillment delays
SELECT 
    ooid.seller_id,
    COUNT(DISTINCT ood.order_id) AS total_orders,
    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (order_delivered_carrier_date::timestamp - order_purchase_timestamp::timestamp)) /
            EXTRACT(EPOCH FROM (order_delivered_customer_date::timestamp - order_purchase_timestamp::timestamp)) * 100
        ), 2
    ) AS avg_seller_time_share
FROM olist_orders_dataset ood 
JOIN olist_order_items_dataset ooid 
    ON ood.order_id = ooid.order_id 
WHERE order_status = 'delivered'
  AND order_delivered_carrier_date IS NOT NULL AND order_delivered_carrier_date != ''
  AND order_delivered_customer_date IS NOT NULL AND order_delivered_customer_date != ''
  AND order_delivered_customer_date::timestamp > order_delivered_carrier_date::timestamp
  AND order_delivered_carrier_date::timestamp >= order_purchase_timestamp::timestamp
GROUP BY ooid.seller_id 
HAVING COUNT(DISTINCT ood.order_id) >= 10
ORDER BY avg_seller_time_share DESC
LIMIT 10;


