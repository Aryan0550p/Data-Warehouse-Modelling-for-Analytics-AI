-- ============================================================================
-- Mart: Product & AI
-- Model: fct_user_feature_adoption
-- Purpose: User feature usage frequency, sessionization stickiness & adoption tiers
-- ============================================================================

WITH feature_usage AS (
    SELECT
        feature_name,
        SUBSTR(interaction_date, 1, 7) AS usage_month,
        COUNT(DISTINCT customer_sk) AS unique_active_users,
        COUNT(DISTINCT session_id) AS total_sessions,
        SUM(session_duration_seconds) AS total_duration_seconds,
        SUM(total_tokens) AS total_tokens_consumed,
        SUM(CASE WHEN has_error_flag = 1 THEN 1 ELSE 0 END) AS error_events_count
    FROM stg_interactions
    GROUP BY feature_name, SUBSTR(interaction_date, 1, 7)
),

adoption_ranked AS (
    SELECT
        feature_name,
        usage_month,
        unique_active_users,
        total_sessions,
        ROUND(total_duration_seconds / 60.0, 1) AS total_duration_minutes,
        total_tokens_consumed,
        error_events_count,
        ROUND(CAST(error_events_count AS NUMERIC) / NULLIF(total_sessions, 0) * 100, 2) AS feature_error_rate_pct,
        -- Rank feature popularity by monthly active users
        RANK() OVER (
            PARTITION BY usage_month 
            ORDER BY unique_active_users DESC
        ) AS monthly_popularity_rank,
        -- Share of total sessions in the month
        ROUND(CAST(total_sessions AS NUMERIC) / SUM(total_sessions) OVER (PARTITION BY usage_month) * 100, 2) AS session_share_pct
    FROM feature_usage
)

SELECT * FROM adoption_ranked;
