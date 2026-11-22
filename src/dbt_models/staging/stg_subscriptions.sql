-- ============================================================================
-- Model: stg_subscriptions
-- Layer: Staging
-- Purpose: SaaS billing invoices normalization and MRR/ARR verification
-- ============================================================================

WITH source AS (
    SELECT 
        billing_sk,
        invoice_id,
        billing_date,
        customer_sk,
        product_sk,
        billing_cycle,
        billed_amount,
        mrr_amount,
        arr_amount,
        payment_status,
        is_renewal,
        is_churn
    FROM fact_subscription_billing
),

normalized AS (
    SELECT
        billing_sk,
        invoice_id,
        billing_date,
        customer_sk,
        product_sk,
        UPPER(TRIM(billing_cycle)) AS billing_cycle,
        ROUND(CAST(billed_amount AS NUMERIC), 2) AS billed_amount,
        ROUND(CAST(mrr_amount AS NUMERIC), 2) AS mrr_amount,
        ROUND(CAST(arr_amount AS NUMERIC), 2) AS arr_amount,
        UPPER(TRIM(payment_status)) AS payment_status,
        CASE WHEN UPPER(TRIM(payment_status)) = 'PAID' THEN 1 ELSE 0 END AS is_paid,
        CASE WHEN UPPER(TRIM(payment_status)) = 'FAILED' THEN 1 ELSE 0 END AS is_failed,
        CASE WHEN is_renewal = 1 OR is_renewal = TRUE THEN 1 ELSE 0 END AS is_renewal_flag,
        CASE WHEN is_churn = 1 OR is_churn = TRUE THEN 1 ELSE 0 END AS is_churn_flag
    FROM source
)

SELECT * FROM normalized;
