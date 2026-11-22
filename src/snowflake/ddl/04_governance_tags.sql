-- ============================================================================
-- Snowflake DDL 04: Data Governance, Dynamic Masking & Object Tagging
-- Project: Data Warehouse Modelling for Analytics & AI
-- Schema: ENTERPRISE_DW.ANALYTICS_GOLD
-- ============================================================================

USE DATABASE ENTERPRISE_DW;
USE SCHEMA ANALYTICS_GOLD;

-- 1. Create Enterprise Governance Tags
CREATE TAG IF NOT EXISTS DATA_OWNER
    ALLOWED_VALUES 'Operations_Lead', 'Head_of_Finance', 'VP_Product', 'AI_Platform_Lead', 'Data_Governance_Council'
    COMMENT = 'Business domain owner accountable for data accuracy and lifecycle';

CREATE TAG IF NOT EXISTS CONFIDENTIALITY
    ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED'
    COMMENT = 'Data sensitivity classification for compliance';

CREATE TAG IF NOT EXISTS PII_CLASSIFICATION
    ALLOWED_VALUES 'DIRECT_IDENTIFIER', 'INDIRECT_IDENTIFIER', 'NON_PII'
    COMMENT = 'Personally Identifiable Information classification flag';

CREATE TAG IF NOT EXISTS SLA_TIER
    ALLOWED_VALUES 'TIER_1_CRITICAL', 'TIER_2_OPERATIONAL', 'TIER_3_ANALYTICAL'
    COMMENT = 'SLA refresh guarantee tier';

-- 2. Apply Tags to Core Tables & Columns
ALTER TABLE dim_customers SET TAG 
    DATA_OWNER = 'VP_Product',
    CONFIDENTIALITY = 'CONFIDENTIAL',
    SLA_TIER = 'TIER_1_CRITICAL';

ALTER TABLE dim_customers MODIFY COLUMN email SET TAG 
    PII_CLASSIFICATION = 'DIRECT_IDENTIFIER';

ALTER TABLE dim_customers MODIFY COLUMN phone SET TAG 
    PII_CLASSIFICATION = 'DIRECT_IDENTIFIER';

ALTER TABLE fact_orders SET TAG 
    DATA_OWNER = 'Operations_Lead',
    CONFIDENTIALITY = 'CONFIDENTIAL',
    SLA_TIER = 'TIER_1_CRITICAL';

ALTER TABLE fact_subscription_billing SET TAG 
    DATA_OWNER = 'Head_of_Finance',
    CONFIDENTIALITY = 'RESTRICTED',
    SLA_TIER = 'TIER_1_CRITICAL';

ALTER TABLE fact_customer_interactions SET TAG 
    DATA_OWNER = 'AI_Platform_Lead',
    CONFIDENTIALITY = 'INTERNAL',
    SLA_TIER = 'TIER_2_OPERATIONAL';

ALTER TABLE fact_inventory_movements SET TAG 
    DATA_OWNER = 'Operations_Lead',
    CONFIDENTIALITY = 'INTERNAL',
    SLA_TIER = 'TIER_2_OPERATIONAL';

-- 3. Dynamic Data Masking Policies
-- Mask Email for non-privileged roles
CREATE OR REPLACE MASKING POLICY mask_email AS (val VARCHAR) 
    RETURNS VARCHAR ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'DATA_ENGINEER') THEN val
        WHEN val IS NULL THEN NULL
        ELSE REGEXP_REPLACE(val, '(^[^@]{2})[^@]+(@.*$)', '\\1****\\2')
    END
    COMMENT = 'Partially masks email usernames for privacy compliance';

-- Mask Phone for non-privileged roles
CREATE OR REPLACE MASKING POLICY mask_phone AS (val VARCHAR) 
    RETURNS VARCHAR ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SECURITYADMIN') THEN val
        WHEN val IS NULL THEN NULL
        ELSE '+1-XXX-XXX-XXXX'
    END
    COMMENT = 'Redacts phone numbers to maintain CCPA/GDPR anonymity';

-- Apply Masking Policies to Customer Dimension
ALTER TABLE dim_customers MODIFY COLUMN email SET MASKING POLICY mask_email;
ALTER TABLE dim_customers MODIFY COLUMN phone SET MASKING POLICY mask_phone;

-- 4. Row Access Policy (Geographic Data Isolation)
CREATE OR REPLACE ROW ACCESS POLICY rap_customer_country AS (country_val VARCHAR)
    RETURNS BOOLEAN ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'DATA_ENGINEER', 'BI_ANALYST') THEN TRUE
        WHEN CURRENT_ROLE() = 'US_ANALYST' AND country_val = 'United States' THEN TRUE
        WHEN CURRENT_ROLE() = 'EU_ANALYST' AND country_val IN ('Germany', 'United Kingdom', 'Sweden') THEN TRUE
        ELSE FALSE
    END
    COMMENT = 'Enforces geographic data residency regulations (e.g. GDPR)';

ALTER TABLE dim_customers ADD ROW ACCESS POLICY rap_customer_country ON (country);
