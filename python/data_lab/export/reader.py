"""Read Postgres tables into DataFrames via psycopg cursor."""

from __future__ import annotations

from typing import Any

import pandas as pd
import psycopg
import structlog

log = structlog.get_logger(__name__)

TABLES = [
    "dim_products",
    "dim_clients",
    "fact_coc_signals",
    "fact_quotes",
    "fact_sold_policies",
    "fact_renewals",
]


def read_table(conn: psycopg.Connection[Any], table: str) -> pd.DataFrame:
    with conn.cursor() as cur:
        cur.execute(f"SELECT * FROM {table}")  # noqa: S608
        cols = [desc[0] for desc in cur.description or []]
        rows = cur.fetchall()
    df = pd.DataFrame(rows, columns=cols)
    log.info("reader.read", table=table, rows=len(df))
    return df


def read_all(conn: psycopg.Connection[Any]) -> dict[str, pd.DataFrame]:
    return {table: read_table(conn, table) for table in TABLES}
