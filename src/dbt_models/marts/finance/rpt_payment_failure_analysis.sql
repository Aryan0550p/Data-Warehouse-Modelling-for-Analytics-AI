-- ============================================================================
-- Mart: Finance
-- Model: rpt_payment_failure_analysis
-- Purpose: Invoicing payment failure rate, dunning risk & revenue recovery
-- ============================================================================

WITH invoice_summary AS (
    SELECT
        billing_cycle,
        payment_status,
        SUBSTR(billing_date, 1, 7) AS billing_month,
        COUNT(billing_sk) AS total_invoices,
        SUM(billed_amount) AS total_billed_volume,
        SUM(CASE WHEN is_failed = 1 THEN 1 ELSE 0 END) AS failed_invoices_count,
        SUM(CASE WHEN is_failed = 1 THEN billed_amount ELSE 0 END) AS revenue_at_risk
    FROM stg_subscriptions
    GROUP BY billing_cycle, payment_status, SUBSTR(billing_date, 1, 7)
),

failure_metrics AS (
    SELECT
        billing_cycle,
        billing_month,
        SUM(total_invoices) AS total_invoices,
        SUM(total_billed_volume) AS total_billed_volume,
        SUM(failed_invoices_count) AS failed_invoices_count,
        SUM(revenue_at_risk) AS revenue_at_risk,
        -- Running cumulative revenue at risk
        SUM(SUM(revenue_at_risk)) OVER (
            PARTITION BY billing_cycle
            ORDER BY billing_month
            ROWS UNBOUNDED PRECEDING
        ) AS cumulative_revenue_at_risk
    FROM invoice_summary
    GROUP BY billing_cycle, billing_month
)

SELECT
    billing_cycle,
    billing_month,
    total_invoices,
    ROUND(total_billed_volume, 2) AS total_billed_volume,
    failed_invoices_count,
    ROUND(revenue_at_risk, 2) AS revenue_at_risk,
    ROUND((failed_invoices_count / NULLIF(total_invoices, 0)) * 100, 2) AS invoice_failure_rate_pct,
    ROUND(cumulative_revenue_at_risk, 2) AS cumulative_revenue_at_risk
FROM failure_metrics;
