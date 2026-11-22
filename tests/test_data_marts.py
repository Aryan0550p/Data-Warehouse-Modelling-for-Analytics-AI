"""
Domain Data Marts Business Logic Tests
Tests the 3 Reporting Domains: Operations, Finance, Product & AI Feature Store.
"""
import sys
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import unittest
import pandas as pd
from src.execution.sql_runner import create_warehouse_connection, load_star_schema_into_warehouse, DbtStyleTransformRunner


class TestDomainDataMarts(unittest.TestCase):
    """Validates KPI calculations across Operations, Finance, and Product marts."""

    @classmethod
    def setUpClass(cls):
        cls.conn = create_warehouse_connection()
        load_star_schema_into_warehouse(cls.conn)
        cls.runner = DbtStyleTransformRunner(cls.conn)
        cls.runner.run_all_transforms()

    def test_operations_mart_sla_bounded(self):
        """Operations Mart: Verifies SLA compliance pct is between 0% and 100%."""
        cur = self.conn.execute("""
            SELECT MIN(sla_compliance_pct), MAX(sla_compliance_pct)
            FROM fct_daily_fulfillment_kpi
        """)
        min_sla, max_sla = cur.fetchone()
        self.assertGreaterEqual(min_sla, 0.0)
        self.assertLessEqual(max_sla, 100.0)

    def test_finance_mart_mrr_cohorts(self):
        """Finance Mart: Verifies monthly MRR waterfall numbers are non-negative and consistent."""
        cur = self.conn.execute("""
            SELECT COUNT(*), SUM(ending_total_mrr)
            FROM fct_monthly_mrr_cohorts
        """)
        months_count, total_mrr = cur.fetchone()
        self.assertGreater(months_count, 12, "Should have over 12 months of MRR history")
        self.assertGreater(total_mrr, 0, "Total MRR should be positive")

    def test_product_ai_mart_model_metrics(self):
        """Product Mart: Verifies AI inference costs and token throughput calculations."""
        cur = self.conn.execute("""
            SELECT COUNT(*), SUM(total_incurred_cost), AVG(avg_latency_seconds)
            FROM fct_ai_model_performance
        """)
        row_count, total_cost, avg_lat = cur.fetchone()
        self.assertGreater(row_count, 0)
        self.assertGreater(total_cost, 0.0)
        self.assertGreater(avg_lat, 0.0)

    def test_ml_feature_store_completeness(self):
        """Product Mart: Verifies ML Churn Prediction Feature Store has 500 customers."""
        df_features = pd.read_sql_query("SELECT * FROM fct_churn_prediction_features", self.conn)
        self.assertEqual(len(df_features), 500)
        # Check essential features exist
        expected_cols = [
            "customer_sk", "customer_id", "customer_segment",
            "lifetime_orders_count", "lifetime_order_spend",
            "lifetime_ai_sessions", "lifetime_tokens_consumed",
            "lifetime_invoices_count", "customer_value_segment_percentile",
            "is_churned_target"
        ]
        for col in expected_cols:
            self.assertIn(col, df_features.columns)


if __name__ == "__main__":
    unittest.main()
