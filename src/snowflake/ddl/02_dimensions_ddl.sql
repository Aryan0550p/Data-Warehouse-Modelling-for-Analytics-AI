-- ============================================================================
-- Snowflake DDL 02: Dimension Tables (8 Core Dimensions)
-- Schema: ENTERPRISE_DW.ANALYTICS_GOLD
-- ============================================================================

USE DATABASE ENTERPRISE_DW;
USE SCHEMA ANALYTICS_GOLD;

-- 1. Dimension: Customers (SCD Type-2)
CREATE OR REPLACE TABLE dim_customers (
    customer_sk            BIGINT NOT NULL,
    customer_id            VARCHAR(32) NOT NULL,
    first_name             VARCHAR(100),
    last_name              VARCHAR(100),
    email                  VARCHAR(255),
    phone                  VARCHAR(50),
    segment                VARCHAR(50) NOT NULL,
    country                VARCHAR(100) NOT NULL,
    churn_risk_score       FLOAT,
    credit_rating          VARCHAR(10),
    effective_start        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    effective_end          TIMESTAMP_NTZ NOT NULL DEFAULT TO_TIMESTAMP_NTZ('9999-12-31 23:59:59'),
    is_current             BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_dim_customers PRIMARY KEY (customer_sk)
)
COMMENT = 'Customer Dimension with Type-2 Slowly Changing Dimension tracking and AI churn score';

-- 2. Dimension: Products (SCD Type-2 & AI Vector Reference)
CREATE OR REPLACE TABLE dim_products (
    product_sk             BIGINT NOT NULL,
    product_id             VARCHAR(32) NOT NULL,
    product_name           VARCHAR(200) NOT NULL,
    category               VARCHAR(100) NOT NULL,
    sku                    VARCHAR(50) NOT NULL,
    unit_cost              NUMBER(12, 2) NOT NULL,
    list_price             NUMBER(12, 2) NOT NULL,
    embedding_vector_id    VARCHAR(64),
    effective_start        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    effective_end          TIMESTAMP_NTZ NOT NULL DEFAULT TO_TIMESTAMP_NTZ('9999-12-31 23:59:59'),
    is_current             BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_dim_products PRIMARY KEY (product_sk)
)
COMMENT = 'Product Dimension containing catalog hierarchy, pricing tiers, and vector embeddings reference';

-- 3. Dimension: Date (Temporal Master Calendar)
CREATE OR REPLACE TABLE dim_date (
    date_key               DATE NOT NULL,
    full_date              VARCHAR(10) NOT NULL,
    year                   INT NOT NULL,
    quarter                INT NOT NULL,
    month                  INT NOT NULL,
    month_name             VARCHAR(20) NOT NULL,
    day                    INT NOT NULL,
    day_of_week            VARCHAR(20) NOT NULL,
    day_of_week_num        INT NOT NULL,
    is_weekend             BOOLEAN NOT NULL,
    fiscal_period          VARCHAR(20) NOT NULL,
    CONSTRAINT pk_dim_date PRIMARY KEY (date_key)
)
COMMENT = 'Conformed Date Dimension spanning fiscal periods, quarters, and Gregorian calendar';

-- 4. Dimension: Time (24-Hour Diurnal Grain)
CREATE OR REPLACE TABLE dim_time (
    time_key               INT NOT NULL,
    hour                   INT NOT NULL,
    minute                 INT NOT NULL,
    second                 INT NOT NULL,
    time_string            VARCHAR(8) NOT NULL,
    day_part               VARCHAR(20) NOT NULL,
    is_peak_hour           BOOLEAN NOT NULL,
    CONSTRAINT pk_dim_time PRIMARY KEY (time_key)
)
COMMENT = 'Conformed Time Dimension supporting intraday operational and latency slicing';

-- 5. Dimension: Suppliers
CREATE OR REPLACE TABLE dim_suppliers (
    supplier_sk            BIGINT NOT NULL,
    supplier_id            VARCHAR(32) NOT NULL,
    supplier_name          VARCHAR(150) NOT NULL,
    country                VARCHAR(100) NOT NULL,
    reliability_score      FLOAT NOT NULL,
    lead_time_days         INT NOT NULL,
    CONSTRAINT pk_dim_suppliers PRIMARY KEY (supplier_sk)
)
COMMENT = 'Supplier Dimension tracking vendor logistics reliability and procurement lead time';

-- 6. Dimension: Warehouse Locations
CREATE OR REPLACE TABLE dim_warehouse_locations (
    warehouse_sk           BIGINT NOT NULL,
    warehouse_id           VARCHAR(32) NOT NULL,
    facility_name          VARCHAR(150) NOT NULL,
    city                   VARCHAR(100) NOT NULL,
    state                  VARCHAR(50),
    country                VARCHAR(100) NOT NULL,
    capacity_sqft          INT NOT NULL,
    CONSTRAINT pk_dim_warehouse PRIMARY KEY (warehouse_sk)
)
COMMENT = 'Facility and Logistics Fulfillment Centers Dimension';

-- 7. Dimension: Sales Channels
CREATE OR REPLACE TABLE dim_sales_channels (
    channel_sk             BIGINT NOT NULL,
    channel_id             VARCHAR(32) NOT NULL,
    channel_name           VARCHAR(100) NOT NULL,
    channel_type           VARCHAR(50) NOT NULL,
    commission_rate        NUMBER(5, 4) NOT NULL,
    CONSTRAINT pk_dim_channels PRIMARY KEY (channel_sk)
)
COMMENT = 'Sales Channel Dimension categorizing Web, App, Direct Sales, and Marketplace routes';

-- 8. Dimension: AI Models & Features
CREATE OR REPLACE TABLE dim_ai_models_features (
    model_sk                   BIGINT NOT NULL,
    model_id                   VARCHAR(32) NOT NULL,
    model_name                 VARCHAR(100) NOT NULL,
    version                    VARCHAR(50) NOT NULL,
    provider                   VARCHAR(100) NOT NULL,
    context_window_tokens      INT NOT NULL,
    cost_per_1k_input_tokens   NUMBER(10, 6) NOT NULL,
    cost_per_1k_output_tokens  NUMBER(10, 6) NOT NULL,
    feature_category           VARCHAR(100) NOT NULL,
    CONSTRAINT pk_dim_ai_models PRIMARY KEY (model_sk)
)
COMMENT = 'Dimension of Foundation AI Models, inference token costs, context windows, and feature taxonomy';
