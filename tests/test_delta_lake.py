"""
Unit & Integration Tests for Delta Lake Engine & Time Travel
Tests ACID transaction log protocol, schema verification, and snapshot reading.
"""
import sys
import shutil
import tempfile
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import unittest
import pandas as pd
from src.delta_engine.table import DeltaTable


class TestDeltaLakeProtocol(unittest.TestCase):
    """Validates Delta Lake ACID protocol behavior."""

    def setUp(self):
        self.test_dir = Path(tempfile.mkdtemp())
        self.table_path = self.test_dir / "test_delta_table"

    def tearDown(self):
        if self.test_dir.exists():
            shutil.rmtree(self.test_dir)

    def test_initial_write_and_log_structure(self):
        """Verifies initial write produces version 0 and protocol metadata."""
        tbl = DeltaTable(self.table_path)
        df = pd.DataFrame({
            "id": [1, 2, 3],
            "name": ["Alpha", "Beta", "Gamma"],
            "score": [10.5, 20.0, 35.2]
        })
        v = tbl.write(df, mode="append")
        self.assertEqual(v, 0)
        self.assertEqual(tbl.latest_version, 0)

        log_file = self.table_path / "_delta_log" / "00000000000000000000.json"
        self.assertTrue(log_file.exists())

        # Verify read
        read_df = tbl.read()
        self.assertEqual(len(read_df), 3)
        self.assertListEqual(list(read_df["name"]), ["Alpha", "Beta", "Gamma"])

    def test_time_travel_and_overwrite(self):
        """Verifies Time Travel between version 0 and version 1."""
        tbl = DeltaTable(self.table_path)
        df_v0 = pd.DataFrame({"id": [1, 2], "val": ["v0_a", "v0_b"]})
        tbl.write(df_v0, mode="append")

        df_v1 = pd.DataFrame({"id": [3, 4], "val": ["v1_c", "v1_d"]})
        v1 = tbl.write(df_v1, mode="overwrite")
        self.assertEqual(v1, 1)

        # Time travel to version 0
        df_at_0 = tbl.read(version=0)
        self.assertEqual(len(df_at_0), 2)
        self.assertEqual(df_at_0["id"].tolist(), [1, 2])

        # Read latest (version 1)
        df_at_1 = tbl.read(version=1)
        self.assertEqual(len(df_at_1), 2)
        self.assertEqual(df_at_1["id"].tolist(), [3, 4])

    def test_commit_history_audit(self):
        """Verifies audit trail retrieval."""
        tbl = DeltaTable(self.table_path)
        df = pd.DataFrame({"x": [10, 20]})
        tbl.write(df, mode="append", author="TestAgent")
        history = tbl.get_history()
        self.assertEqual(len(history), 1)
        self.assertEqual(history[0]["userName"], "TestAgent")
        self.assertEqual(history[0]["version"], 0)


if __name__ == "__main__":
    unittest.main()
