"""Entry point: python -m data_lab.seed [--clients N] [--seed S]"""

from __future__ import annotations

import argparse
import random

import structlog
from dotenv import load_dotenv
from faker import Faker

from data_lab.seed.generators import (
    generate_clients,
    generate_coc_signals,
    generate_policies,
    generate_quotes,
    generate_renewals,
)
from data_lab.seed.loader import get_connection, load_all
from data_lab.utils.logging import configure_logging

log = structlog.get_logger(__name__)


def main() -> None:
    load_dotenv()
    configure_logging()

    parser = argparse.ArgumentParser(description="Generate and load fintech seed data.")
    parser.add_argument("--clients", type=int, default=200, metavar="N",
                        help="Number of client companies to generate (default: 200)")
    parser.add_argument("--seed", type=int, default=42, metavar="S",
                        help="Random seed for reproducibility (default: 42)")
    args = parser.parse_args()

    random.seed(args.seed)
    fake = Faker()
    Faker.seed(args.seed)

    log.info("seed.start", clients=args.clients, seed=args.seed)

    clients  = generate_clients(args.clients, fake)
    by_id    = {c["client_id"]: c for c in clients}
    signals  = generate_coc_signals(clients)
    quotes   = generate_quotes(signals, by_id)
    policies = generate_policies(quotes)
    renewals = generate_renewals(policies)

    log.info(
        "seed.generated",
        clients=len(clients),
        signals=len(signals),
        quotes=len(quotes),
        policies=len(policies),
        renewals=len(renewals),
    )

    conn = get_connection()
    load_all(conn, clients, signals, quotes, policies, renewals)
    conn.close()

    log.info("seed.done")


if __name__ == "__main__":
    main()
