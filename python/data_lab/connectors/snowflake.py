"""Snowflake connector.

Credentials are read from environment variables (see .env.example).
Uses the official snowflake-connector-python; Rust Snowflake drivers
are not mature enough yet.
"""

from __future__ import annotations

import os
from contextlib import contextmanager
from collections.abc import Generator

import snowflake.connector
import structlog
from snowflake.connector import SnowflakeConnection

log = structlog.get_logger(__name__)


def _conn_params() -> dict:
    return {
        "account": os.environ["SNOWFLAKE_ACCOUNT"],
        "user": os.environ["SNOWFLAKE_USER"],
        "password": os.environ["SNOWFLAKE_PASSWORD"],
        "warehouse": os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
        "database": os.environ.get("SNOWFLAKE_DATABASE", "DATA_LAB"),
        "schema": os.environ.get("SNOWFLAKE_SCHEMA", "PUBLIC"),
        "role": os.environ.get("SNOWFLAKE_ROLE", "SYSADMIN"),
    }


@contextmanager
def get_connection() -> Generator[SnowflakeConnection, None, None]:
    """Context manager that yields an open Snowflake connection."""
    conn = snowflake.connector.connect(**_conn_params())
    log.info("snowflake.connect", account=os.environ.get("SNOWFLAKE_ACCOUNT"))
    try:
        yield conn
    finally:
        conn.close()
        log.info("snowflake.disconnect")


def execute_query(sql: str, params: tuple | None = None) -> list[dict]:
    """Execute *sql* and return results as a list of dicts."""
    with get_connection() as conn:
        cur = conn.cursor(snowflake.connector.DictCursor)
        cur.execute(sql, params)
        results = cur.fetchall()
        log.debug("snowflake.query", rows=len(results), sql=sql[:80])
        return results
