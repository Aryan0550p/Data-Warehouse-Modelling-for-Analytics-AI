-- ============================================================================
-- Model: int_sessionized_user_journey
-- Layer: Intermediate
-- Purpose: Sessionization logic detecting continuous user activity & step ordering
-- ============================================================================

WITH ordered_events AS (
    SELECT
        interaction_sk,
        session_id,
        customer_sk,
        model_sk,
        feature_name,
        interaction_date,
        interaction_time,
        session_duration_seconds,
        total_tokens,
        estimated_token_cost,
        latency_seconds,
        has_error_flag,
        -- Detect previous event time for same customer
        LAG(interaction_time, 1) OVER (
            PARTITION BY customer_sk, interaction_date
            ORDER BY interaction_time ASC
        ) AS prev_event_time,
        -- Sequential step in current user day
        ROW_NUMBER() OVER (
            PARTITION BY customer_sk, interaction_date
            ORDER BY interaction_time ASC
        ) AS daily_event_step
    FROM stg_interactions
),

session_boundaries AS (
    SELECT
        interaction_sk,
        session_id,
        customer_sk,
        model_sk,
        feature_name,
        interaction_date,
        interaction_time,
        session_duration_seconds,
        total_tokens,
        estimated_token_cost,
        latency_seconds,
        has_error_flag,
        daily_event_step,
        -- Mark as new session cluster if gap > 30 mins (in HHMM representation)
        CASE 
            WHEN prev_event_time IS NULL THEN 1
            WHEN (interaction_time - prev_event_time) > 30 THEN 1
            ELSE 0
        END AS is_new_session_cluster
    FROM ordered_events
),

session_clusters AS (
    SELECT
        interaction_sk,
        session_id,
        customer_sk,
        model_sk,
        feature_name,
        interaction_date,
        interaction_time,
        session_duration_seconds,
        total_tokens,
        estimated_token_cost,
        latency_seconds,
        has_error_flag,
        daily_event_step,
        -- Cumulative sum creates persistent session cluster ID
        SUM(is_new_session_cluster) OVER (
            PARTITION BY customer_sk, interaction_date
            ORDER BY interaction_time ASC
            ROWS UNBOUNDED PRECEDING
        ) AS session_cluster_seq
    FROM session_boundaries
)

SELECT * FROM session_clusters;
