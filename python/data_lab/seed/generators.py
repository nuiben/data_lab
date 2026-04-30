"""Pure generation functions — no I/O, fully deterministic given a random seed."""

from __future__ import annotations

import random
import uuid
from datetime import UTC, date, datetime, timedelta
from typing import Any

from faker import Faker

TODAY = date.today()
_LOOKBACK_DAYS = 730

# Must match 02_seeds.sql
_MCC_CODES = [
    "5541",
    "5542",
    "5172",
    "4215",
    "4231",
    "5013",
    "5561",
    "5599",
    "7538",
    "5411",
    "5812",
    "5511",
    "7514",
    "7521",
    "4111",
    "4812",
    "4911",
    "5065",
    "7372",
    "5999",
]
_OVERRIDE_MCCS = {"5541", "5542", "5172"}  # known MCC drift candidates

_ZIP_CODES = [
    "28201",
    "30301",
    "37201",
    "75201",
    "77001",
    "73101",
    "80201",
    "85001",
    "89101",
    "45201",
    "53201",
    "55401",
    "64101",
    "97201",
    "98101",
]

_SEGMENT_CODES = ["TRK", "LOG", "FLS", "MFG", "RET", "FNB", "SVC", "TEC"]

_MODEL_IDS = ["MSCORE_V2", "MSCORE_V4"]


def _rand_date(days_back_lo: int, days_back_hi: int) -> date:
    return TODAY - timedelta(days=random.randint(days_back_lo, days_back_hi))


def _score_to_band(score: float) -> str:
    if score < 0.25:
        return "Low"
    if score < 0.55:
        return "Moderate"
    if score < 0.80:
        return "High"
    return "Critical"


def _v2_or_v4() -> str:
    return "MSCORE_V2" if random.random() < 0.08 else "MSCORE_V4"


def generate_merchants(n: int, fake: Faker) -> list[dict[str, Any]]:
    """PaymentCore + AcquireNet merchants. ~30% originate from AcquireNet."""
    merchants = []
    for _ in range(n):
        source = random.choices(["PaymentCore", "AcquireNet"], weights=[0.70, 0.30])[0]
        merchants.append(
            {
                "merchant_id": str(uuid.uuid4()),
                "company_name": fake.company(),
                "dba_name": fake.company() if random.random() < 0.25 else None,
                "ein": f"{random.randint(10, 99)}-{random.randint(1_000_000, 9_999_999)}",
                "mcc": random.choice(_MCC_CODES),
                "zip_code": random.choice(_ZIP_CODES),
                "segment_code": random.choice(_SEGMENT_CODES),
                "status": random.choices(
                    ["Active", "Suspended", "Closed"], weights=[0.85, 0.08, 0.07]
                )[0],
                "onboarded_at": _rand_date(180, _LOOKBACK_DAYS),
                "source_system": source,
            }
        )
    return merchants


def generate_fleet_customers(
    n: int,
    fake: Faker,
    collision_merchants: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """FleetOne fleet customers.
    collision_merchants are merchants whose company_name is reused here with a
    new UUID — simulating the ~12% customer ID collision documented in §6.3.
    """
    customers: list[dict[str, Any]] = []
    for m in collision_merchants:
        customers.append(
            {
                "customer_id": str(uuid.uuid4()),
                "company_name": m["company_name"],
                "dot_number": f"DOT{random.randint(100_000, 999_999)}",
                "fleet_size": random.randint(5, 500),
                "zip_code": random.choice(_ZIP_CODES),
                "segment_code": m["segment_code"],
                "status": random.choices(
                    ["Active", "Suspended", "Closed"], weights=[0.88, 0.07, 0.05]
                )[0],
                "onboarded_at": _rand_date(180, _LOOKBACK_DAYS),
            }
        )
    for _ in range(n - len(collision_merchants)):
        customers.append(
            {
                "customer_id": str(uuid.uuid4()),
                "company_name": fake.company(),
                "dot_number": f"DOT{random.randint(100_000, 999_999)}"
                if random.random() < 0.70
                else None,
                "fleet_size": random.randint(5, 2400),
                "zip_code": random.choice(_ZIP_CODES),
                "segment_code": random.choice(_SEGMENT_CODES),
                "status": random.choices(
                    ["Active", "Suspended", "Closed"], weights=[0.88, 0.07, 0.05]
                )[0],
                "onboarded_at": _rand_date(180, _LOOKBACK_DAYS),
            }
        )
    return customers


def generate_accounts(
    merchants: list[dict[str, Any]],
    fleet_customers: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """One account per merchant and per fleet customer."""
    accounts: list[dict[str, Any]] = []
    for m in merchants:
        accounts.append(
            {
                "account_id": str(uuid.uuid4()),
                "merchant_id": m["merchant_id"],
                "customer_id": None,
                "account_type": random.choices(
                    ["Settlement", "Funding", "Reserve"], weights=[0.70, 0.20, 0.10]
                )[0],
                "routing_number": str(random.randint(100_000_000, 999_999_999)),
                "status": "Active"
                if m["status"] == "Active"
                else random.choice(["Frozen", "Closed"]),
                "opened_at": m["onboarded_at"],
                "source_system": m["source_system"],
            }
        )
    for c in fleet_customers:
        accounts.append(
            {
                "account_id": str(uuid.uuid4()),
                "merchant_id": None,
                "customer_id": c["customer_id"],
                "account_type": random.choices(
                    ["Settlement", "Funding", "Reserve"], weights=[0.60, 0.30, 0.10]
                )[0],
                "routing_number": str(random.randint(100_000_000, 999_999_999)),
                "status": "Active"
                if c["status"] == "Active"
                else random.choice(["Frozen", "Closed"]),
                "opened_at": c["onboarded_at"],
                "source_system": "FleetOne",
            }
        )
    return accounts


def generate_cards(
    fleet_customers: list[dict[str, Any]],
    accounts_by_customer: dict[str, dict[str, Any]],
    fake: Faker,
) -> list[dict[str, Any]]:
    """2–20 cards per fleet customer depending on fleet size."""
    cards: list[dict[str, Any]] = []
    for c in fleet_customers:
        acct = accounts_by_customer.get(c["customer_id"])
        if acct is None:
            continue
        n_cards = random.randint(2, min(c["fleet_size"], 20))
        for _ in range(n_cards):
            cards.append(
                {
                    "card_id": str(uuid.uuid4()),
                    "customer_id": c["customer_id"],
                    "account_id": acct["account_id"],
                    "card_number_last4": f"{random.randint(1000, 9999)}",
                    "card_type": random.choices(
                        ["Fuel", "Fleet", "Expense"], weights=[0.60, 0.30, 0.10]
                    )[0],
                    "driver_name": fake.name() if random.random() < 0.80 else None,
                    "vehicle_id": f"VIN{random.randint(10_000, 99_999)}"
                    if random.random() < 0.70
                    else None,
                    "status": random.choices(
                        ["Active", "Suspended", "Cancelled"], weights=[0.85, 0.10, 0.05]
                    )[0],
                    "issued_at": c["onboarded_at"] + timedelta(days=random.randint(0, 30)),
                }
            )
    return cards


def generate_txns(
    accounts: list[dict[str, Any]],
    cards_by_account: dict[str, list[dict[str, Any]]],
    merchants_by_id: dict[str, dict[str, Any]],
) -> list[dict[str, Any]]:
    """Payment and card transactions across all three source systems.

    Data quality injected:
    - AcquireNet rows: transacted_at is Eastern time stored without a TZ offset
      (appears UTC; is actually off by 4-5 hours).
    - MCC drift: ~5% of transactions on override-flagged MCCs use a stale code.
    """
    txns: list[dict[str, Any]] = []
    for acct in accounts:
        if acct["status"] != "Active":
            continue
        source = acct["source_system"]
        merchant_id = acct.get("merchant_id")
        base_mcc = (
            merchants_by_id[merchant_id]["mcc"]
            if merchant_id and merchant_id in merchants_by_id
            else None
        )
        acct_cards = cards_by_account.get(acct["account_id"], [])
        active_cards = [c for c in acct_cards if c["status"] == "Active"]

        for _ in range(random.randint(5, 50)):
            tx_date = _rand_date(1, 180)
            if source == "AcquireNet":
                # Eastern time without TZ marker — stored as if UTC (data quality issue)
                transacted_at = datetime(
                    tx_date.year,
                    tx_date.month,
                    tx_date.day,
                    random.randint(6, 22),
                    random.randint(0, 59),
                    tzinfo=UTC,
                )
            else:
                transacted_at = datetime(
                    tx_date.year,
                    tx_date.month,
                    tx_date.day,
                    random.randint(0, 23),
                    random.randint(0, 59),
                    tzinfo=UTC,
                )

            if base_mcc and base_mcc in _OVERRIDE_MCCS and random.random() < 0.05:
                mcc = random.choice(list(set(_MCC_CODES) - _OVERRIDE_MCCS))
            else:
                mcc = base_mcc or random.choice(_MCC_CODES)

            card_id = (
                random.choice(active_cards)["card_id"]
                if active_cards and source == "FleetOne"
                else None
            )

            if source == "FleetOne":
                tx_type = "Purchase"
                amount = round(random.uniform(50, 5_000), 2)
            elif source == "AcquireNet":
                tx_type = random.choices(["Purchase", "ACH", "Wire"], weights=[0.50, 0.40, 0.10])[0]
                amount = round(random.uniform(500, 50_000), 2)
            else:
                tx_type = random.choices(["Purchase", "ACH", "Wire"], weights=[0.60, 0.30, 0.10])[0]
                amount = round(random.uniform(500, 25_000), 2)

            txns.append(
                {
                    "transaction_id": str(uuid.uuid4()),
                    "account_id": acct["account_id"],
                    "merchant_id": merchant_id,
                    "card_id": card_id,
                    "amount": amount,
                    "mcc": mcc,
                    "transaction_type": tx_type,
                    "status": random.choices(
                        ["Authorized", "Settled", "Declined", "Voided", "Disputed"],
                        weights=[0.05, 0.82, 0.07, 0.03, 0.03],
                    )[0],
                    "transacted_at": transacted_at,
                    "source_system": source,
                }
            )
    return txns


def generate_settlements(accounts: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Batched fund movements.

    Data quality injected:
    - PaymentCore: settlement_date = batch_date + 1 (T+1 ACH).
    - FleetOne:    settlement_date = batch_date + 2 (T+2 funding).
    AcquireNet settles through PaymentCore and has no independent settlement rows.
    """
    settlements: list[dict[str, Any]] = []
    for acct in accounts:
        if acct["status"] != "Active" or acct["source_system"] == "AcquireNet":
            continue
        source = acct["source_system"]
        lag = 1 if source == "PaymentCore" else 2
        for _ in range(random.randint(3, 20)):
            batch_date = _rand_date(2, 90)
            gross = round(random.uniform(5_000, 500_000), 2)
            fee = round(gross * random.uniform(0.005, 0.02), 2)
            settlements.append(
                {
                    "settlement_id": str(uuid.uuid4()),
                    "account_id": acct["account_id"],
                    "batch_date": batch_date,
                    "settlement_date": batch_date + timedelta(days=lag),
                    "gross_amount": gross,
                    "fee_amount": fee,
                    "net_amount": round(gross - fee, 2),
                    "transaction_count": random.randint(5, 200),
                    "source_system": source,
                }
            )
    return settlements


def generate_underwriting_decisions(
    merchants: list[dict[str, Any]],
    fleet_customers: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Initial underwriting decision per entity.

    Data quality injected:
    - ~8% of decisions reference MSCORE_V2 (grandfathered accounts).
    """
    decisions: list[dict[str, Any]] = []

    def _decision(
        merchant_id: str | None,
        customer_id: str | None,
        onboarded_at: date,
    ) -> dict[str, Any]:
        score = round(random.betavariate(2, 5), 4)
        outcome = "Approve" if score < 0.55 else "Refer" if score < 0.75 else "Decline"
        return {
            "decision_id": str(uuid.uuid4()),
            "merchant_id": merchant_id,
            "customer_id": customer_id,
            "model_id": _v2_or_v4(),
            "decision_date": onboarded_at + timedelta(days=random.randint(0, 3)),
            "outcome": outcome,
            "credit_limit": round(random.uniform(10_000, 500_000), 2)
            if outcome == "Approve"
            else None,
            "score": score,
        }

    for m in merchants:
        decisions.append(_decision(m["merchant_id"], None, m["onboarded_at"]))
    for c in fleet_customers:
        decisions.append(_decision(None, c["customer_id"], c["onboarded_at"]))
    return decisions


def generate_risk_scores(
    merchants: list[dict[str, Any]],
    fleet_customers: list[dict[str, Any]],
    n_days: int = 7,
) -> list[dict[str, Any]]:
    """Daily M-Score refreshes for the last n_days for each active entity."""
    scores: list[dict[str, Any]] = []

    def _score_rows(key: str, entity_id: str) -> list[dict[str, Any]]:
        model_id = _v2_or_v4()
        base = round(random.betavariate(2, 5), 4)
        rows = []
        for offset in range(n_days):
            s = round(min(1.0, max(0.0, base + random.gauss(0, 0.01))), 4)
            rows.append(
                {
                    "score_id": str(uuid.uuid4()),
                    "merchant_id": entity_id if key == "merchant_id" else None,
                    "customer_id": entity_id if key == "customer_id" else None,
                    "model_id": model_id,
                    "score_date": TODAY - timedelta(days=offset),
                    "score": s,
                    "risk_band": _score_to_band(s),
                }
            )
        return rows

    for m in merchants:
        if m["status"] == "Active":
            scores.extend(_score_rows("merchant_id", m["merchant_id"]))
    for c in fleet_customers:
        if c["status"] == "Active":
            scores.extend(_score_rows("customer_id", c["customer_id"]))
    return scores


def generate_disputes(txns: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """~3% of Settled transactions generate a dispute."""
    disputes: list[dict[str, Any]] = []
    for tx in txns:
        if tx["status"] not in ("Settled", "Disputed"):
            continue
        if random.random() > 0.03:
            continue
        opened = tx["transacted_at"].date() + timedelta(days=random.randint(1, 30))
        resolved = (
            opened + timedelta(days=random.randint(10, 60)) if random.random() < 0.70 else None
        )
        disputes.append(
            {
                "dispute_id": str(uuid.uuid4()),
                "transaction_id": tx["transaction_id"],
                "dispute_type": random.choices(
                    ["Chargeback", "Fraud", "Merchant"], weights=[0.50, 0.35, 0.15]
                )[0],
                "amount": tx["amount"],
                "opened_at": opened,
                "resolved_at": resolved,
                "outcome": random.choice(["Won", "Lost", "Withdrawn"]) if resolved else None,
                "source_system": tx["source_system"],
            }
        )
    return disputes


def generate_partners(n: int, fake: Faker) -> list[dict[str, Any]]:
    """XMOB Connect external partners (FIs, platforms, embedded finance)."""
    partners: list[dict[str, Any]] = []
    for _ in range(n):
        contract_start = _rand_date(365, _LOOKBACK_DAYS)
        active = random.random() < 0.80
        partners.append(
            {
                "partner_id": str(uuid.uuid4()),
                "name": fake.company(),
                "partner_type": random.choices(
                    ["FI", "Platform", "Embedded"], weights=[0.55, 0.25, 0.20]
                )[0],
                "contract_start": contract_start,
                "contract_end": None
                if active
                else contract_start + timedelta(days=random.randint(180, 730)),
                "status": "Active"
                if active
                else random.choices(["Pending", "Terminated"], weights=[0.30, 0.70])[0],
                "soc2_verified": random.random() < 0.65,
            }
        )
    return partners
