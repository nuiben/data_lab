"""Load DataFrames into Snowflake using write_pandas."""

from __future__ import annotations

import pandas as pd
import structlog
from snowflake.connector.pandas_tools import write_pandas

from data_lab.connectors.snowflake import get_connection

log = structlog.get_logger(__name__)

_TABLE_MAP = {
    "merchant": "MERCHANT",
    "fleet_customer": "FLEET_CUSTOMER",
    "account": "ACCOUNT",
    "card": "CARD",
    "txn": "TXN",
    "settlement": "SETTLEMENT",
    "underwriting_decision": "UNDERWRITING_DECISION",
    "risk_score": "RISK_SCORE",
    "dispute": "DISPUTE",
    "partner": "PARTNER",
}


def _prepare(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    out.columns = pd.Index([c.upper() for c in out.columns])
    if "CREATED_AT" in out.columns:
        out = out.drop(columns=["CREATED_AT"])
    return out


def load_table(sf_table: str, df: pd.DataFrame) -> None:
    with get_connection() as conn:
        prepared = _prepare(df)
        success, nchunks, nrows, _ = write_pandas(conn, prepared, sf_table)
        if not success:
            raise RuntimeError(f"write_pandas failed for {sf_table}")
        log.info("snowflake_loader.load", table=sf_table, chunks=nchunks, rows=nrows)


def load_all(frames: dict[str, pd.DataFrame]) -> None:
    for pg_table, df in frames.items():
        sf_table = _TABLE_MAP[pg_table]
        load_table(sf_table, df)
