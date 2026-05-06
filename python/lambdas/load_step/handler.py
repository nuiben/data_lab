"""Lambda step 2: load S3 Parquet tables into Snowflake.

Trigger: Step Functions task (see infra/state_machines/pipeline.asl.json)
Receives the export step's output under event["export"]:
  {"bucket": str, "keys": {table: s3_key}, "status": str}
Output: {"status": "ok", "tables": int}
"""

from __future__ import annotations

import structlog

from data_lab.export.downloader import download_all
from data_lab.load.snowflake_loader import load_all
from data_lab.utils.logging import configure_logging

log = structlog.get_logger(__name__)


def handler(event: dict, context: object) -> dict:
    configure_logging()
    export = event["export"]
    bucket: str = export["bucket"]
    keys: dict[str, str] = export["keys"]
    log.info("load_step.start", bucket=bucket, tables=list(keys.keys()))

    frames = download_all(bucket, keys)
    load_all(frames)
    log.info("load_step.done", tables=len(frames))

    return {"status": "ok", "tables": len(frames)}
