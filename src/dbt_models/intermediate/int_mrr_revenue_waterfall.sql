-- ============================================================================
-- Model: int_mrr_revenue_waterfall
-- Layer: Intermediate
-- Purpose: Classify recurring revenue into New, Expansion, Contraction, and Churned MRR
-- ============================================================================

WITH subscription_timeline AS (
    SELECT
        billing_sk,
        customer_sk,
        product_sk,
        billing_date,
        billing_cycle,
        mrr_amount,
        is_paid,
        is_failed,
        is_renewal_flag,
        is_churn_flag
    FROM stg_subscriptions
    WHERE is_paid = 1 OR is_churn_flag = 1
),

waterfall_windowed AS (
    SELECT
        billing_sk,
        customer_sk,
        product_sk,
        billing_date,
        billing_cycle,
        mrr_amount,
        is_paid,
        is_churn_flag,
        -- Prior month MRR for this customer
        LAG(mrr_amount, 1, 0.0) OVER (
            PARTITION BY customer_sk 
            ORDER BY billing_date ASC
        ) AS previous_mrr,
        -- Sequence number of subscription event
        ROW_NUMBER() OVER (
            PARTITION BY customer_sk 
            ORDER BY billing_date ASC
        ) AS invoice_sequence
    FROM subscription_timeline
),

categorized_waterfall AS (
    SELECT
        billing_sk,
        customer_sk,
        product_sk,
        billing_date,
        billing_cycle,
        mrr_amount AS current_mrr,
        previous_mrr,
        mrr_amount - previous_mrr AS mrr_change,
        CASE
            WHEN is_churn_flag = 1 THEN 'CHURN_MRR'
            WHEN invoice_sequence = 1 THEN 'NEW_MRR'
            WHEN mrr_amount > previous_mrr THEN 'EXPANSION_MRR'
            WHEN mrr_amount < previous_mrr THEN 'CONTRACTION_MRR'
            ELSE 'RENEWAL_MRR'
        END AS mrr_movement_category,
        -- Net ARR change
        ROUND((mrr_amount - previous_mrr) * 12.0, 2) AS arr_change_annualized
    FROM waterfall_windowed
)

SELECT * FROM categorized_waterfall;
