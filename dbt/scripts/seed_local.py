#!/usr/bin/env python3
"""Seed data/local.duckdb from local Postgres for offline dbt development.

Run via: just dbt-seed-local
Requires duckdb installed (already in dbt/requirements.txt).
"""
import os
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent

TABLES = [
    "txn",
    "merchant",
    "account",
    "settlement",
    "dispute",
    "fleet_customer",
    "card",
    "underwriting_decision",
    "risk_score",
    "mcc_code",
    "geography",
    "partner",
    "industry_segment",
    "model_version",
]


def main() -> None:
    try:
        import duckdb
    except ImportError:
        print("duckdb not installed — run: pip install -r dbt/requirements.txt")
        sys.exit(1)

    user = os.environ["POSTGRES_USER"]
    password = os.environ["POSTGRES_PASSWORD"]
    host = os.environ.get("POSTGRES_HOST", "localhost")
    port = os.environ.get("POSTGRES_PORT", "5432")
    db = os.environ["POSTGRES_DB"]
    dsn = f"host={host} port={port} dbname={db} user={user} password={password}"

    db_path = ROOT / "data" / "local.duckdb"
    con = duckdb.connect(str(db_path))
    con.execute("INSTALL postgres_scanner; LOAD postgres_scanner;")

    for table in TABLES:
        print(f"  seeding {table}...")
        con.execute(
            f"CREATE OR REPLACE TABLE {table} AS "
            f"SELECT * FROM postgres_scan('{dsn}', 'public', '{table}')"
        )

    con.close()
    print(f"\nDone — DuckDB at {db_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
