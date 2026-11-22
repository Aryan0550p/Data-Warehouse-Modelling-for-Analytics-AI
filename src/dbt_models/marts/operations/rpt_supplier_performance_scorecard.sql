-- ============================================================================
-- Mart: Operations
-- Model: rpt_supplier_performance_scorecard
-- Purpose: Inbound supplier lead-time compliance, receipt volume & quality score
-- ============================================================================

WITH supplier_inbound AS (
    SELECT
        inv.supplier_sk,
        COUNT(inv.movement_sk) AS total_inbound_shipments,
        SUM(inv.absolute_quantity) AS total_units_received,
        AVG(inv.fulfillment_latency_hours) AS avg_delivery_latency_hours
    FROM stg_inventory inv
    WHERE inv.flow_direction = 'INBOUND'
    GROUP BY inv.supplier_sk
),

scorecard AS (
    SELECT
        s.supplier_sk,
        s.supplier_id,
        s.supplier_name,
        s.country,
        s.reliability_score,
        s.lead_time_days AS contract_lead_time_days,
        s.supplier_tier,
        s.lead_time_category,
        COALESCE(si.total_inbound_shipments, 0) AS total_inbound_shipments,
        COALESCE(si.total_units_received, 0) AS total_units_received,
        ROUND(COALESCE(si.avg_delivery_latency_hours, 0) / 24.0, 1) AS actual_avg_lead_time_days,
        -- Lead time variance from contract
        ROUND((COALESCE(si.avg_delivery_latency_hours, 0) / 24.0) - s.lead_time_days, 1) AS lead_time_variance_days,
        -- Relative rank among all suppliers
        RANK() OVER (
            ORDER BY s.reliability_score DESC, COALESCE(si.total_units_received, 0) DESC
        ) AS supplier_overall_rank
    FROM stg_suppliers s
    LEFT JOIN supplier_inbound si ON s.supplier_sk = si.supplier_sk
)

SELECT * FROM scorecard;
