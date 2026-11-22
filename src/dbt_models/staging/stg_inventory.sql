-- ============================================================================
-- Model: stg_inventory
-- Layer: Staging
-- Purpose: Ingest and categorize stock movement directions and SLA bounds
-- ============================================================================

WITH source AS (
    SELECT 
        movement_sk,
        movement_id,
        movement_date,
        product_sk,
        warehouse_sk,
        supplier_sk,
        movement_type,
        quantity_changed,
        ending_on_hand_qty,
        unit_valuation,
        total_valuation_delta,
        fulfillment_latency_hours
    FROM fact_inventory_movements
),

typed AS (
    SELECT
        movement_sk,
        movement_id,
        movement_date,
        product_sk,
        warehouse_sk,
        supplier_sk,
        movement_type,
        CASE 
            WHEN quantity_changed > 0 THEN 'INBOUND'
            WHEN quantity_changed < 0 THEN 'OUTBOUND'
            ELSE 'NEUTRAL_AUDIT'
        END AS flow_direction,
        quantity_changed,
        ABS(quantity_changed) AS absolute_quantity,
        ending_on_hand_qty,
        ROUND(CAST(unit_valuation AS NUMERIC), 2) AS unit_valuation,
        ROUND(CAST(total_valuation_delta AS NUMERIC), 2) AS total_valuation_delta,
        fulfillment_latency_hours,
        CASE WHEN fulfillment_latency_hours <= 24 THEN 1 ELSE 0 END AS met_24h_sla_flag
    FROM source
)

SELECT * FROM typed;
