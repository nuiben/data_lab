"""Download Parquet files from S3 back into DataFrames."""

from __future__ import annotations

import io

import pandas as pd
import pyarrow.parquet as pq
import structlog

from data_lab.connectors.s3 import get_client

log = structlog.get_logger(__name__)


def download_table(bucket: str, key: str) -> pd.DataFrame:
    buf = io.BytesIO()
    get_client().download_fileobj(bucket, key, buf)
    buf.seek(0)
    df: pd.DataFrame = pq.read_table(buf).to_pandas()
    log.info("downloader.read", bucket=bucket, key=key, rows=len(df))
    return df


def download_all(bucket: str, keys: dict[str, str]) -> dict[str, pd.DataFrame]:
    """Download each table's Parquet file; keys is {table_name: s3_key}."""
    return {table: download_table(bucket, key) for table, key in keys.items()}
