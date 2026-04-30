"""Postgres loader — inserts generated seed rows into the local database."""

from __future__ import annotations

import os
from typing import Any

import psycopg
import structlog

log = structlog.get_logger(__name__)


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
    cols = list(clean[0].keys())
    col_list = ", ".join(cols)
    val_list = ", ".join(f"%({c})s" for c in cols)
    query = f"INSERT INTO {table} ({col_list}) VALUES ({val_list})"  # noqa: S608
    with conn.cursor() as cur:
        cur.executemany(query, clean)
    log.info("loader.insert", table=table, rows=len(clean))


def load_all(
    conn: psycopg.Connection[Any],
    *,
    merchants: list[dict[str, Any]],
    fleet_customers: list[dict[str, Any]],
    accounts: list[dict[str, Any]],
    cards: list[dict[str, Any]],
    txns: list[dict[str, Any]],
    settlements: list[dict[str, Any]],
    decisions: list[dict[str, Any]],
    risk_scores: list[dict[str, Any]],
    disputes: list[dict[str, Any]],
    partners: list[dict[str, Any]],
) -> None:
    with conn.transaction():
        _insert(conn, "merchant", merchants)
        _insert(conn, "fleet_customer", fleet_customers)
        _insert(conn, "account", accounts)
        _insert(conn, "card", cards)
        _insert(conn, "txn", txns)
        _insert(conn, "settlement", settlements)
        _insert(conn, "underwriting_decision", decisions)
        _insert(conn, "risk_score", risk_scores)
        _insert(conn, "dispute", disputes)
        _insert(conn, "partner", partners)
