"""
SQL Execution Engine & Model Runner (dbt-Style Pipeline)
Loads Star Schema tables from Gold Parquet and executes all 24 transformations
in dependency order, registering UDFs and validating output integrity.
"""
import sys
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import re
import sqlite3
import time
from typing import Dict, List, Tuple, Any
import pandas as pd
import pyarrow.parquet as pq

from config.pipeline_config import GOLD_DIR, MODELS_DIR, DIMENSIONS, FACTS


def create_warehouse_connection() -> sqlite3.Connection:
    """Creates SQLite in-memory warehouse with Snowflake/Postgres compatible UDFs."""
    conn = sqlite3.connect(":memory:")

    # Register custom UDFs for SQL dialects
    conn.create_function(
        "REGEXP_REPLACE", 3,
        lambda text, pat, repl: re.sub(pat, repl, str(text)) if text is not None else None
    )
    conn.create_function(
        "ROUND", 2,
        lambda val, dec: round(float(val), dec) if val is not None else None
    )
    conn.create_function(
        "TO_DATE", 1,
        lambda val: str(val)[:10] if val is not None else None
    )
    conn.create_function(
        "TO_TIMESTAMP", 1,
        lambda val: str(val) if val is not None else None
    )

    return conn


def load_star_schema_into_warehouse(conn: sqlite3.Connection) -> Dict[str, int]:
    """Loads all 8 Dimensions and 4 Facts from Gold staged Parquet files."""
    row_counts = {}
    all_tables = DIMENSIONS + FACTS

    for tbl in all_tables:
        parquet_path = GOLD_DIR / f"{tbl}.parquet"
        if not parquet_path.exists():
            raise FileNotFoundError(f"Missing staged Parquet table: {parquet_path}")

        df = pd.read_parquet(parquet_path)
        # Convert any boolean to int for SQLite compatibility
        for col in df.select_dtypes(include=["bool"]).columns:
            df[col] = df[col].astype(int)

        df.to_sql(tbl, conn, if_exists="replace", index=False)
        row_counts[tbl] = len(df)

    return row_counts


class DbtStyleTransformRunner:
    """Orchestrates sequential execution of 24 SQL models."""

    EXECUTION_ORDER = [
        # Staging Models (Layer A)
        ("staging", "stg_customers"),
        ("staging", "stg_products"),
        ("staging", "stg_orders"),
        ("staging", "stg_inventory"),
        ("staging", "stg_subscriptions"),
        ("staging", "stg_interactions"),
        ("staging", "stg_ai_models"),
        ("staging", "stg_suppliers"),

        # Intermediate Models (Layer B)
        ("intermediate", "int_customer_scd2"),
        ("intermediate", "int_daily_product_velocity"),
        ("intermediate", "int_mrr_revenue_waterfall"),
        ("intermediate", "int_sessionized_user_journey"),
        ("intermediate", "int_ai_token_cost_efficiency"),
        ("intermediate", "int_order_fulfillment_sla"),

        # Data Marts Models (Layer C)
        ("marts/operations", "fct_daily_fulfillment_kpi"),
        ("marts/operations", "rpt_inventory_stockout_risk"),
        ("marts/operations", "rpt_supplier_performance_scorecard"),
        ("marts/operations", "rpt_warehouse_capacity_utilization"),

        ("marts/finance", "fct_monthly_mrr_cohorts"),
        ("marts/finance", "rpt_unit_economics_margin"),
        ("marts/finance", "rpt_payment_failure_analysis"),

        ("marts/product", "fct_user_feature_adoption"),
        ("marts/product", "fct_ai_model_performance"),
        ("marts/product", "fct_churn_prediction_features")
    ]

    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn

    def run_all_transforms(self) -> List[Dict[str, Any]]:
        """Executes all 24 models and returns execution metadata."""
        results = []
        print(f"=== Executing {len(self.EXECUTION_ORDER)} dbt-style SQL Transformations ===")

        for layer, model_name in self.EXECUTION_ORDER:
            sql_file = MODELS_DIR / layer / f"{model_name}.sql"
            if not sql_file.exists():
                raise FileNotFoundError(f"Model file not found: {sql_file}")

            with open(sql_file, "r", encoding="utf-8") as f:
                sql_content = f.read().strip()

            # Remove trailing semicolon if present
            if sql_content.endswith(";"):
                sql_content = sql_content[:-1]

            create_sql = f"CREATE TABLE {model_name} AS {sql_content}"

            t0 = time.perf_counter()
            self.conn.execute(f"DROP TABLE IF EXISTS {model_name}")
            self.conn.execute(create_sql)
            duration_ms = (time.perf_counter() - t0) * 1000

            # Get row count
            cursor = self.conn.execute(f"SELECT COUNT(*) FROM {model_name}")
            row_count = cursor.fetchone()[0]

            results.append({
                "model": model_name,
                "layer": layer,
                "row_count": row_count,
                "duration_ms": round(duration_ms, 2),
                "status": "SUCCESS"
            })
            print(f"  [{layer}] {model_name}: {row_count} rows created in {duration_ms:.1f}ms")

        print("=== All SQL Transformations Completed Successfully ===")
        return results

    def fetch_model_sample(self, model_name: str, limit: int = 5) -> pd.DataFrame:
        """Fetches sample rows from an executed model."""
        return pd.read_sql_query(f"SELECT * FROM {model_name} LIMIT {limit}", self.conn)


def run_pipeline() -> Tuple[sqlite3.Connection, List[Dict[str, Any]]]:
    """Sets up warehouse, loads tables, and executes transformations."""
    conn = create_warehouse_connection()
    print("Loading Star Schema into Warehouse...")
    loaded = load_star_schema_into_warehouse(conn)
    for tbl, count in loaded.items():
        print(f"  Loaded {tbl}: {count} rows")

    runner = DbtStyleTransformRunner(conn)
    exec_results = runner.run_all_transforms()
    return conn, exec_results


if __name__ == "__main__":
    conn, results = run_pipeline()
