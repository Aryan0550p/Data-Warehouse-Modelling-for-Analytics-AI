-- ============================================================================
-- Model: int_customer_scd2
-- Layer: Intermediate
-- Purpose: SCD Type-2 window logic, detecting customer state transitions & validity ranges
-- ============================================================================

WITH customer_snapshots AS (
    SELECT
        customer_sk,
        customer_id,
        first_name,
        last_name,
        email,
        customer_segment,
        country,
        churn_risk_score,
        effective_start,
        effective_end,
        is_current_flag
    FROM stg_customers
),

windowed_changes AS (
    SELECT
        customer_sk,
        customer_id,
        first_name,
        last_name,
        email,
        customer_segment,
        country,
        churn_risk_score,
        effective_start,
        -- Detect previous segment using LAG window function
        LAG(customer_segment, 1) OVER (
            PARTITION BY customer_id 
            ORDER BY effective_start ASC
        ) AS prior_segment,
        -- Detect previous churn risk using LAG window function
        LAG(churn_risk_score, 1) OVER (
            PARTITION BY customer_id 
            ORDER BY effective_start ASC
        ) AS prior_churn_risk,
        -- Check if this record is the latest available in chain
        ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY effective_start DESC
        ) AS recency_rank,
        is_current_flag
    FROM customer_snapshots
),

classified AS (
    SELECT
        customer_sk,
        customer_id,
        first_name,
        last_name,
        email,
        customer_segment,
        prior_segment,
        country,
        churn_risk_score,
        prior_churn_risk,
        CASE 
            WHEN prior_segment IS NULL THEN 'INITIAL_REGISTRATION'
            WHEN prior_segment <> customer_segment THEN 'TIER_UPGRADE_OR_DOWNGRADE'
            WHEN ABS(churn_risk_score - COALESCE(prior_churn_risk, 0)) >= 0.20 THEN 'CHURN_RISK_SHIFT'
            ELSE 'STABLE'
        END AS transition_type,
        effective_start,
        CASE WHEN recency_rank = 1 THEN 1 ELSE 0 END AS computed_is_current
    FROM windowed_changes
)

SELECT * FROM classified;
