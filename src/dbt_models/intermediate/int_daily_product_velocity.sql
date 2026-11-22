-- ============================================================================
-- Model: int_daily_product_velocity
-- Layer: Intermediate
-- Purpose: 7-day rolling window inventory outflow and stock velocity
-- ============================================================================

WITH daily_outflows AS (
    SELECT
        product_sk,
        warehouse_sk,
        movement_date,
        SUM(CASE WHEN flow_direction = 'OUTBOUND' THEN absolute_quantity ELSE 0 END) AS daily_shipped_qty,
        SUM(CASE WHEN flow_direction = 'INBOUND' THEN absolute_quantity ELSE 0 END) AS daily_received_qty,
        MAX(ending_on_hand_qty) AS closing_on_hand_qty
    FROM stg_inventory
    GROUP BY product_sk, warehouse_sk, movement_date
),

rolling_velocity AS (
    SELECT
        product_sk,
        warehouse_sk,
        movement_date,
        daily_shipped_qty,
        daily_received_qty,
        closing_on_hand_qty,
        -- Rolling 7-day total shipments using window aggregation
        SUM(daily_shipped_qty) OVER (
            PARTITION BY product_sk, warehouse_sk
            ORDER BY movement_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS rolling_7d_shipped_qty,
        -- Rolling 7-day average daily outflow
        AVG(daily_shipped_qty) OVER (
            PARTITION BY product_sk, warehouse_sk
            ORDER BY movement_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS rolling_7d_avg_daily_burn
    FROM daily_outflows
)

SELECT
    product_sk,
    warehouse_sk,
    movement_date,
    daily_shipped_qty,
    daily_received_qty,
    closing_on_hand_qty,
    rolling_7d_shipped_qty,
    ROUND(rolling_7d_avg_daily_burn, 2) AS rolling_7d_avg_daily_burn,
    -- Estimated days of inventory remaining
    CASE 
        WHEN rolling_7d_avg_daily_burn > 0 
        THEN ROUND(closing_on_hand_qty / rolling_7d_avg_daily_burn, 1)
        ELSE 999.0 
    END AS estimated_days_of_supply
FROM rolling_velocity;
