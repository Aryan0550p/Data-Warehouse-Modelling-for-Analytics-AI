-- ============================================================================
-- Mart: Operations
-- Model: rpt_inventory_stockout_risk
-- Purpose: Forecast days of supply and highlight inventory stockout risk SKUs
-- ============================================================================

WITH latest_product_inventory AS (
    SELECT
        vel.product_sk,
        vel.warehouse_sk,
        vel.movement_date,
        vel.closing_on_hand_qty,
        vel.rolling_7d_shipped_qty,
        vel.rolling_7d_avg_daily_burn,
        vel.estimated_days_of_supply,
        ROW_NUMBER() OVER (
            PARTITION BY vel.product_sk, vel.warehouse_sk
            ORDER BY vel.movement_date DESC
        ) AS recency_rank
    FROM int_daily_product_velocity vel
),

enriched_stock_risk AS (
    SELECT
        lpi.product_sk,
        p.product_id,
        p.product_name,
        p.category,
        lpi.warehouse_sk,
        wh.facility_name,
        lpi.movement_date AS snapshot_date,
        lpi.closing_on_hand_qty,
        lpi.rolling_7d_avg_daily_burn,
        lpi.estimated_days_of_supply,
        CASE 
            WHEN lpi.closing_on_hand_qty = 0 THEN 'OUT_OF_STOCK_CRITICAL'
            WHEN lpi.estimated_days_of_supply <= 5.0 THEN 'IMMINENT_STOCKOUT_RISK'
            WHEN lpi.estimated_days_of_supply <= 14.0 THEN 'REORDER_THRESHOLD'
            ELSE 'HEALTHY_BUFFER'
        END AS stock_health_status,
        -- Priority rank for supply chain replenishment
        DENSE_RANK() OVER (
            ORDER BY lpi.estimated_days_of_supply ASC
        ) AS replenishment_priority_rank
    FROM latest_product_inventory lpi
    INNER JOIN dim_products p ON lpi.product_sk = p.product_sk
    INNER JOIN dim_warehouse_locations wh ON lpi.warehouse_sk = wh.warehouse_sk
    WHERE lpi.recency_rank = 1
)

SELECT * FROM enriched_stock_risk;
