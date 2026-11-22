-- ============================================================================
-- Model: stg_orders
-- Layer: Staging
-- Purpose: Sanitize order transactions, cast dates, compute discount rates
-- ============================================================================

WITH source AS (
    SELECT 
        order_sk,
        order_id,
        order_date,
        order_time,
        customer_sk,
        product_sk,
        channel_sk,
        quantity,
        unit_price,
        gross_amount,
        discount_amount,
        net_amount,
        unit_cost,
        total_cost,
        margin_amount,
        margin_pct,
        order_status
    FROM fact_orders
),

validated AS (
    SELECT
        order_sk,
        order_id,
        order_date,
        order_time,
        customer_sk,
        product_sk,
        channel_sk,
        quantity,
        ROUND(CAST(unit_price AS NUMERIC), 2) AS unit_price,
        ROUND(CAST(gross_amount AS NUMERIC), 2) AS gross_amount,
        ROUND(CAST(discount_amount AS NUMERIC), 2) AS discount_amount,
        ROUND(CAST(net_amount AS NUMERIC), 2) AS net_amount,
        ROUND(CAST(unit_cost AS NUMERIC), 2) AS unit_cost,
        ROUND(CAST(total_cost AS NUMERIC), 2) AS total_cost,
        ROUND(CAST(margin_amount AS NUMERIC), 2) AS margin_amount,
        ROUND(CAST(margin_pct AS NUMERIC), 2) AS margin_pct,
        UPPER(TRIM(order_status)) AS order_status,
        CASE WHEN UPPER(TRIM(order_status)) = 'DELIVERED' THEN 1 ELSE 0 END AS is_delivered,
        CASE WHEN UPPER(TRIM(order_status)) = 'CANCELLED' THEN 1 ELSE 0 END AS is_cancelled,
        CASE WHEN UPPER(TRIM(order_status)) = 'RETURNED' THEN 1 ELSE 0 END AS is_returned
    FROM source
    WHERE quantity > 0
)

SELECT * FROM validated;
