"""Entry point: python -m data_lab.seed [--merchants N] [--customers N] [--seed S]"""

from __future__ import annotations

import argparse
import random

import structlog
from dotenv import load_dotenv
from faker import Faker

from data_lab.seed.generators import (
    generate_accounts,
    generate_cards,
    generate_disputes,
    generate_fleet_customers,
    generate_merchants,
    generate_partners,
    generate_risk_scores,
    generate_settlements,
    generate_txns,
    generate_underwriting_decisions,
)
from data_lab.seed.loader import get_connection, load_all
from data_lab.utils.logging import configure_logging

log = structlog.get_logger(__name__)


def main() -> None:
    load_dotenv()
    configure_logging()

    parser = argparse.ArgumentParser(description="Generate and load XMOB seed data.")
    parser.add_argument(
        "--merchants",
        type=int,
        default=120,
        metavar="N",
        help="Number of P&S merchants (default: 120)",
    )
    parser.add_argument(
        "--customers",
        type=int,
        default=80,
        metavar="N",
        help="Number of FCC fleet customers (default: 80)",
    )
    parser.add_argument(
        "--partners",
        type=int,
        default=20,
        metavar="N",
        help="Number of XMOB Connect partners (default: 20)",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        metavar="S",
        help="Random seed for reproducibility (default: 42)",
    )
    args = parser.parse_args()

    random.seed(args.seed)
    fake = Faker()
    Faker.seed(args.seed)

    log.info("seed.start", merchants=args.merchants, customers=args.customers, seed=args.seed)

    merchants = generate_merchants(args.merchants, fake)

    # ~12% of fleet customers share a company name with a merchant (no ID link exists)
    n_collisions = max(1, round(args.customers * 0.12))
    collision_merchants = random.sample(merchants, min(n_collisions, len(merchants)))
    fleet_customers = generate_fleet_customers(args.customers, fake, collision_merchants)

    accounts = generate_accounts(merchants, fleet_customers)
    accounts_by_customer = {a["customer_id"]: a for a in accounts if a["customer_id"]}

    cards = generate_cards(fleet_customers, accounts_by_customer, fake)
    cards_by_account: dict[str, list] = {}
    for c in cards:
        cards_by_account.setdefault(c["account_id"], []).append(c)

    txns = generate_txns(accounts, cards_by_account, {m["merchant_id"]: m for m in merchants})
    settlements = generate_settlements(accounts)
    decisions = generate_underwriting_decisions(merchants, fleet_customers)
    risk_scores = generate_risk_scores(merchants, fleet_customers)
    disputes = generate_disputes(txns)
    partners = generate_partners(args.partners, fake)

    log.info(
        "seed.generated",
        merchants=len(merchants),
        fleet_customers=len(fleet_customers),
        accounts=len(accounts),
        cards=len(cards),
        txns=len(txns),
        settlements=len(settlements),
        decisions=len(decisions),
        risk_scores=len(risk_scores),
        disputes=len(disputes),
        partners=len(partners),
    )

    conn = get_connection()
    load_all(
        conn,
        merchants=merchants,
        fleet_customers=fleet_customers,
        accounts=accounts,
        cards=cards,
        txns=txns,
        settlements=settlements,
        decisions=decisions,
        risk_scores=risk_scores,
        disputes=disputes,
        partners=partners,
    )
    conn.close()

    log.info("seed.done")


if __name__ == "__main__":
    main()
