-- ============================================================================
-- Snowflake DDL 01: Setup Database, Schemas, Warehouses, Stages & Formats
-- Project: Data Warehouse Modelling for Analytics & AI
-- ============================================================================

-- Switch to administrative role
USE ROLE ACCOUNTADMIN;

-- 1. Create Dedicated Virtual Warehouses
CREATE WAREHOUSE IF NOT EXISTS WH_ANALYTICS
    WITH WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 3
    SCALING_POLICY = 'STANDARD'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Virtual Warehouse for dbt transforms, ad-hoc SQL, and BI dashboards';

CREATE WAREHOUSE IF NOT EXISTS WH_AI_TRANSFORMS
    WITH WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 2
    SCALING_POLICY = 'ECONOMY'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Virtual Warehouse for AI feature engineering and heavy ML workloads';

-- 2. Create Central Enterprise Database
CREATE DATABASE IF NOT EXISTS ENTERPRISE_DW
    DATA_RETENTION_TIME_IN_DAYS = 7
    COMMENT = 'Enterprise Data Warehouse hosting 3-layer Lakehouse & Star Schema';

USE DATABASE ENTERPRISE_DW;

-- 3. Layered Schemas
CREATE SCHEMA IF NOT EXISTS RAW_BRONZE
    DATA_RETENTION_TIME_IN_DAYS = 3
    COMMENT = 'Layer 1: Raw ingestion staging from Delta Lake / event logs';

CREATE SCHEMA IF NOT EXISTS CURATED_SILVER
    DATA_RETENTION_TIME_IN_DAYS = 7
    COMMENT = 'Layer 2: Cleaned, deduplicated, and SCD-2 enriched tables';

CREATE SCHEMA IF NOT EXISTS ANALYTICS_GOLD
    DATA_RETENTION_TIME_IN_DAYS = 14
    COMMENT = 'Layer 3: Enterprise Star Schema (8 Dimensions + 4 Facts)';

-- Domain Data Marts
CREATE SCHEMA IF NOT EXISTS MARTS_OPERATIONS
    COMMENT = 'Operations Mart: Fulfillment SLAs, Inventory Velocity & Supply Chain';

CREATE SCHEMA IF NOT EXISTS MARTS_FINANCE
    COMMENT = 'Finance Mart: SaaS MRR/ARR Waterfall, Unit Economics & Margins';

CREATE SCHEMA IF NOT EXISTS MARTS_PRODUCT_AI
    COMMENT = 'Product & AI Mart: User Journey, AI Inferences & ML Feature Store';

-- 4. File Formats & External/Internal Stages
USE SCHEMA ANALYTICS_GOLD;

CREATE OR REPLACE FILE FORMAT FF_PARQUET
    TYPE = 'PARQUET'
    COMPRESSION = 'SNAPPY'
    BINARY_AS_TEXT = FALSE;

CREATE OR REPLACE FILE FORMAT FF_CSV
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'None');

-- Stage pointing to staged Parquet lakehouse files
CREATE STAGE IF NOT EXISTS STG_DELTA_LAKE
    FILE_FORMAT = FF_PARQUET
    COMMENT = 'Internal/External Stage for Delta Lake Parquet tables';
