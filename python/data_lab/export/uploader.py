"""Serialize DataFrames to Parquet in-memory and upload to S3."""

from __future__ import annotations

import io
from datetime import date

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import structlog

from data_lab.connectors.s3 import get_client

log = structlog.get_logger(__name__)

_EXPORTED_AT = date.today().isoformat()


def _s3_key(table: str) -> str:
    return f"fintech/{table}/exported_at={_EXPORTED_AT}/{table}.parquet"


def upload_table(bucket: str, table: str, df: pd.DataFrame) -> str:
    """Serialize *df* to Parquet and upload to *bucket*. Returns the S3 key."""
    arrow_table = pa.Table.from_pandas(df, preserve_index=False)
    buf = io.BytesIO()
    pq.write_table(arrow_table, buf, compression="snappy")
    buf.seek(0)

    key = _s3_key(table)
    client = get_client()
    client.upload_fileobj(buf, bucket, key)
    log.info("uploader.upload", table=table, bucket=bucket, key=key, rows=len(df))
    return key


def upload_all(bucket: str, frames: dict[str, pd.DataFrame]) -> dict[str, str]:
    """Upload all tables; returns {table: s3_key}."""
    return {table: upload_table(bucket, table, df) for table, df in frames.items()}
