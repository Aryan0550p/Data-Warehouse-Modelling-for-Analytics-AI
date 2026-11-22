-- ============================================================================
-- Model: stg_customers
-- Layer: Staging
-- Purpose: Standardize customer attributes, clean email/phone, format segment
-- ============================================================================

WITH source AS (
    SELECT 
        customer_sk,
        customer_id,
        first_name,
        last_name,
        email,
        phone,
        segment,
        country,
        churn_risk_score,
        credit_rating,
        effective_start,
        effective_end,
        is_current
    FROM dim_customers
),

cleaned AS (
    SELECT
        customer_sk,
        customer_id,
        TRIM(first_name) AS first_name,
        TRIM(last_name) AS last_name,
        LOWER(TRIM(email)) AS email,
        REGEXP_REPLACE(phone, '[^0-9+]', '') AS clean_phone,
        UPPER(TRIM(segment)) AS customer_segment,
        country,
        COALESCE(churn_risk_score, 0.0) AS churn_risk_score,
        COALESCE(credit_rating, 'NR') AS credit_rating,
        effective_start,
        effective_end,
        CASE WHEN is_current = 1 OR is_current = TRUE THEN 1 ELSE 0 END AS is_current_flag
    FROM source
)

SELECT * FROM cleaned;
