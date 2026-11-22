-- ============================================================================
-- Model: int_order_fulfillment_sla
-- Layer: Intermediate
-- Purpose: Window ranking and SLA performance by warehouse facility
-- ============================================================================

WITH fulfillment_records AS (
    SELECT
        inv.movement_sk,
        inv.movement_id,
        inv.movement_date,
        inv.product_sk,
        inv.warehouse_sk,
        inv.supplier_sk,
        inv.movement_type,
        inv.absolute_quantity,
        inv.fulfillment_latency_hours,
        inv.met_24h_sla_flag
    FROM stg_inventory inv
    WHERE inv.flow_direction = 'OUTBOUND'
),

ranked_latencies AS (
    SELECT
        movement_sk,
        movement_id,
        movement_date,
        product_sk,
        warehouse_sk,
        movement_type,
        absolute_quantity,
        fulfillment_latency_hours,
        met_24h_sla_flag,
        -- Warehouse rank of slowest dispatches
        DENSE_RANK() OVER (
            PARTITION BY warehouse_sk 
            ORDER BY fulfillment_latency_hours DESC
        ) AS warehouse_latency_rank,
        -- Average latency by warehouse
        AVG(fulfillment_latency_hours) OVER (
            PARTITION BY warehouse_sk
        ) AS warehouse_avg_latency,
        -- Running count of SLA misses
        SUM(CASE WHEN met_24h_sla_flag = 0 THEN 1 ELSE 0 END) OVER (
            PARTITION BY warehouse_sk
            ORDER BY movement_date
            ROWS UNBOUNDED PRECEDING
        ) AS cumulative_sla_breaches
    FROM fulfillment_records
)

SELECT
    movement_sk,
    movement_id,
    movement_date,
    product_sk,
    warehouse_sk,
    movement_type,
    absolute_quantity,
    fulfillment_latency_hours,
    met_24h_sla_flag,
    warehouse_latency_rank,
    ROUND(warehouse_avg_latency, 1) AS warehouse_avg_latency,
    cumulative_sla_breaches
FROM ranked_latencies;
