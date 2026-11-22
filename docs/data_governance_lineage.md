# Enterprise Data Governance & Lineage Specification

## 1. Governance Operating Framework & Ownership Matrix

This document defines the data governance policies, ownership mapping, lifecycle management, and end-to-end data lineage across the 3-Layer Delta Lakehouse and Snowflake Data Warehouse.

### RACI Governance Matrix
| Core Entity | Table | Data Owner | Data Steward | Technical Custodian | Primary Consumer Domains |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Customer** | `dim_customers` | VP of Product | Head of CRM Analytics | Lead Data Engineer | Finance, Product, AI Feature Store |
| **Product** | `dim_products` | Head of Product | Catalog Ops Specialist | Analytics Engineer | Operations, Finance, Product |
| **Order / Sales** | `fact_orders` | Operations Lead | Order Management Lead | Lead Data Engineer | Operations, Finance |
| **Inventory** | `fact_inventory_movements` | Operations Lead | Logistics & WMS Manager| Data Engineer | Operations, Procurement |
| **Billing & MRR** | `fact_subscription_billing` | Head of Finance | RevOps Analytics Lead | Lead Data Engineer | Executive, Finance, Sales |
| **AI Telemetry** | `fact_customer_interactions`| AI Platform Lead | MLOps Engineer | ML Infrastructure Engineer | Product, AI Ops, ML Modeling |
| **Calendar** | `dim_date` | Governance Council | Analytics Engineering | Analytics Engineer | All Enterprise Domains |

---

## 2. End-to-End Data Lineage

The following lineage graph tracks data transformation from source transactional applications, through Delta Lake Bronze and Silver, into Snowflake Gold Star Schema, and out to domain-specific Data Marts and Machine Learning feature consumers:

```mermaid
flowchart LR
    subgraph Sources["Operational Sources"]
        S_CRM["CRM & Auth DB"]
        S_ERP["ERP & Inventory DB"]
        S_STRIPE["Stripe Billing API"]
        S_TELEMETRY["AI Gateway / LLM Proxy Logs"]
    end

    subgraph Bronze["Delta Lake Bronze (Raw)"]
        B_CUST["bronze/dim_customers"]
        B_PROD["bronze/dim_products"]
        B_ORD["bronze/fact_orders"]
        B_INV["bronze/fact_inventory_movements"]
        B_SUB["bronze/fact_subscription_billing"]
        B_INT["bronze/fact_customer_interactions"]
    end

    subgraph Silver["Delta Lake Silver (Curated)"]
        S_CUST["silver/dim_customers (SCD2)"]
        S_PROD["silver/dim_products"]
        S_ORD["silver/fact_orders (Enriched)"]
        S_INV["silver/fact_inventory_movements"]
        S_SUB["silver/fact_subscription_billing"]
        S_INT["silver/fact_customer_interactions"]
    end

    subgraph SnowflakeGold["Snowflake Gold (Star Schema)"]
        G_CUST["dim_customers"]
        G_PROD["dim_products"]
        G_DATE["dim_date"]
        G_ORD["fact_orders (Clustered)"]
        G_INV["fact_inventory_movements (Clustered)"]
        G_SUB["fact_subscription_billing (Clustered)"]
        G_INT["fact_customer_interactions (Clustered)"]
    end

    subgraph Intermediate["Intermediate Transforms (dbt)"]
        I_SCD2["int_customer_scd2"]
        I_VEL["int_daily_product_velocity"]
        I_MRR["int_mrr_revenue_waterfall"]
        I_SESS["int_sessionized_user_journey"]
        I_EFF["int_ai_token_cost_efficiency"]
        I_SLA["int_order_fulfillment_sla"]
    end

    subgraph Marts["Domain Data Marts"]
        M_OPS1["fct_daily_fulfillment_kpi"]
        M_OPS2["rpt_inventory_stockout_risk"]
        M_FIN1["fct_monthly_mrr_cohorts"]
        M_FIN2["rpt_unit_economics_margin"]
        M_PROD1["fct_user_feature_adoption"]
        M_PROD2["fct_ai_model_performance"]
        M_PROD3["fct_churn_prediction_features"]
    end

    subgraph Consumers["Consumption Endpoints"]
        BI_OPS["Operations Tableau Dashboard"]
        BI_FIN["Executive Finance Board Report"]
        AI_CHURN["XGBoost Churn Prediction Model"]
        AI_LLM["LLM Token Cost Monitor"]
    end

    S_CRM --> B_CUST
    S_ERP --> B_PROD & B_ORD & B_INV
    S_STRIPE --> B_SUB
    S_TELEMETRY --> B_INT

    B_CUST --> S_CUST
    B_PROD --> S_PROD
    B_ORD --> S_ORD
    B_INV --> S_INV
    B_SUB --> S_SUB
    B_INT --> S_INT

    S_CUST --> G_CUST
    S_PROD --> G_PROD
    S_ORD --> G_ORD
    S_INV --> G_INV
    S_SUB --> G_SUB
    S_INT --> G_INT

    G_CUST --> I_SCD2
    G_INV --> I_VEL & I_SLA
    G_SUB --> I_MRR
    G_INT --> I_SESS & I_EFF

    I_SLA --> M_OPS1
    I_VEL --> M_OPS2
    I_MRR --> M_FIN1
    G_ORD & G_CUST --> M_FIN2
    I_SESS --> M_PROD1
    I_EFF --> M_PROD2
    G_CUST & G_ORD & G_SUB & G_INT --> M_PROD3

    M_OPS1 & M_OPS2 --> BI_OPS
    M_FIN1 & M_FIN2 --> BI_FIN
    M_PROD3 --> AI_CHURN
    M_PROD2 --> AI_LLM
```

---

## 3. Data Classification & Security Standards

| Classification | Definition | Examples | Storage Controls | Access Controls |
| :--- | :--- | :--- | :--- | :--- |
| **Public** | Information approved for unrestricted public release. | Calendar dimensions, public pricing lists, country codes. | Standard AES-256 encryption. | Read access to all authenticated roles. |
| **Internal** | Operational data intended for internal enterprise visibility. | Warehouse inventory balances, supplier lead times, product catalog. | Standard encryption at rest. | Granted to `BI_ANALYST`, `DATA_ENGINEER`, `ANALYTICS_ENGINEER`. |
| **Confidential** | Business data that could cause financial or competitive harm if leaked. | Sales order volumes, individual order items, margins, customer names. | Snowflake encryption + Audit Logging. | Restricted to authorized domain analysts and engineers. |
| **Restricted (PII)** | Personally Identifiable Information or sensitive revenue data. | Customer emails, phone numbers, individual billing invoices, churn risk scores. | Column-level Dynamic Masking (`mask_email`, `mask_phone`). | Restricted to `ACCOUNTADMIN`, `SECURITYADMIN`, and `DATA_ENGINEER`. |

---

## 4. Data Quality Contracts & Testing SLA

Every table ingested and transformed passes automated schema tests before being promoted:
1. **Uniqueness Tests**: Primary keys (`customer_sk`, `product_sk`, `order_sk`, `billing_sk`, `movement_sk`, `interaction_sk`) must have zero duplicate values.
2. **Not-Null Constraints**: Mandatory operational fields (dates, amounts, customer identifiers) must have zero null values.
3. **Referential Integrity Tests**: Foreign keys in Fact tables must cleanly join to primary keys in Dimension tables without orphaned records.
4. **Range / Value Boundaries**:
   - `quantity` $> 0$
   - `net_amount` $\ge 0$
   - `churn_risk_score` between $0.0$ and $1.0$
   - `reliability_score` between $0.0$ and $1.0$
5. **Freshness SLAs**:
   - Fact Tables: Ingested every 60 minutes with max latency of 2 hours.
   - Dimension Tables: Processed daily at 02:00 UTC.
   - Data Marts: Refreshed every morning at 04:00 UTC prior to executive reporting.
