-- ============================================================================
-- Snowflake Enterprise Environment Configuration
-- Project: Data Warehouse Modelling for Analytics & AI
-- 3-Layer Architecture + Star Schema + Data Marts
-- ============================================================================

-- 1. Roles & Privileges
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS DATA_ENGINEER;
CREATE ROLE IF NOT EXISTS ANALYTICS_ENGINEER;
CREATE ROLE IF NOT EXISTS BI_ANALYST;
CREATE ROLE IF NOT EXISTS ML_SCIENTIST;

-- 2. Virtual Warehouses with Auto-Suspend & Auto-Resume
-- Standard Analytics Warehouse (X-Small to Medium auto-scaling)
CREATE WAREHOUSE IF NOT EXISTS WH_ANALYTICS
    WITH WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 3
    SCALING_POLICY = 'STANDARD'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Virtual Warehouse for Analytics, SQL transforms, and BI queries';

-- Dedicated ML & Heavy Transformation Warehouse
CREATE WAREHOUSE IF NOT EXISTS WH_AI_TRANSFORMS
    WITH WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 2
    SCALING_POLICY = 'ECONOMY'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Virtual Warehouse for Feature Store generation and heavy aggregations';

-- 3. Database Creation
CREATE DATABASE IF NOT EXISTS ENTERPRISE_DW
    DATA_RETENTION_TIME_IN_DAYS = 7
    COMMENT = 'Enterprise Data Warehouse with 3-layer Lakehouse & Star Schema';

USE DATABASE ENTERPRISE_DW;

-- 4. Schemas for 3-Layer Lakehouse & Marts
-- Layer 1: Bronze (Raw ingestion)
CREATE SCHEMA IF NOT EXISTS RAW_BRONZE
    DATA_RETENTION_TIME_IN_DAYS = 3
    COMMENT = 'Raw ingested data from operational systems & event streaming';

-- Layer 2: Silver (Curated, Deduplicated, SCD2)
CREATE SCHEMA IF NOT EXISTS CURATED_SILVER
    DATA_RETENTION_TIME_IN_DAYS = 7
    COMMENT = 'Cleaned, deduplicated, and enriched tables with SCD-2 tracking';

-- Layer 3: Gold (Enterprise Star Schema: 8 Dims + 4 Facts)
CREATE SCHEMA IF NOT EXISTS ANALYTICS_GOLD
    DATA_RETENTION_TIME_IN_DAYS = 14
    COMMENT = 'Enterprise Dimensional Model (Star Schema) for Analytics and AI';

-- Data Marts (3 Domains)
CREATE SCHEMA IF NOT EXISTS MARTS_OPERATIONS
    COMMENT = 'Operations Domain Mart: Fulfillment SLA, Inventory, Supplier performance';

CREATE SCHEMA IF NOT EXISTS MARTS_FINANCE
    COMMENT = 'Finance Domain Mart: MRR Waterfall, Unit Economics, Margin, Churn';

CREATE SCHEMA IF NOT EXISTS MARTS_PRODUCT_AI
    COMMENT = 'Product & AI Domain Mart: Engagement, AI Token cost, ML Feature Store';

-- 5. External Stages & File Formats for Delta Lake Integration
CREATE OR REPLACE FILE FORMAT FF_PARQUET
    TYPE = 'PARQUET'
    COMPRESSION = 'SNAPPY';

CREATE OR REPLACE FILE FORMAT FF_JSON
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = TRUE;

CREATE OR REPLACE FILE FORMAT FF_CSV_STAGING
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'None');

-- Internal Stage for Delta Lake Parquet/Delta payload staging
CREATE STAGE IF NOT EXISTS STG_DELTA_LAKE
    FILE_FORMAT = FF_PARQUET
    COMMENT = 'Stage for Delta Lake Bronze/Silver/Gold Parquet tables';

-- 6. Resource Monitors (Cost Governance & Guardrails)
CREATE RESOURCE MONITOR IF NOT EXISTS RM_DAILY_GUARDRAIL
    WITH CREDIT_QUOTA = 50
    FREQUENCY = DAILY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS 
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE WH_ANALYTICS SET RESOURCE_MONITOR = RM_DAILY_GUARDRAIL;
ALTER WAREHOUSE WH_AI_TRANSFORMS SET RESOURCE_MONITOR = RM_DAILY_GUARDRAIL;
