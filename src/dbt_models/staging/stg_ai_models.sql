-- ============================================================================
-- Model: stg_ai_models
-- Layer: Staging
-- Purpose: Standardize AI Model catalog and calculate cost per 1M tokens
-- ============================================================================

WITH source AS (
    SELECT 
        model_sk,
        model_id,
        model_name,
        version,
        provider,
        context_window_tokens,
        cost_per_1k_input_tokens,
        cost_per_1k_output_tokens,
        feature_category
    FROM dim_ai_models_features
),

calculated AS (
    SELECT
        model_sk,
        model_id,
        TRIM(model_name) AS model_name,
        TRIM(version) AS model_version,
        TRIM(provider) AS provider,
        context_window_tokens,
        ROUND(CAST(cost_per_1k_input_tokens AS NUMERIC), 6) AS cost_per_1k_input_tokens,
        ROUND(CAST(cost_per_1k_output_tokens AS NUMERIC), 6) AS cost_per_1k_output_tokens,
        ROUND(CAST(cost_per_1k_input_tokens AS NUMERIC) * 1000, 4) AS cost_per_1m_input_tokens,
        ROUND(CAST(cost_per_1k_output_tokens AS NUMERIC) * 1000, 4) AS cost_per_1m_output_tokens,
        TRIM(feature_category) AS feature_category
    FROM source
)

SELECT * FROM calculated;
