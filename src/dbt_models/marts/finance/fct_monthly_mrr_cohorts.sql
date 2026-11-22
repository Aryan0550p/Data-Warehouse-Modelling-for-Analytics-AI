-- ============================================================================
-- Mart: Finance
-- Model: fct_monthly_mrr_cohorts
-- Purpose: SaaS MRR Waterfall, New vs Expansion vs Churned MRR and net growth
-- ============================================================================

WITH monthly_waterfall AS (
    SELECT
        SUBSTR(billing_date, 1, 7) AS billing_month,
        SUM(CASE WHEN mrr_movement_category = 'NEW_MRR' THEN current_mrr ELSE 0 END) AS new_mrr,
        SUM(CASE WHEN mrr_movement_category = 'EXPANSION_MRR' THEN mrr_change ELSE 0 END) AS expansion_mrr,
        SUM(CASE WHEN mrr_movement_category = 'CONTRACTION_MRR' THEN ABS(mrr_change) ELSE 0 END) AS contraction_mrr,
        SUM(CASE WHEN mrr_movement_category = 'CHURN_MRR' THEN previous_mrr ELSE 0 END) AS churned_mrr,
        SUM(CASE WHEN mrr_movement_category = 'RENEWAL_MRR' THEN current_mrr ELSE 0 END) AS renewal_mrr,
        SUM(current_mrr) AS ending_total_mrr,
        COUNT(DISTINCT customer_sk) AS active_subscribers
    FROM int_mrr_revenue_waterfall
    GROUP BY SUBSTR(billing_date, 1, 7)
),

mrr_kpis AS (
    SELECT
        billing_month,
        ROUND(new_mrr, 2) AS new_mrr,
        ROUND(expansion_mrr, 2) AS expansion_mrr,
        ROUND(contraction_mrr, 2) AS contraction_mrr,
        ROUND(churned_mrr, 2) AS churned_mrr,
        ROUND(renewal_mrr, 2) AS renewal_mrr,
        ROUND(ending_total_mrr, 2) AS ending_total_mrr,
        active_subscribers,
        -- Net MRR added
        ROUND(new_mrr + expansion_mrr - contraction_mrr - churned_mrr, 2) AS net_mrr_change,
        -- Prior month ending MRR
        LAG(ending_total_mrr, 1) OVER (
            ORDER BY billing_month ASC
        ) AS prior_month_mrr,
        -- Annualized Run Rate (ARR)
        ROUND(ending_total_mrr * 12.0, 2) AS ending_arr
    FROM monthly_waterfall
)

SELECT
    billing_month,
    new_mrr,
    expansion_mrr,
    contraction_mrr,
    churned_mrr,
    renewal_mrr,
    ending_total_mrr,
    net_mrr_change,
    ending_arr,
    active_subscribers,
    -- Month-over-Month MRR Growth Rate
    ROUND((net_mrr_change / NULLIF(prior_month_mrr, 0)) * 100, 2) AS mom_growth_pct
FROM mrr_kpis;
