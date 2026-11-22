# Enterprise Data Dictionary: 7 Core Entities

This Data Dictionary defines the 7 core analytical and operational entities in the `ENTERPRISE_DW` schema, detailing business context, grain, column schemas, data governance tags, PII classifications, and masking policies.

---

## Entity 1: Customer (`dim_customers`)
* **Business Definition**: Represents an enterprise, mid-market, or startup account using our platform products or cloud services.
* **Schema & Table**: `ENTERPRISE_DW.ANALYTICS_GOLD.dim_customers`
* **Grain**: One record per customer state version (SCD Type-2).
* **Primary Key**: `customer_sk` | **Natural Key**: `customer_id`
* **Data Owner**: VP of Product | **Data Steward**: Head of CRM Analytics | **SLA Tier**: Tier 1 (Critical)
* **Confidentiality**: `CONFIDENTIAL`

| Column Name | Data Type | Nullable | PII Class | Masking Policy | Description & Business Rules | Example Value |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `customer_sk` | BIGINT | No | NON_PII | None | Surrogate synthetic integer key assigned during Silver ETL. | `1042` |
| `customer_id` | VARCHAR(32) | No | INDIRECT | None | Unique natural business identifier formatted `CUST-XXXXX`. | `CUST-00104` |
| `first_name` | VARCHAR(100) | Yes | INDIRECT | None | Customer primary contact given name. | `Elena` |
| `last_name` | VARCHAR(100) | Yes | INDIRECT | None | Customer primary contact family name. | `Chen` |
| `email` | VARCHAR(255) | Yes | DIRECT | `mask_email` | Authorized account email address. Partially masked for non-admin roles. | `e****@example.com` |
| `phone` | VARCHAR(50) | Yes | DIRECT | `mask_phone` | Account contact phone number. Redacted to standard mask. | `+1-XXX-XXX-XXXX` |
| `segment` | VARCHAR(50) | No | NON_PII | None | Account market segment (`Enterprise`, `Mid-Market`, `SMB`, `High-Growth Startup`). | `Enterprise` |
| `country` | VARCHAR(100) | No | NON_PII | None | Country of incorporation/headquarters for residency routing. | `United States` |
| `churn_risk_score` | FLOAT | Yes | NON_PII | None | Predictive AI churn propensity score calculated weekly ($0.000$ to $1.000$). | `0.185` |
| `credit_rating` | VARCHAR(10) | Yes | NON_PII | None | Financial creditworthiness classification (`AAA`, `AA`, `A`, `BBB`, `NR`). | `AA` |
| `effective_start` | TIMESTAMP_NTZ | No | NON_PII | None | Timestamp marking the start of validity for this customer state. | `2025-01-01 00:00:00` |
| `effective_end` | TIMESTAMP_NTZ | No | NON_PII | None | Expiry timestamp of this state. Set to `9999-12-31 23:59:59` for current state. | `9999-12-31 23:59:59` |
| `is_current` | BOOLEAN | No | NON_PII | None | Boolean flag indicating whether this is the active current customer record. | `TRUE` |

---

## Entity 2: Product (`dim_products`)
* **Business Definition**: Catalog of software modules, AI models, cloud compute slices, and enterprise licenses.
* **Schema & Table**: `ENTERPRISE_DW.ANALYTICS_GOLD.dim_products`
* **Grain**: One record per product SKU version (SCD Type-2).
* **Primary Key**: `product_sk` | **Natural Key**: `product_id`
* **Data Owner**: Head of Product Management | **Data Steward**: Catalog Operations Specialist | **SLA Tier**: Tier 2 (Operational)
* **Confidentiality**: `INTERNAL`

| Column Name | Data Type | Nullable | PII Class | Masking Policy | Description & Business Rules | Example Value |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `product_sk` | BIGINT | No | NON_PII | None | Surrogate synthetic key. | `14` |
| `product_id` | VARCHAR(32) | No | NON_PII | None | Unique product identifier formatted `PROD-XXXX`. | `PROD-0004` |
| `product_name` | VARCHAR(200) | No | NON_PII | None | Market commercial product title. | `Delta Lake Engine Pro` |
| `category` | VARCHAR(100) | No | NON_PII | None | High-level taxonomy (`AI Infrastructure`, `Data Analytics`, `Cloud Compute`, etc.). | `Data Analytics` |
| `sku` | VARCHAR(50) | No | NON_PII | None | Stock keeping unit identifier. | `SKU-DAT-0004` |
| `unit_cost` | NUMBER(12,2) | No | FINANCIAL | None | Direct baseline COGS incurred to deliver product unit. | `450.00` |
| `list_price` | NUMBER(12,2) | No | FINANCIAL | None | Standard catalog MSRP before enterprise discounting. | `1250.00` |
| `embedding_vector_id`| VARCHAR(64) | Yes | NON_PII | None | Reference pointer to product semantic vector in external Vector Index. | `emb_dim1536_p0004`|
| `effective_start` | TIMESTAMP_NTZ | No | NON_PII | None | SCD2 starting timestamp. | `2025-01-01 00:00:00` |
| `effective_end` | TIMESTAMP_NTZ | No | NON_PII | None | SCD2 expiration timestamp. | `9999-12-31 23:59:59` |
| `is_current` | BOOLEAN | No | NON_PII | None | Current active record indicator. | `TRUE` |

---

## Entity 3: Order / Transaction (`fact_orders`)
* **Business Definition**: Commercial sales order placed by a customer across any digital or direct sales channel.
* **Schema & Table**: `ENTERPRISE_DW.ANALYTICS_GOLD.fact_orders`
* **Grain**: One record per line-item order transaction.
* **Primary Key**: `order_sk` | **Foreign Keys**: `customer_sk`, `product_sk`, `channel_sk`, `order_date`, `order_time`
* **Cluster Key**: `(order_date, customer_sk)`
* **Data Owner**: Operations Lead | **Data Steward**: Order Management Lead | **SLA Tier**: Tier 1 (Critical)
* **Confidentiality**: `CONFIDENTIAL`

| Column Name | Data Type | Nullable | PII Class | Masking Policy | Description & Business Rules | Example Value |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `order_sk` | BIGINT | No | NON_PII | None | Surrogate fact transaction key. | `401` |
| `order_id` | VARCHAR(32) | No | NON_PII | None | Operational invoice/order number formatted `ORD-XXXXXXX`. | `ORD-0000401` |
| `order_date` | DATE | No | NON_PII | None | Date of order confirmation. Foreign key to `dim_date`. | `2026-03-15` |
| `order_time` | INT | No | NON_PII | None | Time key in HHMM representation. Foreign key to `dim_time`. | `1430` |
| `customer_sk` | BIGINT | No | NON_PII | None | Purchasing customer reference. Foreign key to `dim_customers`. | `102` |
| `product_sk` | BIGINT | No | NON_PII | None | Purchased item reference. Foreign key to `dim_products`. | `5` |
| `channel_sk` | BIGINT | No | NON_PII | None | Channel of transaction origin. Foreign key to `dim_sales_channels`.| `1` |
| `quantity` | INT | No | NON_PII | None | Units purchased (strictly $> 0$). | `3` |
| `unit_price` | NUMBER(12,2) | No | FINANCIAL | None | Sale price per unit at transaction time. | `1250.00` |
| `gross_amount` | NUMBER(14,2) | No | FINANCIAL | None | $quantity \times unit\_price$. | `3750.00` |
| `discount_amount` | NUMBER(14,2) | No | FINANCIAL | None | Contractual or promotional discount granted. | `375.00` |
| `net_amount` | NUMBER(14,2) | No | FINANCIAL | None | $gross\_amount - discount\_amount$. Net recognized booking. | `3375.00` |
| `unit_cost` | NUMBER(12,2) | No | FINANCIAL | None | Unit COGS valuation at time of booking. | `450.00` |
| `total_cost` | NUMBER(14,2) | No | FINANCIAL | None | Total COGS incurred ($quantity \times unit\_cost$). | `1350.00` |
| `margin_amount` | NUMBER(14,2) | No | FINANCIAL | None | Net dollar gross profit ($net\_amount - total\_cost$). | `2025.00` |
| `margin_pct` | NUMBER(7,2) | No | FINANCIAL | None | Gross contribution margin percentage ($margin\_amount / net\_amount \times 100$). | `60.00` |
| `order_status` | VARCHAR(50) | No | NON_PII | None | Current status (`Delivered`, `Shipped`, `Processing`, `Cancelled`, `Returned`). | `Delivered` |

---

## Entity 4: Inventory Movement (`fact_inventory_movements`)
* **Business Definition**: Supply chain events recording receipts from suppliers, customer shipments, transfers, and cycle counts.
* **Schema & Table**: `ENTERPRISE_DW.ANALYTICS_GOLD.fact_inventory_movements`
* **Grain**: One record per inventory adjustment or transfer.
* **Primary Key**: `movement_sk` | **Foreign Keys**: `product_sk`, `warehouse_sk`, `supplier_sk`, `movement_date`
* **Cluster Key**: `(movement_date, product_sk)`
* **Data Owner**: Operations Lead | **Data Steward**: Logistics & Supply Chain Manager | **SLA Tier**: Tier 2 (Operational)
* **Confidentiality**: `INTERNAL`

| Column Name | Data Type | Nullable | PII Class | Masking Policy | Description & Business Rules | Example Value |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `movement_sk` | BIGINT | No | NON_PII | None | Surrogate inventory movement identifier. | `1520` |
| `movement_id` | VARCHAR(32) | No | NON_PII | None | WMS transfer or receipt tracking ID (`MOV-XXXXXXX`). | `MOV-0001520` |
| `movement_date` | DATE | No | NON_PII | None | Date of movement event. Foreign key to `dim_date`. | `2026-04-10` |
| `product_sk` | BIGINT | No | NON_PII | None | Product inventory reference. Foreign key to `dim_products`. | `8` |
| `warehouse_sk` | BIGINT | No | NON_PII | None | Facility location reference. Foreign key to `dim_warehouse_locations`.| `1` |
| `supplier_sk` | BIGINT | No | NON_PII | None | Vendor origin for inbound receipts. Foreign key to `dim_suppliers`. | `2` |
| `movement_type` | VARCHAR(50) | No | NON_PII | None | Event category (`Purchase_Receipt`, `Customer_Shipment`, `Stock_Transfer`). | `Customer_Shipment` |
| `quantity_changed`| INT | No | NON_PII | None | Signed delta units (positive = inbound, negative = outbound). | `-15` |
| `ending_on_hand_qty`| INT | No | NON_PII | None | Warehouse post-movement on-hand stock balance. | `340` |
| `unit_valuation` | NUMBER(12,2) | No | FINANCIAL | None | Cost valuation per unit. | `380.00` |
| `total_valuation_delta`| NUMBER(14,2)| No | FINANCIAL | None | $quantity\_changed \times unit\_valuation$. | `-5700.00` |
| `fulfillment_latency_hours`| INT | No | NON_PII | None | Turnaround latency in hours from order to physical fulfillment. | `18` |

---

## Entity 5: Subscription Billing (`fact_subscription_billing`)
* **Business Definition**: Recurring software subscription invoices tracking MRR, ARR, renewals, and churn events.
* **Schema & Table**: `ENTERPRISE_DW.ANALYTICS_GOLD.fact_subscription_billing`
* **Grain**: One record per subscription billing invoice.
* **Primary Key**: `billing_sk` | **Foreign Keys**: `customer_sk`, `product_sk`, `billing_date`
* **Cluster Key**: `(billing_date, customer_sk)`
* **Data Owner**: Head of Finance | **Data Steward**: Revenue Operations Lead | **SLA Tier**: Tier 1 (Critical)
* **Confidentiality**: `RESTRICTED`

| Column Name | Data Type | Nullable | PII Class | Masking Policy | Description & Business Rules | Example Value |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `billing_sk` | BIGINT | No | NON_PII | None | Surrogate billing record ID. | `890` |
| `invoice_id` | VARCHAR(32) | No | NON_PII | None | Stripe / ERP financial invoice number (`INV-XXXXXXX`). | `INV-0000890` |
| `billing_date` | DATE | No | NON_PII | None | Invoicing date. Foreign key to `dim_date`. | `2026-02-01` |
| `customer_sk` | BIGINT | No | NON_PII | None | Subscribing customer reference. Foreign key to `dim_customers`. | `45` |
| `product_sk` | BIGINT | No | NON_PII | None | Subscribed software plan. Foreign key to `dim_products`. | `2` |
| `billing_cycle` | VARCHAR(20) | No | NON_PII | None | Contract term (`Monthly` or `Annual`). | `Annual` |
| `billed_amount` | NUMBER(14,2) | No | FINANCIAL | None | Dollar amount charged on current invoice. | `8150.00` |
| `mrr_amount` | NUMBER(14,2) | No | FINANCIAL | None | Normalized Monthly Recurring Revenue contribution. | `799.00` |
| `arr_amount` | NUMBER(14,2) | No | FINANCIAL | None | Annualized Run Rate ($mrr\_amount \times 12$). | `9588.00` |
| `payment_status`| VARCHAR(50) | No | FINANCIAL | None | Processing state (`Paid`, `Failed`, `Pending`, `Refunded`). | `Paid` |
| `is_renewal` | BOOLEAN | No | NON_PII | None | True if invoice represents a contract renewal. | `TRUE` |
| `is_churn` | BOOLEAN | No | NON_PII | None | True if invoice triggered or coincided with subscription cancellation. | `FALSE` |

---

## Entity 6: Customer Interaction & AI Usage (`fact_customer_interactions`)
* **Business Definition**: Telemetry from user interactions, API endpoints, and LLM inference generation.
* **Schema & Table**: `ENTERPRISE_DW.ANALYTICS_GOLD.fact_customer_interactions`
* **Grain**: One record per user interaction / AI model execution event.
* **Primary Key**: `interaction_sk` | **Foreign Keys**: `customer_sk`, `model_sk`, `interaction_date`, `interaction_time`
* **Cluster Key**: `(interaction_date, model_sk)`
* **Data Owner**: AI Platform Lead | **Data Steward**: ML Ops Engineer | **SLA Tier**: Tier 2 (Operational)
* **Confidentiality**: `INTERNAL`

| Column Name | Data Type | Nullable | PII Class | Masking Policy | Description & Business Rules | Example Value |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `interaction_sk` | BIGINT | No | NON_PII | None | Surrogate interaction telemetry key. | `3410` |
| `session_id` | VARCHAR(64) | No | INDIRECT | None | Client browser/API session UUID. | `SESS-9b4e101c781d`|
| `interaction_date`| DATE | No | NON_PII | None | Date of interaction. Foreign key to `dim_date`. | `2026-05-18` |
| `interaction_time`| INT | No | NON_PII | None | Time key in HHMM. Foreign key to `dim_time`. | `1115` |
| `customer_sk` | BIGINT | No | NON_PII | None | User organization. Foreign key to `dim_customers`. | `78` |
| `model_sk` | BIGINT | No | NON_PII | None | AI Model invoked. Foreign key to `dim_ai_models_features`. | `2` |
| `feature_name` | VARCHAR(100) | No | NON_PII | None | Application capability invoked (e.g. `SQL Query Auto-Complete`). | `Vector RAG Retrieval`|
| `session_duration_seconds`| INT | No | NON_PII | None | Dwell time of session in seconds. | `142` |
| `prompt_tokens` | INT | No | NON_PII | None | Number of input tokens in prompt context. | `1250` |
| `completion_tokens`| INT | No | NON_PII | None | Number of output tokens generated by model. | `480` |
| `total_tokens` | INT | No | NON_PII | None | Total tokens ($prompt\_tokens + completion\_tokens$). | `1730` |
| `estimated_token_cost`| NUMBER(12,6)| No | FINANCIAL | None | Dollar API cost incurred for inference. | `0.010950` |
| `latency_seconds` | FLOAT | No | NON_PII | None | Inference latency in seconds. | `1.428` |
| `had_error` | BOOLEAN | No | NON_PII | None | True if inference experienced API failure, timeout, or rate-limit. | `FALSE` |

---

## Entity 7: Date & Temporal Ledger (`dim_date`)
* **Business Definition**: Conformed enterprise Gregorian and fiscal master calendar supporting chronological analytics.
* **Schema & Table**: `ENTERPRISE_DW.ANALYTICS_GOLD.dim_date`
* **Grain**: One record per calendar day.
* **Primary Key**: `date_key`
* **Data Owner**: Data Governance Council | **Data Steward**: Analytics Engineering Lead | **SLA Tier**: Tier 1 (Critical)
* **Confidentiality**: `PUBLIC`

| Column Name | Data Type | Nullable | PII Class | Masking Policy | Description & Business Rules | Example Value |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `date_key` | DATE | No | NON_PII | None | Primary date identifier formatted `YYYY-MM-DD`. | `2026-06-01` |
| `full_date` | VARCHAR(10) | No | NON_PII | None | String date representation. | `2026-06-01` |
| `year` | INT | No | NON_PII | None | Four-digit calendar year. | `2026` |
| `quarter` | INT | No | NON_PII | None | Calendar quarter ($1$ through $4$). | `2` |
| `month` | INT | No | NON_PII | None | Calendar month ($1$ through $12$). | `6` |
| `month_name` | VARCHAR(20) | No | NON_PII | None | English month name. | `June` |
| `day` | INT | No | NON_PII | None | Day of month ($1$ through $31$). | `1` |
| `day_of_week` | VARCHAR(20) | No | NON_PII | None | English day of week name. | `Monday` |
| `day_of_week_num` | INT | No | NON_PII | None | ISO weekday ($1 = \text{Monday}, 7 = \text{Sunday}$). | `1` |
| `is_weekend` | BOOLEAN | No | NON_PII | None | True if Saturday or Sunday. | `FALSE` |
| `fiscal_period` | VARCHAR(20) | No | NON_PII | None | Corporate fiscal quarter tag (e.g. `FY26-Q2`). | `FY26-Q2` |
