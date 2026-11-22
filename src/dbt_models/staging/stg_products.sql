-- ============================================================================
-- Model: stg_products
-- Layer: Staging
-- Purpose: Catalog normalization, unit economics validation & SKU classification
-- ============================================================================

WITH source AS (
    SELECT 
        product_sk,
        product_id,
        product_name,
        category,
        sku,
        unit_cost,
        list_price,
        embedding_vector_id,
        effective_start,
        effective_end,
        is_current
    FROM dim_products
),

standardized AS (
    SELECT
        product_sk,
        product_id,
        TRIM(product_name) AS product_name,
        TRIM(category) AS product_category,
        UPPER(TRIM(sku)) AS sku,
        ROUND(CAST(unit_cost AS NUMERIC), 2) AS unit_cost,
        ROUND(CAST(list_price AS NUMERIC), 2) AS list_price,
        ROUND(CAST(list_price AS NUMERIC) - CAST(unit_cost AS NUMERIC), 2) AS standard_unit_margin,
        ROUND((CAST(list_price AS NUMERIC) - CAST(unit_cost AS NUMERIC)) / NULLIF(CAST(list_price AS NUMERIC), 0) * 100, 2) AS standard_margin_pct,
        embedding_vector_id,
        effective_start,
        effective_end,
        is_current
    FROM source
)

SELECT * FROM standardized;
