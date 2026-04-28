"""Entry point: python -m data_lab.load"""

from __future__ import annotations

import structlog
from dotenv import load_dotenv

from data_lab.export.reader import read_all
from data_lab.load.snowflake_loader import load_all
from data_lab.seed.loader import get_connection
from data_lab.utils.logging import configure_logging

log = structlog.get_logger(__name__)


def main() -> None:
    load_dotenv()
    configure_logging()

    log.info("load.start", destination="snowflake")

    pg_conn = get_connection()
    frames = read_all(pg_conn)
    pg_conn.close()

    load_all(frames)

    log.info("load.done", tables=len(frames))


if __name__ == "__main__":
    main()
