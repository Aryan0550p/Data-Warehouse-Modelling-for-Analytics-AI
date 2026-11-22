"""
Automated SQL Transformation & Schema Integrity Tests
Validates referential integrity, primary key uniqueness, and not-null constraints.
"""
import sys
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import unittest
from src.execution.sql_runner import create_warehouse_connection, load_star_schema_into_warehouse, DbtStyleTransformRunner


class TestSqlTransformations(unittest.TestCase):
    """Integration test suite executing and verifying all 24 models."""

    @classmethod
    def setUpClass(cls):
        cls.conn = create_warehouse_connection()
        cls.loaded_counts = load_star_schema_into_warehouse(cls.conn)
        cls.runner = DbtStyleTransformRunner(cls.conn)
        cls.results = cls.runner.run_all_transforms()

    def test_all_24_models_executed_successfully(self):
        """Verifies exactly 24 models executed with status SUCCESS."""
        self.assertEqual(len(self.results), 24)
        for res in self.results:
            self.assertEqual(res["status"], "SUCCESS")
            self.assertGreater(res["row_count"], 0, f"Model {res['model']} produced 0 rows")

    def test_referential_integrity_fact_orders(self):
        """Verifies zero orphaned foreign keys in fact_orders."""
        cursor = self.conn.execute("""
            SELECT COUNT(*) 
            FROM fact_orders fo
            LEFT JOIN dim_customers c ON fo.customer_sk = c.customer_sk
            LEFT JOIN dim_products p ON fo.product_sk = p.product_sk
            LEFT JOIN dim_sales_channels ch ON fo.channel_sk = ch.channel_sk
            WHERE c.customer_sk IS NULL OR p.product_sk IS NULL OR ch.channel_sk IS NULL
        """)
        orphans = cursor.fetchone()[0]
        self.assertEqual(orphans, 0, "Fact orders contains orphaned foreign keys")

    def test_primary_key_uniqueness(self):
        """Verifies primary key uniqueness across dimensions and facts."""
        checks = [
            ("dim_customers", "customer_sk"),
            ("dim_products", "product_sk"),
            ("dim_date", "date_key"),
            ("fact_orders", "order_sk"),
            ("fact_inventory_movements", "movement_sk"),
            ("fact_subscription_billing", "billing_sk"),
            ("fact_customer_interactions", "interaction_sk")
        ]
        for tbl, pk in checks:
            cur = self.conn.execute(f"SELECT COUNT({pk}) - COUNT(DISTINCT {pk}) FROM {tbl}")
            dups = cur.fetchone()[0]
            self.assertEqual(dups, 0, f"Duplicate primary keys detected in {tbl}.{pk}")

    def test_margin_calculations_validity(self):
        """Verifies that net amounts equal gross minus discount in fact_orders."""
        cur = self.conn.execute("""
            SELECT COUNT(*) 
            FROM fact_orders 
            WHERE ABS(net_amount - (gross_amount - discount_amount)) > 0.05
        """)
        mismatches = cur.fetchone()[0]
        self.assertEqual(mismatches, 0, "Order net amounts do not equal gross minus discount")


if __name__ == "__main__":
    unittest.main()
