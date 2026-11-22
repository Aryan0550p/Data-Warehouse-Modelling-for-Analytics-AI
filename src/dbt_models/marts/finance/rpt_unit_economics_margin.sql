-- ============================================================================
-- Mart: Finance
-- Model: rpt_unit_economics_margin
-- Purpose: Gross margin, discount depth, and unit profitability by product line and segment
-- ============================================================================

WITH transaction_margins AS (
    SELECT
        p.category AS product_category,
        p.product_name,
        c.customer_segment,
        o.order_id,
        o.quantity,
        o.gross_amount,
        o.discount_amount,
        o.net_amount,
        o.total_cost,
        o.margin_amount
    FROM stg_orders o
    INNER JOIN dim_products p ON o.product_sk = p.product_sk
    INNER JOIN stg_customers c ON o.customer_sk = c.customer_sk
    WHERE o.is_delivered = 1
),

aggregated_economics AS (
    SELECT
        product_category,
        product_name,
        customer_segment,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(quantity) AS total_units_sold,
        SUM(gross_amount) AS total_gross_revenue,
        SUM(discount_amount) AS total_discounts_granted,
        SUM(net_amount) AS total_net_revenue,
        SUM(total_cost) AS total_cogs,
        SUM(margin_amount) AS total_gross_profit
    FROM transaction_margins
    GROUP BY product_category, product_name, customer_segment
)

SELECT
    product_category,
    product_name,
    customer_segment,
    total_orders,
    total_units_sold,
    ROUND(total_gross_revenue, 2) AS total_gross_revenue,
    ROUND(total_discounts_granted, 2) AS total_discounts_granted,
    ROUND(total_net_revenue, 2) AS total_net_revenue,
    ROUND(total_cogs, 2) AS total_cogs,
    ROUND(total_gross_profit, 2) AS total_gross_profit,
    -- Effective discount rate
    ROUND((total_discounts_granted / NULLIF(total_gross_revenue, 0)) * 100, 2) AS effective_discount_pct,
    -- Gross Margin Percentage
    ROUND((total_gross_profit / NULLIF(total_net_revenue, 0)) * 100, 2) AS gross_margin_pct,
    -- Rank profitability within category
    DENSE_RANK() OVER (
        PARTITION BY product_category 
        ORDER BY total_gross_profit DESC
    ) AS category_profitability_rank
FROM aggregated_economics;
