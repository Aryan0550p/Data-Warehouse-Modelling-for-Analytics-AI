"""
Lakehouse Layer 1: Bronze Ingestion
Ingests raw operational source files into Delta Lake Bronze tables with ingestion metadata.
"""
import sys
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import uuid
import hashlib
from datetime import datetime, timezone
from typing import Dict, Any
import pandas as pd

from config.pipeline_config import RAW_SOURCES_DIR, BRONZE_DIR, DIMENSIONS, FACTS
from src.delta_engine.table import DeltaTable


def ingest_table_to_bronze(source_csv: Path, bronze_base_dir: Path, batch_id: str) -> Dict[str, Any]:
    """Ingests a single CSV into a Bronze Delta table with audit columns."""
    table_name = source_csv.stem
    df_raw = pd.read_csv(source_csv)

    now_utc = datetime.now(timezone.utc).isoformat()
    # Add Bronze ingestion metadata
    df_raw["_ingested_at"] = now_utc
    df_raw["_source_file"] = source_csv.name
    df_raw["_batch_id"] = batch_id
    df_raw["_is_quarantine"] = False

    table_path = bronze_base_dir / table_name
    delta_tbl = DeltaTable(table_path)
    # Bronze ingest is append-only
    commit_ver = delta_tbl.write(df_raw, mode="append", author="BronzeIngestionPipeline")

    return {
        "table_name": table_name,
        "rows_ingested": len(df_raw),
        "commit_version": commit_ver,
        "delta_path": str(table_path)
    }


def run_bronze_ingestion() -> Dict[str, Any]:
    """Runs ingestion across all 8 dimensions and 4 facts into Bronze layer."""
    batch_id = str(uuid.uuid4())
    print(f"=== Starting Bronze Lakehouse Ingestion [Batch: {batch_id}] ===")
    results = {}

    all_tables = DIMENSIONS + FACTS
    for table_name in all_tables:
        csv_file = RAW_SOURCES_DIR / f"{table_name}.csv"
        if not csv_file.exists():
            print(f"Warning: Source file {csv_file} not found. Skipping.")
            continue
        res = ingest_table_to_bronze(csv_file, BRONZE_DIR, batch_id)
        results[table_name] = res
        print(f"  [Bronze] {table_name}: Ingested {res['rows_ingested']} rows -> Delta v{res['commit_version']}")

    print("=== Bronze Lakehouse Ingestion Complete ===")
    return results


if __name__ == "__main__":
    run_bronze_ingestion()
