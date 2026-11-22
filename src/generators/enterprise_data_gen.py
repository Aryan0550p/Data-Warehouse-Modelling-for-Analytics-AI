"""
Enterprise Synthetic Data Generator
Produces realistic, referentially-integral datasets for Lakehouse Ingestion
and Snowflake Star Schema Modelling (4 Facts + 8 Dimensions).
"""
import sys
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import random
import uuid
from datetime import datetime, date, timedelta
from typing import Dict, List, Tuple
import pandas as pd
import numpy as np

# Set deterministic seed for reproducibility
random.seed(42)
np.random.seed(42)


class EnterpriseDataGenerator:
    """Generates coherent operational and dimensional datasets."""

    def __init__(self, start_date: str = "2025-01-01", end_date: str = "2026-11-20"):
        self.start_date = datetime.strptime(start_date, "%Y-%m-%d").date()
        self.end_date = datetime.strptime(end_date, "%Y-%m-%d").date()
        self.num_days = (self.end_date - self.start_date).days + 1

    def generate_dim_date(self) -> pd.DataFrame:
        """Generates comprehensive Date Dimension."""
        records = []
        current = self.start_date
        while current <= self.end_date:
            month = current.month
            quarter = (month - 1) // 3 + 1
            is_weekend = current.weekday() >= 5
            fiscal_quarter = f"FY{current.year % 100}-Q{quarter}"
            records.append({
                "date_key": current.strftime("%Y-%m-%d"),
                "full_date": current.strftime("%Y-%m-%d"),
                "year": current.year,
                "quarter": quarter,
                "month": month,
                "month_name": current.strftime("%B"),
                "day": current.day,
                "day_of_week": current.strftime("%A"),
                "day_of_week_num": current.weekday() + 1,
                "is_weekend": is_weekend,
                "fiscal_period": fiscal_quarter
            })
            current += timedelta(days=1)
        return pd.DataFrame(records)

    def generate_dim_time(self) -> pd.DataFrame:
        """Generates 24-hour Time Dimension."""
        records = []
        for hour in range(24):
            for minute in (0, 15, 30, 45):
                time_key = hour * 100 + minute
                if 5 <= hour < 12:
                    day_part = "Morning"
                elif 12 <= hour < 17:
                    day_part = "Afternoon"
                elif 17 <= hour < 22:
                    day_part = "Evening"
                else:
                    day_part = "Night"
                is_peak = (9 <= hour <= 11) or (14 <= hour <= 16)
                records.append({
                    "time_key": time_key,
                    "hour": hour,
                    "minute": minute,
                    "second": 0,
                    "time_string": f"{hour:02d}:{minute:02d}:00",
                    "day_part": day_part,
                    "is_peak_hour": is_peak
                })
        return pd.DataFrame(records)

    def generate_dim_customers(self, n: int = 500) -> pd.DataFrame:
        """Generates Customer Dimension with Type-2 SCD attributes and AI churn score."""
        segments = ["Enterprise", "Mid-Market", "SMB", "High-Growth Startup"]
        countries = ["United States", "United Kingdom", "Germany", "Japan", "Canada", "Singapore"]
        first_names = ["Alex", "Elena", "Marcus", "Sophia", "David", "Aria", "Liam", "Maya", "Lucas", "Zara"]
        last_names = ["Chen", "Smith", "Mueller", "Vance", "Tanaka", "Patel", "Dubois", "Kim", "Rossi", "Schmidt"]

        records = []
        for i in range(1, n + 1):
            cust_id = f"CUST-{i:05d}"
            fn = random.choice(first_names)
            ln = random.choice(last_names)
            seg = random.choice(segments)
            country = random.choice(countries)
            churn_risk = round(float(np.random.beta(a=2, b=5)), 3)
            # Baseline effective start
            eff_start = self.start_date.strftime("%Y-%m-%d 00:00:00")
            eff_end = "9999-12-31 23:59:59"

            records.append({
                "customer_sk": i,
                "customer_id": cust_id,
                "first_name": fn,
                "last_name": ln,
                "email": f"{fn.lower()}.{ln.lower()}{i}@example.com",
                "phone": f"+1-555-{random.randint(100, 999)}-{random.randint(1000, 9999)}",
                "segment": seg,
                "country": country,
                "churn_risk_score": churn_risk,
                "credit_rating": random.choice(["AAA", "AA", "A", "BBB"]),
                "effective_start": eff_start,
                "effective_end": eff_end,
                "is_current": True
            })
        return pd.DataFrame(records)

    def generate_dim_products(self, n: int = 50) -> pd.DataFrame:
        """Generates Product Dimension with vector embedding reference."""
        categories = {
            "AI Infrastructure": ["GPU Cloud Slice", "LLM Inference Endpoint", "Vector Cache Node", "Distributed Fine-Tuning Cluster"],
            "Data Analytics": ["Delta Lake Engine Pro", "Snowflake Pipeline Sync", "Real-Time Feature Store", "BI Cube Accelerator"],
            "Cloud Compute": ["Memory-Optimized Worker", "Serverless Container Node", "Edge Compute Router", "High-IOPS Block Storage"],
            "Developer Tools": ["dbt Transform Agent", "SQL Glot Optimizer", "Data Lineage Tracer", "Schema Contract Guardian"]
        }

        records = []
        prod_sk = 1
        for cat, names in categories.items():
            for name in names:
                list_price = round(random.uniform(150.0, 4500.0), 2)
                unit_cost = round(list_price * random.uniform(0.35, 0.65), 2)
                records.append({
                    "product_sk": prod_sk,
                    "product_id": f"PROD-{prod_sk:04d}",
                    "product_name": name,
                    "category": cat,
                    "sku": f"SKU-{cat[:3].upper()}-{prod_sk:04d}",
                    "unit_cost": unit_cost,
                    "list_price": list_price,
                    "embedding_vector_id": f"emb_dim1536_p{prod_sk:04d}",
                    "effective_start": "2025-01-01 00:00:00",
                    "effective_end": "9999-12-31 23:59:59",
                    "is_current": True
                })
                prod_sk += 1
        return pd.DataFrame(records)

    def generate_dim_suppliers(self) -> pd.DataFrame:
        """Generates Supplier Dimension."""
        data = [
            {"supplier_sk": 1, "supplier_id": "SUP-001", "supplier_name": "Apex Semiconductor Fab", "country": "Taiwan", "reliability_score": 0.98, "lead_time_days": 14},
            {"supplier_sk": 2, "supplier_id": "SUP-002", "supplier_name": "Optima Cloud Hardware", "country": "United States", "reliability_score": 0.94, "lead_time_days": 7},
            {"supplier_sk": 3, "supplier_id": "SUP-003", "supplier_name": "Silicon Global Logistics", "country": "South Korea", "reliability_score": 0.91, "lead_time_days": 21},
            {"supplier_sk": 4, "supplier_id": "SUP-004", "supplier_name": "EuroServer Components", "country": "Germany", "reliability_score": 0.96, "lead_time_days": 10},
            {"supplier_sk": 5, "supplier_id": "SUP-005", "supplier_name": "Nordic Optical interconnects", "country": "Sweden", "reliability_score": 0.89, "lead_time_days": 18}
        ]
        return pd.DataFrame(data)

    def generate_dim_warehouse_locations(self) -> pd.DataFrame:
        """Generates Warehouse Locations Dimension."""
        data = [
            {"warehouse_sk": 1, "warehouse_id": "WH-US-EAST", "facility_name": "Virginia Cloud Logistics Hub", "city": "Ashburn", "state": "VA", "country": "United States", "capacity_sqft": 450000},
            {"warehouse_sk": 2, "warehouse_id": "WH-US-WEST", "facility_name": "Silicon Valley Regional DC", "city": "San Jose", "state": "CA", "country": "United States", "capacity_sqft": 320000},
            {"warehouse_sk": 3, "warehouse_id": "WH-EU-CENTRAL", "facility_name": "Frankfurt Edge Distribution", "city": "Frankfurt", "state": "HE", "country": "Germany", "capacity_sqft": 280000},
            {"warehouse_sk": 4, "warehouse_id": "WH-APAC-EAST", "facility_name": "Tokyo Tech Distribution Depot", "city": "Tokyo", "state": "TK", "country": "Japan", "capacity_sqft": 210000}
        ]
        return pd.DataFrame(data)

    def generate_dim_sales_channels(self) -> pd.DataFrame:
        """Generates Sales Channels Dimension."""
        data = [
            {"channel_sk": 1, "channel_id": "CH-WEB", "channel_name": "Direct Self-Serve Web", "channel_type": "Digital", "commission_rate": 0.02},
            {"channel_sk": 2, "channel_id": "CH-APP", "channel_name": "Mobile iOS/Android App", "channel_type": "Digital", "commission_rate": 0.03},
            {"channel_sk": 3, "channel_id": "CH-ENTERPRISE", "channel_name": "Enterprise Direct Sales", "channel_type": "Direct", "commission_rate": 0.08},
            {"channel_sk": 4, "channel_id": "CH-PARTNER", "channel_name": "Global Reseller Partner API", "channel_type": "Indirect", "commission_rate": 0.12},
            {"channel_sk": 5, "channel_id": "CH-MARKETPLACE", "channel_name": "Cloud Marketplace Co-Sell", "channel_type": "Partner", "commission_rate": 0.05}
        ]
        return pd.DataFrame(data)

    def generate_dim_ai_models_features(self) -> pd.DataFrame:
        """Generates AI Models and Feature Catalog Dimension."""
        data = [
            {"model_sk": 1, "model_id": "MOD-GPT4O", "model_name": "gpt-4o", "version": "2024-11", "provider": "OpenAI", "context_window_tokens": 128000, "cost_per_1k_input_tokens": 0.0025, "cost_per_1k_output_tokens": 0.0100, "feature_category": "Reasoning & Coding"},
            {"model_sk": 2, "model_id": "MOD-CLAUDE35S", "model_name": "claude-3-5-sonnet", "version": "v2", "provider": "Anthropic", "context_window_tokens": 200000, "cost_per_1k_input_tokens": 0.0030, "cost_per_1k_output_tokens": 0.0150, "feature_category": "Analysis & Agents"},
            {"model_sk": 3, "model_id": "MOD-GEMINI15P", "model_name": "gemini-1.5-pro", "version": "002", "provider": "Google", "context_window_tokens": 2000000, "cost_per_1k_input_tokens": 0.00125, "cost_per_1k_output_tokens": 0.0050, "feature_category": "Multimodal & Long-Context"},
            {"model_sk": 4, "model_id": "MOD-LLAMA370B", "model_name": "llama-3.1-70b", "version": "instruct", "provider": "Meta", "context_window_tokens": 128000, "cost_per_1k_input_tokens": 0.0008, "cost_per_1k_output_tokens": 0.0025, "feature_category": "Open-Source Sovereign"},
            {"model_sk": 5, "model_id": "MOD-EMBED3LARGE", "model_name": "text-embedding-3-large", "version": "v1", "provider": "OpenAI", "context_window_tokens": 8192, "cost_per_1k_input_tokens": 0.00013, "cost_per_1k_output_tokens": 0.0000, "feature_category": "Vector Embeddings"}
        ]
        return pd.DataFrame(data)

    def generate_fact_orders(
        self,
        dim_cust: pd.DataFrame,
        dim_prod: pd.DataFrame,
        dim_chan: pd.DataFrame,
        n_orders: int = 4000
    ) -> pd.DataFrame:
        """Generates Fact Orders with pricing, quantities, discounts, margins, and statuses."""
        records = []
        cust_sks = dim_cust["customer_sk"].tolist()
        prod_map = dim_prod.set_index("product_sk").to_dict(orient="index")
        chan_sks = dim_chan["channel_sk"].tolist()
        statuses = ["Delivered", "Delivered", "Delivered", "Shipped", "Processing", "Cancelled", "Returned"]

        start_ts = int(datetime.combine(self.start_date, datetime.min.time()).timestamp())
        end_ts = int(datetime.combine(self.end_date, datetime.min.time()).timestamp())

        for i in range(1, n_orders + 1):
            ts = random.randint(start_ts, end_ts)
            dt = datetime.fromtimestamp(ts)
            order_date_str = dt.strftime("%Y-%m-%d")
            order_time_key = dt.hour * 100 + (dt.minute // 15) * 15

            c_sk = random.choice(cust_sks)
            p_sk = random.choice(list(prod_map.keys()))
            ch_sk = random.choice(chan_sks)

            prod_info = prod_map[p_sk]
            list_price = prod_info["list_price"]
            unit_cost = prod_info["unit_cost"]

            qty = random.choices([1, 2, 3, 5, 10, 20], weights=[0.45, 0.25, 0.15, 0.08, 0.05, 0.02])[0]
            disc_rate = random.choices([0.0, 0.05, 0.10, 0.15, 0.20], weights=[0.55, 0.20, 0.15, 0.07, 0.03])[0]

            gross = round(list_price * qty, 2)
            disc_amt = round(gross * disc_rate, 2)
            net_amt = round(gross - disc_amt, 2)
            cost_total = round(unit_cost * qty, 2)
            margin = round(net_amt - cost_total, 2)
            status = random.choice(statuses)

            records.append({
                "order_sk": i,
                "order_id": f"ORD-{i:07d}",
                "order_date": order_date_str,
                "order_time": order_time_key,
                "customer_sk": c_sk,
                "product_sk": p_sk,
                "channel_sk": ch_sk,
                "quantity": qty,
                "unit_price": list_price,
                "gross_amount": gross,
                "discount_amount": disc_amt,
                "net_amount": net_amt,
                "unit_cost": unit_cost,
                "total_cost": cost_total,
                "margin_amount": margin,
                "margin_pct": round((margin / net_amt) * 100, 2) if net_amt > 0 else 0.0,
                "order_status": status
            })
        return pd.DataFrame(records)

    def generate_fact_inventory_movements(
        self,
        dim_prod: pd.DataFrame,
        dim_wh: pd.DataFrame,
        dim_sup: pd.DataFrame,
        n_movements: int = 3000
    ) -> pd.DataFrame:
        """Generates Fact Inventory Movements with logistics SLAs, stock velocity, and balances."""
        records = []
        prod_map = dim_prod.set_index("product_sk").to_dict(orient="index")
        wh_sks = dim_wh["warehouse_sk"].tolist()
        sup_sks = dim_sup["supplier_sk"].tolist()
        movement_types = ["Purchase_Receipt", "Customer_Shipment", "Stock_Transfer", "Cycle_Adjustment"]

        start_ts = int(datetime.combine(self.start_date, datetime.min.time()).timestamp())
        end_ts = int(datetime.combine(self.end_date, datetime.min.time()).timestamp())

        # Track running balance per (warehouse, product)
        balances = {(wh, p): random.randint(200, 1000) for wh in wh_sks for p in prod_map.keys()}

        for i in range(1, n_movements + 1):
            ts = random.randint(start_ts, end_ts)
            dt = datetime.fromtimestamp(ts)
            m_date_str = dt.strftime("%Y-%m-%d")

            p_sk = random.choice(list(prod_map.keys()))
            wh_sk = random.choice(wh_sks)
            sup_sk = random.choice(sup_sks)
            m_type = random.choices(movement_types, weights=[0.35, 0.45, 0.12, 0.08])[0]

            unit_cost = prod_map[p_sk]["unit_cost"]

            if m_type == "Purchase_Receipt":
                qty = random.randint(50, 300)
            elif m_type == "Customer_Shipment":
                qty = -random.randint(1, 40)
            elif m_type == "Stock_Transfer":
                qty = random.choice([-20, 20])
            else:
                qty = random.randint(-10, 10)

            cur_bal = balances[(wh_sk, p_sk)]
            new_bal = max(0, cur_bal + qty)
            balances[(wh_sk, p_sk)] = new_bal

            latency_hrs = random.randint(4, 72)

            records.append({
                "movement_sk": i,
                "movement_id": f"MOV-{i:07d}",
                "movement_date": m_date_str,
                "product_sk": p_sk,
                "warehouse_sk": wh_sk,
                "supplier_sk": sup_sk,
                "movement_type": m_type,
                "quantity_changed": qty,
                "ending_on_hand_qty": new_bal,
                "unit_valuation": unit_cost,
                "total_valuation_delta": round(qty * unit_cost, 2),
                "fulfillment_latency_hours": latency_hrs
            })
        return pd.DataFrame(records)

    def generate_fact_subscription_billing(
        self,
        dim_cust: pd.DataFrame,
        dim_prod: pd.DataFrame,
        n_invoices: int = 2500
    ) -> pd.DataFrame:
        """Generates Fact Subscription Billing with MRR/ARR waterfall metrics."""
        records = []
        cust_sks = dim_cust["customer_sk"].tolist()
        prod_sks = dim_prod["product_sk"].tolist()
        cycles = ["Monthly", "Annual"]
        statuses = ["Paid", "Paid", "Paid", "Paid", "Pending", "Failed", "Refunded"]

        start_ts = int(datetime.combine(self.start_date, datetime.min.time()).timestamp())
        end_ts = int(datetime.combine(self.end_date, datetime.min.time()).timestamp())

        for i in range(1, n_invoices + 1):
            ts = random.randint(start_ts, end_ts)
            dt = datetime.fromtimestamp(ts)
            b_date_str = dt.strftime("%Y-%m-%d")

            c_sk = random.choice(cust_sks)
            p_sk = random.choice(prod_sks)
            cycle = random.choices(cycles, weights=[0.75, 0.25])[0]
            status = random.choice(statuses)

            base_rate = random.choice([99.0, 299.0, 799.0, 1999.0, 4999.0])
            if cycle == "Annual":
                mrr = base_rate
                arr = round(base_rate * 12.0 * 0.85, 2) # 15% annual discount
                billed_amount = arr
            else:
                mrr = base_rate
                arr = round(base_rate * 12.0, 2)
                billed_amount = mrr

            is_renewal = random.choice([True, True, False])
            is_churn = (status == "Refunded") or (random.random() < 0.04)

            records.append({
                "billing_sk": i,
                "invoice_id": f"INV-{i:07d}",
                "billing_date": b_date_str,
                "customer_sk": c_sk,
                "product_sk": p_sk,
                "billing_cycle": cycle,
                "billed_amount": billed_amount,
                "mrr_amount": mrr,
                "arr_amount": arr,
                "payment_status": status,
                "is_renewal": is_renewal,
                "is_churn": is_churn
            })
        return pd.DataFrame(records)

    def generate_fact_customer_interactions(
        self,
        dim_cust: pd.DataFrame,
        dim_models: pd.DataFrame,
        n_events: int = 5000
    ) -> pd.DataFrame:
        """Generates Fact Customer Interactions & AI Telemetry."""
        records = []
        cust_sks = dim_cust["customer_sk"].tolist()
        model_map = dim_models.set_index("model_sk").to_dict(orient="index")
        features = [
            "SQL Query Auto-Complete",
            "Data Pipeline Agent Run",
            "Semantic Schema Search",
            "Automated Churn Insight",
            "Dashboard Chat Explainer",
            "Vector RAG Retrieval"
        ]

        start_ts = int(datetime.combine(self.start_date, datetime.min.time()).timestamp())
        end_ts = int(datetime.combine(self.end_date, datetime.min.time()).timestamp())

        for i in range(1, n_events + 1):
            ts = random.randint(start_ts, end_ts)
            dt = datetime.fromtimestamp(ts)
            i_date_str = dt.strftime("%Y-%m-%d")
            i_time_key = dt.hour * 100 + (dt.minute // 15) * 15

            c_sk = random.choice(cust_sks)
            m_sk = random.choice(list(model_map.keys()))
            m_info = model_map[m_sk]
            feat = random.choice(features)

            duration = random.randint(5, 600)
            p_tokens = random.randint(150, 4000)
            c_tokens = random.randint(50, 2500)
            in_cost = (p_tokens / 1000.0) * m_info["cost_per_1k_input_tokens"]
            out_cost = (c_tokens / 1000.0) * m_info["cost_per_1k_output_tokens"]
            est_cost = round(in_cost + out_cost, 6)

            latency = round(float(np.random.gamma(shape=2.0, scale=0.8)), 3)
            had_err = random.random() < 0.025

            records.append({
                "interaction_sk": i,
                "session_id": f"SESS-{uuid.uuid4().hex[:12]}",
                "interaction_date": i_date_str,
                "interaction_time": i_time_key,
                "customer_sk": c_sk,
                "model_sk": m_sk,
                "feature_name": feat,
                "session_duration_seconds": duration,
                "prompt_tokens": p_tokens,
                "completion_tokens": c_tokens,
                "total_tokens": p_tokens + c_tokens,
                "estimated_token_cost": est_cost,
                "latency_seconds": latency,
                "had_error": had_err
            })
        return pd.DataFrame(records)


def generate_all_datasets(output_dir: Path) -> Dict[str, pd.DataFrame]:
    """Generates and dumps all 8 dimensions and 4 facts into raw sources directory."""
    output_dir.mkdir(parents=True, exist_ok=True)
    gen = EnterpriseDataGenerator()

    datasets = {}
    print("Generating Dimensions...")
    datasets["dim_date"] = gen.generate_dim_date()
    datasets["dim_time"] = gen.generate_dim_time()
    datasets["dim_customers"] = gen.generate_dim_customers()
    datasets["dim_products"] = gen.generate_dim_products()
    datasets["dim_suppliers"] = gen.generate_dim_suppliers()
    datasets["dim_warehouse_locations"] = gen.generate_dim_warehouse_locations()
    datasets["dim_sales_channels"] = gen.generate_dim_sales_channels()
    datasets["dim_ai_models_features"] = gen.generate_dim_ai_models_features()

    print("Generating Facts...")
    datasets["fact_orders"] = gen.generate_fact_orders(
        datasets["dim_customers"], datasets["dim_products"], datasets["dim_sales_channels"]
    )
    datasets["fact_inventory_movements"] = gen.generate_fact_inventory_movements(
        datasets["dim_products"], datasets["dim_warehouse_locations"], datasets["dim_suppliers"]
    )
    datasets["fact_subscription_billing"] = gen.generate_fact_subscription_billing(
        datasets["dim_customers"], datasets["dim_products"]
    )
    datasets["fact_customer_interactions"] = gen.generate_fact_customer_interactions(
        datasets["dim_customers"], datasets["dim_ai_models_features"]
    )

    for name, df in datasets.items():
        csv_path = output_dir / f"{name}.csv"
        df.to_csv(csv_path, index=False)
        print(f" -> Saved {name}: {len(df)} rows to {csv_path.name}")

    return datasets


if __name__ == "__main__":
    from config.pipeline_config import RAW_SOURCES_DIR
    generate_all_datasets(RAW_SOURCES_DIR)
