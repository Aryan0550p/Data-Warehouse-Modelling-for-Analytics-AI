-- ============================================================================
-- Mart: Product & AI
-- Model: fct_ai_model_performance
-- Purpose: AI Model latency distribution, prompt token cost & reliability SLA
-- ============================================================================

WITH model_events AS (
    SELECT
        eff.model_sk,
        eff.model_name,
        eff.provider,
        eff.feature_name,
        eff.latency_seconds,
        eff.prompt_tokens,
        eff.completion_tokens,
        eff.total_tokens,
        eff.estimated_token_cost,
        eff.has_error_flag
    FROM int_ai_token_cost_efficiency eff
),

aggregated_model_kpis AS (
    SELECT
        model_sk,
        model_name,
        provider,
        feature_name,
        COUNT(*) AS total_inferences,
        SUM(prompt_tokens) AS total_prompt_tokens,
        SUM(completion_tokens) AS total_completion_tokens,
        SUM(total_tokens) AS total_tokens_processed,
        SUM(estimated_token_cost) AS total_incurred_cost,
        AVG(latency_seconds) AS avg_latency_seconds,
        MIN(latency_seconds) AS min_latency_seconds,
        MAX(latency_seconds) AS max_latency_seconds,
        SUM(CASE WHEN has_error_flag = 1 THEN 1 ELSE 0 END) AS error_count
    FROM model_events
    GROUP BY model_sk, model_name, provider, feature_name
)

SELECT
    model_sk,
    model_name,
    provider,
    feature_name,
    total_inferences,
    total_prompt_tokens,
    total_completion_tokens,
    total_tokens_processed,
    ROUND(total_incurred_cost, 4) AS total_incurred_cost,
    ROUND(total_incurred_cost / NULLIF(total_inferences, 0), 6) AS avg_cost_per_inference,
    ROUND(avg_latency_seconds, 3) AS avg_latency_seconds,
    ROUND(min_latency_seconds, 3) AS min_latency_seconds,
    ROUND(max_latency_seconds, 3) AS max_latency_seconds,
    error_count,
    ROUND(CAST(error_count AS NUMERIC) / NULLIF(total_inferences, 0) * 100, 2) AS error_rate_pct,
    -- Relative cost efficiency rank
    DENSE_RANK() OVER (
        PARTITION BY feature_name 
        ORDER BY (total_incurred_cost / NULLIF(total_inferences, 0)) ASC
    ) AS feature_cost_efficiency_rank
FROM aggregated_model_kpis;
