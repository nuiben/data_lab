"""Lambda step 1: export Postgres tables to Parquet on S3.

Trigger: Step Functions task (see infra/state_machines/pipeline.asl.json)
Output: {"status": "ok", "bucket": str, "keys": list[str]}
"""

from __future__ import annotations

import os

import structlog

from data_lab.export.reader import read_all
from data_lab.export.uploader import upload_all
from data_lab.seed.loader import get_connection
from data_lab.utils.logging import configure_logging

log = structlog.get_logger(__name__)


def handler(event: dict, context: object) -> dict:
    configure_logging()
    bucket = os.environ["DATA_LAB_S3_BUCKET"]
    log.info("export_step.start", bucket=bucket)

    conn = get_connection()
    frames = read_all(conn)
    conn.close()

    keys = upload_all(bucket, frames)
    log.info("export_step.done", tables=len(keys))

    return {"status": "ok", "bucket": bucket, "keys": keys}
