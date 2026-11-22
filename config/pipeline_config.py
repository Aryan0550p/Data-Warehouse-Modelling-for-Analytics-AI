"""
Global Pipeline Configuration and Constants
Data Warehouse Modelling for Analytics & AI (Snowflake, Delta Lake, SQL)
"""
from pathlib import Path

# Base Paths
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
RAW_SOURCES_DIR = DATA_DIR / "raw_sources"
LAKEHOUSE_DIR = DATA_DIR / "lakehouse"
BRONZE_DIR = LAKEHOUSE_DIR / "bronze"
SILVER_DIR = LAKEHOUSE_DIR / "silver"
GOLD_DIR = LAKEHOUSE_DIR / "gold"
MODELS_DIR = BASE_DIR / "src" / "dbt_models"
DOCS_DIR = BASE_DIR / "docs"

# Warehouse & Database Names (Snowflake)
SNOWFLAKE_DATABASE = "ENTERPRISE_DW"
SCHEMA_BRONZE = "RAW_BRONZE"
SCHEMA_SILVER = "CURATED_SILVER"
SCHEMA_GOLD_DW = "ANALYTICS_GOLD"
SCHEMA_MARTS_OPS = "MARTS_OPERATIONS"
SCHEMA_MARTS_FIN = "MARTS_FINANCE"
SCHEMA_MARTS_PROD = "MARTS_PRODUCT_AI"

# Star Schema Specification: 8 Dimensions & 4 Facts
DIMENSIONS = [
    "dim_customers",
    "dim_products",
    "dim_date",
    "dim_time",
    "dim_suppliers",
    "dim_warehouse_locations",
    "dim_sales_channels",
    "dim_ai_models_features"
]

FACTS = [
    "fact_orders",
    "fact_inventory_movements",
    "fact_subscription_billing",
    "fact_customer_interactions"
]

# 3 Reporting Domains
DOMAINS = ["operations", "finance", "product"]

# Core Entities for Data Governance & Dictionary
CORE_ENTITIES = [
    "Customer",
    "Product",
    "Order_Transaction",
    "Inventory_Movement",
    "Subscription_Billing",
    "Customer_Interaction_AI",
    "Date_Temporal_Ledger"
]

# Performance / Cost Optimization Target
TARGET_QUERY_COST_REDUCTION_PCT = 38.0
