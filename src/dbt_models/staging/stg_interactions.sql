-- ============================================================================
-- Model: stg_interactions
-- Layer: Staging
-- Purpose: Ingest and clean product telemetry and AI model execution events
-- ============================================================================

WITH source AS (
    SELECT 
        interaction_sk,
        session_id,
        interaction_date,
        interaction_time,
        customer_sk,
        model_sk,
        feature_name,
        session_duration_seconds,
        prompt_tokens,
        completion_tokens,
        total_tokens,
        estimated_token_cost,
        latency_seconds,
        had_error
    FROM fact_customer_interactions
),

cleaned AS (
    SELECT
        interaction_sk,
        session_id,
        interaction_date,
        interaction_time,
        customer_sk,
        model_sk,
        TRIM(feature_name) AS feature_name,
        session_duration_seconds,
        prompt_tokens,
        completion_tokens,
        total_tokens,
        ROUND(CAST(estimated_token_cost AS NUMERIC), 6) AS estimated_token_cost,
        ROUND(CAST(latency_seconds AS NUMERIC), 3) AS latency_seconds,
        CASE WHEN had_error = 1 OR had_error = TRUE THEN 1 ELSE 0 END AS has_error_flag
    FROM source
)

SELECT * FROM cleaned;
