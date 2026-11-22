-- ============================================================================
-- Mart: Product & AI (ML Feature Store)
-- Model: fct_churn_prediction_features
-- Purpose: Feature Store table for training customer churn & propensity AI models
-- ============================================================================

WITH customer_orders AS (
    SELECT
        customer_sk,
        COUNT(DISTINCT order_id) AS lifetime_orders_count,
        SUM(net_amount) AS lifetime_order_spend,
        AVG(net_amount) AS avg_order_value,
        MAX(order_date) AS last_order_date
    FROM stg_orders
    WHERE is_delivered = 1
    GROUP BY customer_sk
),

customer_ai_engagement AS (
    SELECT
        customer_sk,
        COUNT(DISTINCT session_id) AS lifetime_ai_sessions,
        SUM(total_tokens) AS lifetime_tokens_consumed,
        SUM(estimated_token_cost) AS lifetime_ai_cost,
        AVG(session_duration_seconds) AS avg_session_duration_sec,
        SUM(CASE WHEN has_error_flag = 1 THEN 1 ELSE 0 END) AS total_errors_encountered,
        MAX(interaction_date) AS last_interaction_date
    FROM stg_interactions
    GROUP BY customer_sk
),

customer_billing AS (
    SELECT
        customer_sk,
        COUNT(billing_sk) AS lifetime_invoices_count,
        SUM(CASE WHEN is_paid = 1 THEN billed_amount ELSE 0 END) AS lifetime_subscription_spend,
        SUM(CASE WHEN is_failed = 1 THEN 1 ELSE 0 END) AS total_failed_payments,
        MAX(is_churn_flag) AS historical_churn_flag,
        MAX(billing_date) AS last_billing_date
    FROM stg_subscriptions
    GROUP BY customer_sk
),

feature_assembly AS (
    SELECT
        c.customer_sk,
        c.customer_id,
        c.customer_segment,
        c.country,
        c.credit_rating,
        -- Engagement Features
        COALESCE(co.lifetime_orders_count, 0) AS lifetime_orders_count,
        ROUND(COALESCE(co.lifetime_order_spend, 0.0), 2) AS lifetime_order_spend,
        ROUND(COALESCE(co.avg_order_value, 0.0), 2) AS avg_order_value,
        co.last_order_date,
        -- AI Usage Features
        COALESCE(ai.lifetime_ai_sessions, 0) AS lifetime_ai_sessions,
        COALESCE(ai.lifetime_tokens_consumed, 0) AS lifetime_tokens_consumed,
        ROUND(COALESCE(ai.lifetime_ai_cost, 0.0), 4) AS lifetime_ai_cost,
        ROUND(COALESCE(ai.avg_session_duration_sec, 0.0), 1) AS avg_session_duration_sec,
        COALESCE(ai.total_errors_encountered, 0) AS total_errors_encountered,
        ai.last_interaction_date,
        -- Billing & Payment Health Features
        COALESCE(cb.lifetime_invoices_count, 0) AS lifetime_invoices_count,
        ROUND(COALESCE(cb.lifetime_subscription_spend, 0.0), 2) AS lifetime_subscription_spend,
        COALESCE(cb.total_failed_payments, 0) AS total_failed_payments,
        COALESCE(cb.historical_churn_flag, 0) AS is_churned_target,
        -- Window Ranking / Percentile within Segment
        PERCENT_RANK() OVER (
            PARTITION BY c.customer_segment 
            ORDER BY COALESCE(co.lifetime_order_spend, 0) + COALESCE(cb.lifetime_subscription_spend, 0) ASC
        ) AS customer_value_segment_percentile
    FROM stg_customers c
    LEFT JOIN customer_orders co ON c.customer_sk = co.customer_sk
    LEFT JOIN customer_ai_engagement ai ON c.customer_sk = ai.customer_sk
    LEFT JOIN customer_billing cb ON c.customer_sk = cb.customer_sk
    WHERE c.is_current_flag = 1
)

SELECT
    customer_sk,
    customer_id,
    customer_segment,
    country,
    credit_rating,
    lifetime_orders_count,
    lifetime_order_spend,
    avg_order_value,
    last_order_date,
    lifetime_ai_sessions,
    lifetime_tokens_consumed,
    lifetime_ai_cost,
    avg_session_duration_sec,
    total_errors_encountered,
    last_interaction_date,
    lifetime_invoices_count,
    lifetime_subscription_spend,
    total_failed_payments,
    ROUND(customer_value_segment_percentile, 4) AS customer_value_segment_percentile,
    is_churned_target
FROM feature_assembly;
