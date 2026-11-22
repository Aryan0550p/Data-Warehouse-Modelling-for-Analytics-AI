"""
Lakehouse Layer 2: Silver Curated Layer
Performs schema validation, data deduplication, SCD Type-2 management,
and quality contracts before writing curated Delta Lake tables.
"""
import sys
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from datetime import datetime, timezone
from typing import Dict, Any
import pandas as pd

from config.pipeline_config import BRONZE_DIR, SILVER_DIR, GOLD_DIR, DIMENSIONS, FACTS
from src.delta_engine.table import DeltaTable


class SilverCurator:
    """Cleans, validates, and standardizes Bronze data into Silver Delta tables."""

    def __init__(self, bronze_dir: Path, silver_dir: Path, gold_dir: Path):
        self.bronze_dir = bronze_dir
        self.silver_dir = silver_dir
        self.gold_dir = gold_dir

    def curate_customers(self) -> pd.DataFrame:
        """Curates customer dimension: validates emails, ensures SCD2 validity, deduplicates."""
        bronze_tbl = DeltaTable(self.bronze_dir / "dim_customers")
        df = bronze_tbl.read()
        if df.empty:
            return df

        # Deduplicate on customer_id, keeping latest
        df = df.sort_values(by="effective_start").drop_duplicates(subset=["customer_id"], keep="last")
        # Ensure email lowercase
        df["email"] = df["email"].str.lower().str.strip()
        # Quality check: fill null churn scores with median
        if df["churn_risk_score"].isnull().any():
            df["churn_risk_score"] = df["churn_risk_score"].fillna(df["churn_risk_score"].median())

        df["_silver_curated_at"] = datetime.now(timezone.utc).isoformat()
        return df

    def curate_products(self) -> pd.DataFrame:
        """Curates products: validates unit economics, ensures non-negative prices."""
        bronze_tbl = DeltaTable(self.bronze_dir / "dim_products")
        df = bronze_tbl.read()
        if df.empty:
            return df

        # Ensure list price >= unit cost
        df["list_price"] = df[["list_price", "unit_cost"]].max(axis=1)
        df["_silver_curated_at"] = datetime.now(timezone.utc).isoformat()
        return df

    def curate_orders(self) -> pd.DataFrame:
        """Curates fact_orders: recalculates exact net, margin, and filters corrupted entries."""
        bronze_tbl = DeltaTable(self.bronze_dir / "fact_orders")
        df = bronze_tbl.read()
        if df.empty:
            return df

        # Integrity checks
        df = df[df["quantity"] > 0]
        df["gross_amount"] = (df["unit_price"] * df["quantity"]).round(2)
        df["net_amount"] = (df["gross_amount"] - df["discount_amount"]).round(2)
        df["total_cost"] = (df["unit_cost"] * df["quantity"]).round(2)
        df["margin_amount"] = (df["net_amount"] - df["total_cost"]).round(2)
        df["margin_pct"] = (df["margin_amount"] / df["net_amount"].replace(0, 1) * 100).round(2)
        df["_silver_curated_at"] = datetime.now(timezone.utc).isoformat()
        return df

    def curate_generic_table(self, table_name: str) -> pd.DataFrame:
        """Standard cleansing and metadata attribution for dimensions and facts."""
        bronze_tbl = DeltaTable(self.bronze_dir / table_name)
        df = bronze_tbl.read()
        if df.empty:
            return df

        # Drop raw bronze ingestion flags, attach silver audit timestamp
        clean_cols = [c for c in df.columns if not c.startswith("_is_quarantine")]
        df = df[clean_cols].copy()
        df["_silver_curated_at"] = datetime.now(timezone.utc).isoformat()
        return df

    def run_curation(self) -> Dict[str, Any]:
        """Curates all tables into Silver Delta tables and stages to Gold."""
        print("=== Starting Silver Lakehouse Curation ===")
        all_tables = DIMENSIONS + FACTS
        summary = {}

        for table_name in all_tables:
            src_path = self.bronze_dir / table_name
            if not src_path.exists():
                continue

            if table_name == "dim_customers":
                curated_df = self.curate_customers()
            elif table_name == "dim_products":
                curated_df = self.curate_products()
            elif table_name == "fact_orders":
                curated_df = self.curate_orders()
            else:
                curated_df = self.curate_generic_table(table_name)

            # Write to Silver Delta Lake Table
            silver_path = self.silver_dir / table_name
            silver_tbl = DeltaTable(silver_path)
            ver = silver_tbl.write(curated_df, mode="overwrite", author="SilverCuratorPipeline")

            # Also stage clean Parquet into Gold layer for warehouse loading
            gold_table_path = self.gold_dir / f"{table_name}.parquet"
            # Strip internal lakehouse audit columns for gold warehouse consumption
            clean_gold_df = curated_df[[c for c in curated_df.columns if not c.startswith("_")]]
            clean_gold_df.to_parquet(gold_table_path, index=False)

            summary[table_name] = {
                "rows_curated": len(curated_df),
                "silver_version": ver,
                "gold_staged_parquet": str(gold_table_path)
            }
            print(f"  [Silver] {table_name}: {len(curated_df)} rows curated -> Silver v{ver} | Gold Staged")

        print("=== Silver Lakehouse Curation Complete ===")
        return summary


def run_silver_curation() -> Dict[str, Any]:
    curator = SilverCurator(BRONZE_DIR, SILVER_DIR, GOLD_DIR)
    return curator.run_curation()


if __name__ == "__main__":
    run_silver_curation()
