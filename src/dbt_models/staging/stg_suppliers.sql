-- ============================================================================
-- Model: stg_suppliers
-- Layer: Staging
-- Purpose: Ingest vendor catalog, classify reliability and logistics risk tiers
-- ============================================================================

WITH source AS (
    SELECT 
        supplier_sk,
        supplier_id,
        supplier_name,
        country,
        reliability_score,
        lead_time_days
    FROM dim_suppliers
),

ranked AS (
    SELECT
        supplier_sk,
        supplier_id,
        TRIM(supplier_name) AS supplier_name,
        country,
        ROUND(CAST(reliability_score AS NUMERIC), 3) AS reliability_score,
        lead_time_days,
        CASE 
            WHEN reliability_score >= 0.95 THEN 'TIER_1_PREFERRED'
            WHEN reliability_score >= 0.90 THEN 'TIER_2_QUALIFIED'
            ELSE 'TIER_3_EVALUATION'
        END AS supplier_tier,
        CASE 
            WHEN lead_time_days <= 7 THEN 'SHORT_LEAD_TIME'
            WHEN lead_time_days <= 14 THEN 'MEDIUM_LEAD_TIME'
            ELSE 'EXTENDED_LEAD_TIME'
        END AS lead_time_category
    FROM source
)

SELECT * FROM ranked;
