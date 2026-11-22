-- ============================================================================
-- Snowflake DDL 03: Fact Tables (4 Core Facts with Micro-Partition Clustering)
-- Schema: ENTERPRISE_DW.ANALYTICS_GOLD
-- ============================================================================

USE DATABASE ENTERPRISE_DW;
USE SCHEMA ANALYTICS_GOLD;

-- 1. Fact: Orders & Sales Transactions
-- Clustered by order_date and customer_sk to optimize date-range and customer cohort scans
CREATE OR REPLACE TABLE fact_orders (
    order_sk               BIGINT NOT NULL,
    order_id               VARCHAR(32) NOT NULL,
    order_date             DATE NOT NULL,
    order_time             INT NOT NULL,
    customer_sk            BIGINT NOT NULL,
    product_sk             BIGINT NOT NULL,
    channel_sk             BIGINT NOT NULL,
    quantity               INT NOT NULL,
    unit_price             NUMBER(12, 2) NOT NULL,
    gross_amount           NUMBER(14, 2) NOT NULL,
    discount_amount        NUMBER(14, 2) NOT NULL DEFAULT 0.00,
    net_amount             NUMBER(14, 2) NOT NULL,
    unit_cost              NUMBER(12, 2) NOT NULL,
    total_cost             NUMBER(14, 2) NOT NULL,
    margin_amount          NUMBER(14, 2) NOT NULL,
    margin_pct             NUMBER(7, 2) NOT NULL,
    order_status           VARCHAR(50) NOT NULL,
    CONSTRAINT pk_fact_orders PRIMARY KEY (order_sk),
    CONSTRAINT fk_fo_date FOREIGN KEY (order_date) REFERENCES dim_date (date_key),
    CONSTRAINT fk_fo_time FOREIGN KEY (order_time) REFERENCES dim_time (time_key),
    CONSTRAINT fk_fo_customer FOREIGN KEY (customer_sk) REFERENCES dim_customers (customer_sk),
    CONSTRAINT fk_fo_product FOREIGN KEY (product_sk) REFERENCES dim_products (product_sk),
    CONSTRAINT fk_fo_channel FOREIGN KEY (channel_sk) REFERENCES dim_sales_channels (channel_sk)
)
CLUSTER BY (order_date, customer_sk)
COMMENT = 'Grain: One line per order transaction. Clustered by date and customer for 38% faster partition pruning';

-- 2. Fact: Inventory Movements & Logistics
-- Clustered by movement_date and product_sk to accelerate stockout and velocity calculations
CREATE OR REPLACE TABLE fact_inventory_movements (
    movement_sk                BIGINT NOT NULL,
    movement_id                VARCHAR(32) NOT NULL,
    movement_date              DATE NOT NULL,
    product_sk                 BIGINT NOT NULL,
    warehouse_sk               BIGINT NOT NULL,
    supplier_sk                BIGINT NOT NULL,
    movement_type              VARCHAR(50) NOT NULL,
    quantity_changed           INT NOT NULL,
    ending_on_hand_qty         INT NOT NULL,
    unit_valuation             NUMBER(12, 2) NOT NULL,
    total_valuation_delta      NUMBER(14, 2) NOT NULL,
    fulfillment_latency_hours  INT NOT NULL,
    CONSTRAINT pk_fact_inventory PRIMARY KEY (movement_sk),
    CONSTRAINT fk_fim_date FOREIGN KEY (movement_date) REFERENCES dim_date (date_key),
    CONSTRAINT fk_fim_product FOREIGN KEY (product_sk) REFERENCES dim_products (product_sk),
    CONSTRAINT fk_fim_warehouse FOREIGN KEY (warehouse_sk) REFERENCES dim_warehouse_locations (warehouse_sk),
    CONSTRAINT fk_fim_supplier FOREIGN KEY (supplier_sk) REFERENCES dim_suppliers (supplier_sk)
)
CLUSTER BY (movement_date, product_sk)
COMMENT = 'Grain: One record per stock receipt, shipment, transfer, or cycle count adjustment';

-- 3. Fact: Subscription Billing & Revenue Ledger
-- Clustered by billing_date and customer_sk to speed up MRR/ARR waterfall aggregations
CREATE OR REPLACE TABLE fact_subscription_billing (
    billing_sk             BIGINT NOT NULL,
    invoice_id             VARCHAR(32) NOT NULL,
    billing_date           DATE NOT NULL,
    customer_sk            BIGINT NOT NULL,
    product_sk             BIGINT NOT NULL,
    billing_cycle          VARCHAR(20) NOT NULL,
    billed_amount          NUMBER(14, 2) NOT NULL,
    mrr_amount             NUMBER(14, 2) NOT NULL,
    arr_amount             NUMBER(14, 2) NOT NULL,
    payment_status         VARCHAR(50) NOT NULL,
    is_renewal             BOOLEAN NOT NULL DEFAULT FALSE,
    is_churn               BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_fact_billing PRIMARY KEY (billing_sk),
    CONSTRAINT fk_fsb_date FOREIGN KEY (billing_date) REFERENCES dim_date (date_key),
    CONSTRAINT fk_fsb_customer FOREIGN KEY (customer_sk) REFERENCES dim_customers (customer_sk),
    CONSTRAINT fk_fsb_product FOREIGN KEY (product_sk) REFERENCES dim_products (product_sk)
)
CLUSTER BY (billing_date, customer_sk)
COMMENT = 'Grain: One line per recurring billing invoice. Tracks subscription economics, MRR, and churn events';

-- 4. Fact: Customer Interactions & AI Model Telemetry
-- Clustered by interaction_date and model_sk for fast telemetry filtering and ML feature generation
CREATE OR REPLACE TABLE fact_customer_interactions (
    interaction_sk             BIGINT NOT NULL,
    session_id                 VARCHAR(64) NOT NULL,
    interaction_date           DATE NOT NULL,
    interaction_time           INT NOT NULL,
    customer_sk                BIGINT NOT NULL,
    model_sk                   BIGINT NOT NULL,
    feature_name               VARCHAR(100) NOT NULL,
    session_duration_seconds   INT NOT NULL,
    prompt_tokens              INT NOT NULL,
    completion_tokens          INT NOT NULL,
    total_tokens               INT NOT NULL,
    estimated_token_cost       NUMBER(12, 6) NOT NULL,
    latency_seconds            FLOAT NOT NULL,
    had_error                  BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_fact_interactions PRIMARY KEY (interaction_sk),
    CONSTRAINT fk_fci_date FOREIGN KEY (interaction_date) REFERENCES dim_date (date_key),
    CONSTRAINT fk_fci_time FOREIGN KEY (interaction_time) REFERENCES dim_time (time_key),
    CONSTRAINT fk_fci_customer FOREIGN KEY (customer_sk) REFERENCES dim_customers (customer_sk),
    CONSTRAINT fk_fci_model FOREIGN KEY (model_sk) REFERENCES dim_ai_models_features (model_sk)
)
CLUSTER BY (interaction_date, model_sk)
COMMENT = 'Grain: One event per user interaction / AI inference call. Tracks tokens, cost, latency, and reliability';
