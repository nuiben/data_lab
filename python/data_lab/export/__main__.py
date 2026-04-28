"""Entry point: python -m data_lab.export"""

from __future__ import annotations

import os

import structlog
from dotenv import load_dotenv

from data_lab.export.reader import read_all
from data_lab.export.uploader import upload_all
from data_lab.seed.loader import get_connection
from data_lab.utils.logging import configure_logging

log = structlog.get_logger(__name__)


def main() -> None:
    load_dotenv()
    configure_logging()

    bucket = os.environ.get("DATA_LAB_S3_BUCKET", "")
    if not bucket:
        raise SystemExit("DATA_LAB_S3_BUCKET is not set in the environment.")

    log.info("export.start", bucket=bucket)

    conn = get_connection()
    frames = read_all(conn)
    conn.close()

    keys = upload_all(bucket, frames)

    for table, key in keys.items():
        log.info("export.uploaded", table=table, key=key)

    log.info("export.done", tables=len(keys))


if __name__ == "__main__":
    main()
