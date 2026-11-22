-- ============================================================================
-- Mart: Operations
-- Model: fct_daily_fulfillment_kpi
-- Purpose: Daily operations SLA compliance, throughput & dispatch velocity
-- ============================================================================

WITH daily_aggregates AS (
    SELECT
        sla.warehouse_sk,
        sla.movement_date,
        COUNT(sla.movement_sk) AS total_outbound_shipments,
        SUM(sla.absolute_quantity) AS total_units_dispatched,
        AVG(sla.fulfillment_latency_hours) AS avg_latency_hours,
        SUM(sla.met_24h_sla_flag) AS shipments_meeting_sla,
        COUNT(sla.movement_sk) - SUM(sla.met_24h_sla_flag) AS shipments_breaching_sla
    FROM int_order_fulfillment_sla sla
    GROUP BY sla.warehouse_sk, sla.movement_date
),

kpi_calculations AS (
    SELECT
        da.warehouse_sk,
        wh.facility_name,
        wh.city,
        wh.country,
        da.movement_date,
        da.total_outbound_shipments,
        da.total_units_dispatched,
        ROUND(da.avg_latency_hours, 2) AS avg_latency_hours,
        da.shipments_meeting_sla,
        da.shipments_breaching_sla,
        ROUND(CAST(da.shipments_meeting_sla AS NUMERIC) / NULLIF(da.total_outbound_shipments, 0) * 100, 2) AS sla_compliance_pct,
        -- Running 30-day cumulative shipments
        SUM(da.total_outbound_shipments) OVER (
            PARTITION BY da.warehouse_sk
            ORDER BY da.movement_date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS rolling_30d_shipments
    FROM daily_aggregates da
    INNER JOIN dim_warehouse_locations wh ON da.warehouse_sk = wh.warehouse_sk
)

SELECT * FROM kpi_calculations;
