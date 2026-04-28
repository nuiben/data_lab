"""Load DataFrames into Snowflake using write_pandas."""

from __future__ import annotations

import pandas as pd
import structlog
from snowflake.connector.pandas_tools import write_pandas

from data_lab.connectors.snowflake import get_connection

log = structlog.get_logger(__name__)

# Map Postgres table names → Snowflake table names (uppercase convention).
_TABLE_MAP = {
    "dim_products":      "DIM_PRODUCTS",
    "dim_clients":       "DIM_CLIENTS",
    "fact_coc_signals":  "FACT_COC_SIGNALS",
    "fact_quotes":       "FACT_QUOTES",
    "fact_sold_policies": "FACT_SOLD_POLICIES",
    "fact_renewals":     "FACT_RENEWALS",
}


def _prepare(df: pd.DataFrame, sf_table: str) -> pd.DataFrame:
    """Uppercase column names to match Snowflake DDL."""
    out = df.copy()
    out.columns = pd.Index([c.upper() for c in out.columns])
    # Drop CREATED_AT — Snowflake DEFAULT CURRENT_TIMESTAMP() handles it.
    if "CREATED_AT" in out.columns:
        out = out.drop(columns=["CREATED_AT"])
    return out


def load_table(sf_table: str, df: pd.DataFrame) -> None:
    with get_connection() as conn:
        prepared = _prepare(df, sf_table)
        success, nchunks, nrows, _ = write_pandas(conn, prepared, sf_table)
        if not success:
            raise RuntimeError(f"write_pandas failed for {sf_table}")
        log.info("snowflake_loader.load", table=sf_table, chunks=nchunks, rows=nrows)


def load_all(frames: dict[str, pd.DataFrame]) -> None:
    for pg_table, df in frames.items():
        sf_table = _TABLE_MAP[pg_table]
        load_table(sf_table, df)
