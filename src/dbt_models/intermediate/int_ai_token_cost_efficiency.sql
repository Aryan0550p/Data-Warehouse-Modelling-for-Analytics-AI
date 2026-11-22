-- ============================================================================
-- Model: int_ai_token_cost_efficiency
-- Layer: Intermediate
-- Purpose: Window ranking, latency deciles (NTILE) and model efficiency metrics
-- ============================================================================

WITH base_telemetry AS (
    SELECT
        i.interaction_sk,
        i.session_id,
        i.customer_sk,
        i.model_sk,
        m.model_name,
        m.provider,
        i.feature_name,
        i.interaction_date,
        i.prompt_tokens,
        i.completion_tokens,
        i.total_tokens,
        i.estimated_token_cost,
        i.latency_seconds,
        i.has_error_flag
    FROM stg_interactions i
    INNER JOIN stg_ai_models m ON i.model_sk = m.model_sk
),

percentiles_and_windows AS (
    SELECT
        interaction_sk,
        session_id,
        customer_sk,
        model_sk,
        model_name,
        provider,
        feature_name,
        interaction_date,
        prompt_tokens,
        completion_tokens,
        total_tokens,
        estimated_token_cost,
        latency_seconds,
        has_error_flag,
        -- Latency decile distribution
        NTILE(10) OVER (
            PARTITION BY model_sk 
            ORDER BY latency_seconds ASC
        ) AS latency_decile,
        -- Average latency for this model
        AVG(latency_seconds) OVER (
            PARTITION BY model_sk
        ) AS model_avg_latency,
        -- Model overall average token cost
        AVG(estimated_token_cost) OVER (
            PARTITION BY model_sk
        ) AS model_avg_cost,
        -- Moving 50-event running total token cost
        SUM(estimated_token_cost) OVER (
            PARTITION BY model_sk
            ORDER BY interaction_date
            ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
        ) AS rolling_50_event_token_cost
    FROM base_telemetry
)

SELECT
    interaction_sk,
    session_id,
    customer_sk,
    model_sk,
    model_name,
    provider,
    feature_name,
    interaction_date,
    prompt_tokens,
    completion_tokens,
    total_tokens,
    ROUND(estimated_token_cost, 6) AS estimated_token_cost,
    ROUND(latency_seconds, 3) AS latency_seconds,
    latency_decile,
    ROUND(model_avg_latency, 3) AS model_avg_latency,
    ROUND(model_avg_cost, 6) AS model_avg_cost,
    ROUND(rolling_50_event_token_cost, 4) AS rolling_50_event_token_cost,
    has_error_flag
FROM percentiles_and_windows;
