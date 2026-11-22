-- ============================================================================
-- Mart: Operations
-- Model: rpt_warehouse_capacity_utilization
-- Purpose: Facility inventory density, valuation holding, and turnover velocity
-- ============================================================================

WITH warehouse_stock AS (
    SELECT
        inv.warehouse_sk,
        inv.product_sk,
        inv.movement_date,
        inv.ending_on_hand_qty,
        inv.unit_valuation,
        ROW_NUMBER() OVER (
            PARTITION BY inv.warehouse_sk, inv.product_sk
            ORDER BY inv.movement_date DESC
        ) AS rank_latest
    FROM fact_inventory_movements inv
),

facility_summary AS (
    SELECT
        ws.warehouse_sk,
        wh.facility_name,
        wh.city,
        wh.state,
        wh.country,
        wh.capacity_sqft,
        SUM(ws.ending_on_hand_qty) AS current_total_units_stocked,
        SUM(ws.ending_on_hand_qty * ws.unit_valuation) AS total_inventory_valuation
    FROM warehouse_stock ws
    INNER JOIN dim_warehouse_locations wh ON ws.warehouse_sk = wh.warehouse_sk
    WHERE ws.rank_latest = 1
    GROUP BY ws.warehouse_sk, wh.facility_name, wh.city, wh.state, wh.country, wh.capacity_sqft
)

SELECT
    warehouse_sk,
    facility_name,
    city,
    state,
    country,
    capacity_sqft,
    current_total_units_stocked,
    ROUND(total_inventory_valuation, 2) AS total_inventory_valuation,
    -- Density metric (units per 1,000 sqft)
    ROUND(CAST(current_total_units_stocked AS NUMERIC) / (capacity_sqft / 1000.0), 2) AS units_per_k_sqft,
    -- Rank facilities by valuation
    RANK() OVER (
        ORDER BY total_inventory_valuation DESC
    ) AS facility_valuation_rank
FROM facility_summary;
