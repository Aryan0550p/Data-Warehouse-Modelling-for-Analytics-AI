-- ============================================================================
-- Snowflake Staging & Bulk Ingestion: COPY INTO & Snowpipe Pipelines
-- Project: Data Warehouse Modelling for Analytics & AI
-- Schema: ENTERPRISE_DW.ANALYTICS_GOLD
-- ============================================================================

USE DATABASE ENTERPRISE_DW;
USE SCHEMA ANALYTICS_GOLD;

-- ----------------------------------------------------------------------------
-- 1. Dimensions COPY INTO Scripts (Loading from Staged Parquet)
-- ----------------------------------------------------------------------------

-- Load dim_customers
COPY INTO dim_customers
FROM (
    SELECT 
        $1:customer_sk::BIGINT,
        $1:customer_id::VARCHAR,
        $1:first_name::VARCHAR,
        $1:last_name::VARCHAR,
        $1:email::VARCHAR,
        $1:phone::VARCHAR,
        $1:segment::VARCHAR,
        $1:country::VARCHAR,
        $1:churn_risk_score::FLOAT,
        $1:credit_rating::VARCHAR,
        TO_TIMESTAMP_NTZ($1:effective_start::VARCHAR),
        TO_TIMESTAMP_NTZ($1:effective_end::VARCHAR),
        $1:is_current::BOOLEAN
    FROM @STG_DELTA_LAKE/dim_customers.parquet
)
FILE_FORMAT = (FORMAT_NAME = FF_PARQUET)
ON_ERROR = 'CONTINUE';

-- Load dim_products
COPY INTO dim_products
FROM (
    SELECT 
        $1:product_sk::BIGINT,
        $1:product_id::VARCHAR,
        $1:product_name::VARCHAR,
        $1:category::VARCHAR,
        $1:sku::VARCHAR,
        $1:unit_cost::NUMBER(12, 2),
        $1:list_price::NUMBER(12, 2),
        $1:embedding_vector_id::VARCHAR,
        TO_TIMESTAMP_NTZ($1:effective_start::VARCHAR),
        TO_TIMESTAMP_NTZ($1:effective_end::VARCHAR),
        $1:is_current::BOOLEAN
    FROM @STG_DELTA_LAKE/dim_products.parquet
)
FILE_FORMAT = (FORMAT_NAME = FF_PARQUET)
ON_ERROR = 'CONTINUE';

-- Load dim_date
COPY INTO dim_date
FROM (
    SELECT 
        TO_DATE($1:date_key::VARCHAR),
        $1:full_date::VARCHAR,
        $1:year::INT,
        $1:quarter::INT,
        $1:month::INT,
        $1:month_name::VARCHAR,
        $1:day::INT,
        $1:day_of_week::VARCHAR,
        $1:day_of_week_num::INT,
        $1:is_weekend::BOOLEAN,
        $1:fiscal_period::VARCHAR
    FROM @STG_DELTA_LAKE/dim_date.parquet
)
FILE_FORMAT = (FORMAT_NAME = FF_PARQUET)
ON_ERROR = 'CONTINUE';

-- Load dim_time
COPY INTO dim_time
FROM (
    SELECT 
        $1:time_key::INT,
        $1:hour::INT,
        $1:minute::INT,
        $1:second::INT,
        $1:time_string::VARCHAR,
        $1:day_part::VARCHAR,
        $1:is_peak_hour::BOOLEAN
    FROM @STG_DELTA_LAKE/dim_time.parquet
)
FILE_FORMAT = (FORMAT_NAME = FF_PARQUET)
ON_ERROR = 'CONTINUE';

-- Load dim_suppliers
COPY INTO dim_suppliers
FROM (
    SELECT 
        $1:supplier_sk::BIGINT,
        $1:supplier_id::VARCHAR,
        $1:supplier_name::VARCHAR,
        $1:country::VARCHAR,
        $1:reliability_score::FLOAT,
        $1:lead_time_days::INT
    FROM @STG_DELTA_LAKE/dim_suppliers.parquet
)
FILE_FORMAT = (FORMAT_NAME = FF_PARQUET)
ON_ERROR = 'CONTINUE';

-- Load dim_warehouse_locations
COPY INTO dim_warehouse_locations
FROM (
    SELECT 
        $1:warehouse_sk::BIGINT,
        $1:warehouse_id::VARCHAR,
        $1:facility_name::VARCHAR,
        $1:city::VARCHAR,
        $1:state::VARCHAR,
        $1:country::VARCHAR,
        $1:capacity_sqft::INT
    FROM @STG_DELTA_LAKE/dim_warehouse_locations.parquet
)
FILE_FORMAT = (FORMAT_NAME = FF_PARQUET)
ON_ERROR = 'CONTINUE';

-- Load dim_sales_channels
COPY INTO dim_sales_channels
FROM (
    SELECT 
        $1:channel_sk::BIGINT,
        $1:channel_id::VARCHAR,
        $1:channel_name::VARCHAR,
        $1:channel_type::VARCHAR,
        $1:commission_rate::NUMBER(5, 4)
    FROM @STG_DELTA_LAKE/dim_sales_channels.parquet
)
FILE_FORMAT = (FORMAT_NAME = FF_PARQUET)
ON_ERROR = 'CONTINUE';

-- Load dim_ai_models_features
COPY INTO dim_ai_models_features
FROM (
    SELECT 
        $1:model_sk::BIGINT,
        $1:model_id::VARCHAR,
        $1:model_name::VARCHAR,
        $1:version::VARCHAR,
        $1:provider::VARCHAR,
        $1:context_window_tokens::INT,
        $1:cost_per_1k_input_tokens::NUMBER(10, 6),
        $1:cost_per_1k_output_tokens::NUMBER(10, 6),
        $1:feature_category::VARCHAR
    FROM @STG_DELTA_LAKE/dim_ai_models_features.parquet
)
FILE_FORMAT = (FORMAT_NAME = FF_PARQUET)
ON_ERROR = 'CONTINUE';


-- ----------------------------------------------------------------------------
-- 2. Facts COPY INTO Scripts (Loading from Staged Parquet)
-- ----------------------------------------------------------------------------

-- Load fact_orders
COPY INTO fact_orders
FROM (
    SELECT 
        $1:order_sk::BIGINT,
        $1:order_id::VARCHAR,
        TO_DATE($1:order_date::VARCHAR),
        $1:order_time::INT,
        $1:customer_sk::BIGINT,
        $1:product_sk::BIGINT,
        $1:channel_sk::BIGINT,
        $1:quantity::INT,
        $1:unit_price::NUMBER(12, 2),
        $1:gross_amount::NUMBER(14, 2),
        $1:discount_amount::NUMBER(14, 2),
        $1:net_amount::NUMBER(14, 2),
        $1:unit_cost::NUMBER(12, 2),
        $1:total_cost::NUMBER(14, 2),
        $1:margin_amount::NUMBER(14, 2),
        $1:margin_pct::NUMBER(7, 2),
        $1:order_status::VARCHAR
    FROM @STG_DELTA_LAKE/fact_orders.parquet
)
FILE_FORMAT = (FORMAT_NAME = FF_PARQUET)
ON_ERROR = 'CONTINUE';

-- Load fact_inventory_movements
COPY INTO fact_inventory_movements
FROM (
    SELECT 
        $1:movement_sk::BIGINT,
        $1:movement_id::VARCHAR,
        TO_DATE($1:movement_date::VARCHAR),
        $1:product_sk::BIGINT,
        $1:warehouse_sk::BIGINT,
        $1:supplier_sk::BIGINT,
        $1:movement_type::VARCHAR,
        $1:quantity_changed::INT,
        $1:ending_on_hand_qty::INT,
        $1:unit_valuation::NUMBER(12, 2),
        $1:total_valuation_delta::NUMBER(14, 2),
        $1:fulfillment_latency_hours::INT
    FROM @STG_DELTA_LAKE/fact_inventory_movements.parquet
)
FILE_FORMAT = (FORMAT_NAME = FF_PARQUET)
ON_ERROR = 'CONTINUE';

-- Load fact_subscription_billing
COPY INTO fact_subscription_billing
FROM (
    SELECT 
        $1:billing_sk::BIGINT,
        $1:invoice_id::VARCHAR,
        TO_DATE($1:billing_date::VARCHAR),
        $1:customer_sk::BIGINT,
        $1:product_sk::BIGINT,
        $1:billing_cycle::VARCHAR,
        $1:billed_amount::NUMBER(14, 2),
        $1:mrr_amount::NUMBER(14, 2),
        $1:arr_amount::NUMBER(14, 2),
        $1:payment_status::VARCHAR,
        $1:is_renewal::BOOLEAN,
        $1:is_churn::BOOLEAN
    FROM @STG_DELTA_LAKE/fact_subscription_billing.parquet
)
FILE_FORMAT = (FORMAT_NAME = FF_PARQUET)
ON_ERROR = 'CONTINUE';

-- Load fact_customer_interactions
COPY INTO fact_customer_interactions
FROM (
    SELECT 
        $1:interaction_sk::BIGINT,
        $1:session_id::VARCHAR,
        TO_DATE($1:interaction_date::VARCHAR),
        $1:interaction_time::INT,
        $1:customer_sk::BIGINT,
        $1:model_sk::BIGINT,
        $1:feature_name::VARCHAR,
        $1:session_duration_seconds::INT,
        $1:prompt_tokens::INT,
        $1:completion_tokens::INT,
        $1:total_tokens::INT,
        $1:estimated_token_cost::NUMBER(12, 6),
        $1:latency_seconds::FLOAT,
        $1:had_error::BOOLEAN
    FROM @STG_DELTA_LAKE/fact_customer_interactions.parquet
)
FILE_FORMAT = (FORMAT_NAME = FF_PARQUET)
ON_ERROR = 'CONTINUE';


-- ----------------------------------------------------------------------------
-- 3. Continuous Ingestion: Snowpipe Configuration
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PIPE pipe_fact_customer_interactions
    AUTO_INGEST = TRUE
AS
COPY INTO fact_customer_interactions
FROM (
    SELECT 
        $1:interaction_sk::BIGINT,
        $1:session_id::VARCHAR,
        TO_DATE($1:interaction_date::VARCHAR),
        $1:interaction_time::INT,
        $1:customer_sk::BIGINT,
        $1:model_sk::BIGINT,
        $1:feature_name::VARCHAR,
        $1:session_duration_seconds::INT,
        $1:prompt_tokens::INT,
        $1:completion_tokens::INT,
        $1:total_tokens::INT,
        $1:estimated_token_cost::NUMBER(12, 6),
        $1:latency_seconds::FLOAT,
        $1:had_error::BOOLEAN
    FROM @STG_DELTA_LAKE/streaming_interactions/
)
FILE_FORMAT = (FORMAT_NAME = FF_PARQUET);
