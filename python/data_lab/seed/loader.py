"""Postgres loader — inserts generated seed rows into the local database."""

from __future__ import annotations

import os
from typing import Any

import psycopg
import structlog

log = structlog.get_logger(__name__)

# Fields prefixed with _ are internal pipeline metadata and not persisted.
def _strip(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [{k: v for k, v in row.items() if not k.startswith("_")} for row in rows]


def get_connection() -> psycopg.Connection[Any]:
    return psycopg.connect(
        host=os.environ.get("POSTGRES_HOST", "localhost"),
        port=int(os.environ.get("POSTGRES_PORT", "5432")),
        dbname=os.environ.get("POSTGRES_DB", "data_lab"),
        user=os.environ.get("POSTGRES_USER", "data_lab"),
        password=os.environ.get("POSTGRES_PASSWORD", ""),
    )


def _insert(
    conn: psycopg.Connection[Any],
    table: str,
    rows: list[dict[str, Any]],
) -> None:
    if not rows:
        return
    clean = _strip(rows)
    cols  = list(clean[0].keys())
    col_list  = ", ".join(cols)
    val_list  = ", ".join(f"%({c})s" for c in cols)
    query = f"INSERT INTO {table} ({col_list}) VALUES ({val_list})"  # noqa: S608
    with conn.cursor() as cur:
        cur.executemany(query, clean)
    log.info("loader.insert", table=table, rows=len(clean))


def load_all(
    conn: psycopg.Connection[Any],
    clients: list[dict[str, Any]],
    signals: list[dict[str, Any]],
    quotes: list[dict[str, Any]],
    policies: list[dict[str, Any]],
    renewals: list[dict[str, Any]],
) -> None:
    with conn.transaction():
        _insert(conn, "dim_clients",       clients)
        _insert(conn, "fact_coc_signals",  signals)
        _insert(conn, "fact_quotes",       quotes)
        _insert(conn, "fact_sold_policies", policies)
        _insert(conn, "fact_renewals",     renewals)
