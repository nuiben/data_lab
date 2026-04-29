"""Pure generation functions — no I/O, fully deterministic given a random seed."""

from __future__ import annotations

import random
import uuid
from datetime import date, timedelta
from typing import Any

from faker import Faker

TODAY = date.today()
_LOOKBACK_DAYS = 730

_SIC_INDUSTRIES: list[tuple[str, str]] = [
    ("2000", "Manufacturing"),
    ("4200", "Logistics"),
    ("5000", "Retail"),
    ("5140", "Food & Beverage"),
    ("6020", "Fintech"),
    ("7000", "Healthcare"),
    ("7372", "Software"),
    ("8000", "Business Services"),
]

_PRODUCT_IDS = ["RCA", "BLF", "KPRC", "ODC", "DCR", "ECA", "TEC", "WTR"]

_CONVERSION_RATES: dict[str, float] = {
    "RCA": 0.35,
    "BLF": 0.35,
    "KPRC": 0.28,
    "ECA": 0.25,
    "ODC": 0.22,
    "DCR": 0.22,
    "TEC": 0.18,
    "WTR": 0.18,
}

_SEAT_COUNTS: dict[str, tuple[int, int]] = {
    "Micro": (5, 25),
    "SMB": (15, 100),
    "Mid-Market": (100, 500),
}

_SEAT_RATE: dict[str, tuple[int, int]] = {
    "Micro": (200, 500),
    "SMB": (150, 400),
    "Mid-Market": (100, 250),
}

_PRODUCT_RATE_MULT: dict[str, float] = {
    "RCA": 1.0,
    "BLF": 1.0,
    "KPRC": 1.2,
    "ECA": 1.2,
    "ODC": 1.1,
    "WTR": 1.1,
    "TEC": 1.5,
    "DCR": 1.5,
}

_RISK_MULT: dict[str, float] = {
    "Preferred": 0.90,
    "Standard": 1.00,
    "Elevated": 1.15,
    "Watch": 1.35,
}

_RETENTION_BY_CLASS: dict[str, float] = {
    "Preferred": 0.88,
    "Standard": 0.74,
    "Elevated": 0.58,
    "Watch": 0.38,
}

_COC_WEIGHTS = {
    "cash_flow": 0.25,
    "customer": 0.20,
    "volatility": 0.20,
    "leverage": 0.15,
    "succession": 0.10,
    "regulatory": 0.10,
}


def _clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))


def _coc_score(
    cf_conc: float,
    cust_conc: float,
    volatility: float,
    leverage: float,
    succession: bool,
    reg_score: float,
) -> float:
    return (
        cf_conc * _COC_WEIGHTS["cash_flow"]
        + cust_conc * _COC_WEIGHTS["customer"]
        + (volatility / 10.0) * _COC_WEIGHTS["volatility"]
        + _clamp(leverage / 8.0, 0.0, 1.0) * _COC_WEIGHTS["leverage"]
        + (1.0 if succession else 0.0) * _COC_WEIGHTS["succession"]
        + reg_score * _COC_WEIGHTS["regulatory"]
    )


def _risk_class(score: float) -> str:
    if score < 0.30:
        return "Preferred"
    if score < 0.55:
        return "Standard"
    if score < 0.75:
        return "Elevated"
    return "Watch"


def generate_clients(n: int, fake: Faker) -> list[dict[str, Any]]:
    size_bands: list[str] = random.choices(
        ["Micro", "SMB", "Mid-Market"], weights=[0.40, 0.45, 0.15], k=n
    )
    clients: list[dict[str, Any]] = []
    for size_band in size_bands:
        sic_code, industry = random.choice(_SIC_INDUSTRIES)
        clients.append(
            {
                "client_id": str(uuid.uuid4()),
                "company_name": fake.company(),
                "ein": f"{random.randint(10, 99)}-{random.randint(1_000_000, 9_999_999)}",
                "sic_code": sic_code,
                "industry": industry,
                "size_band": size_band,
                "state_abbr": fake.state_abbr(),
            }
        )
    return clients


def generate_coc_signals(clients: list[dict[str, Any]]) -> list[dict[str, Any]]:
    signals: list[dict[str, Any]] = []
    for client in clients:
        for _ in range(random.randint(1, 3)):
            opp_date = TODAY - timedelta(days=random.randint(30, _LOOKBACK_DAYS))
            cf_conc = round(_clamp(random.gauss(0.45, 0.15), 0.05, 0.95), 4)
            cust_conc = round(_clamp(random.gauss(0.30, 0.20), 0.05, 0.95), 4)
            volatility = round(random.uniform(1.0, 10.0), 2)
            leverage = round(_clamp(random.gauss(2.5, 1.2), 0.1, 8.0), 2)
            succession = random.random() < (0.30 if client["size_band"] != "Mid-Market" else 0.15)
            reg_score = round(random.uniform(0.0, 1.0), 3)

            score = round(
                _coc_score(cf_conc, cust_conc, volatility, leverage, succession, reg_score), 4
            )
            signals.append(
                {
                    "signal_id": str(uuid.uuid4()),
                    "client_id": client["client_id"],
                    "opportunity_date": opp_date,
                    "cash_flow_concentration_pct": cf_conc,
                    "customer_concentration_pct": cust_conc,
                    "industry_volatility_index": volatility,
                    "leverage_ratio": leverage,
                    "owner_succession_risk": succession,
                    "regulatory_exposure_score": reg_score,
                    "coc_score": score,
                    "risk_class": _risk_class(score),
                    "opportunity_status": random.choices(
                        ["Closed-Won", "Closed-Lost", "Qualified", "Open"],
                        weights=[0.28, 0.50, 0.12, 0.10],
                    )[0],
                }
            )
    return signals


def generate_quotes(
    signals: list[dict[str, Any]],
    clients_by_id: dict[str, dict[str, Any]],
) -> list[dict[str, Any]]:
    quotes: list[dict[str, Any]] = []
    for signal in signals:
        if signal["opportunity_status"] not in ("Closed-Won", "Qualified"):
            continue
        client = clients_by_id[signal["client_id"]]
        opp_date: date = signal["opportunity_date"]
        quote_date = opp_date + timedelta(days=random.randint(1, 7))
        expires_at = quote_date + timedelta(days=30)

        products = random.sample(_PRODUCT_IDS, random.randint(1, 4))
        for product_id in products:
            seat_lo, seat_hi = _SEAT_COUNTS[client["size_band"]]
            rate_lo, rate_hi = _SEAT_RATE[client["size_band"]]
            seats = random.randint(seat_lo, seat_hi)
            acv = round(
                seats
                * random.uniform(rate_lo, rate_hi)
                * _PRODUCT_RATE_MULT[product_id]
                * _RISK_MULT[signal["risk_class"]],
                2,
            )
            status = (
                "Quoted"
                if expires_at >= TODAY
                else random.choices(["Expired", "Declined"], weights=[0.7, 0.3])[0]
            )
            quotes.append(
                {
                    "quote_id": str(uuid.uuid4()),
                    "signal_id": signal["signal_id"],
                    "client_id": signal["client_id"],
                    "product_id": product_id,
                    "quote_date": quote_date,
                    "seats": seats,
                    "annual_contract_value": acv,
                    "status": status,
                    "expires_at": expires_at,
                    # internal — used in generate_policies, not persisted
                    "_risk_class": signal["risk_class"],
                }
            )
    return quotes


def generate_policies(quotes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    policies: list[dict[str, Any]] = []
    for quote in quotes:
        if random.random() >= _CONVERSION_RATES[quote["product_id"]]:
            continue
        quote_date: date = quote["quote_date"]
        effective = quote_date + timedelta(days=random.randint(1, 14))
        expiration = effective + timedelta(days=365)
        if expiration >= TODAY:
            status = "Active"
        else:
            status = random.choices(["Lapsed", "Cancelled"], weights=[0.85, 0.15])[0]
        policies.append(
            {
                "policy_id": str(uuid.uuid4()),
                "quote_id": quote["quote_id"],
                "client_id": quote["client_id"],
                "product_id": quote["product_id"],
                "effective_date": effective,
                "expiration_date": expiration,
                "annual_contract_value": quote["annual_contract_value"],
                "seats": quote["seats"],
                "status": status,
                # internal — used in generate_renewals, not persisted
                "_risk_class": quote["_risk_class"],
            }
        )
    return policies


def generate_renewals(policies: list[dict[str, Any]]) -> list[dict[str, Any]]:
    renewals: list[dict[str, Any]] = []
    for policy in policies:
        expiration: date = policy["expiration_date"]
        if expiration >= TODAY:
            continue
        risk_class: str = policy.get("_risk_class", "Standard")
        retention_rate = _RETENTION_BY_CLASS.get(risk_class, 0.72)
        retained = random.random() < retention_rate
        rate_change = round(random.gauss(0.03, 0.04), 4)
        prior_acv: float = policy["annual_contract_value"]

        if retained:
            new_acv = round(prior_acv * (1 + rate_change), 2)
            status = "Retained" if abs(rate_change) < 0.02 else "Repriced"
        else:
            new_acv = None
            rate_change = None  # type: ignore[assignment]
            status = "Churned"

        renewals.append(
            {
                "renewal_id": str(uuid.uuid4()),
                "policy_id": policy["policy_id"],
                "renewal_date": expiration + timedelta(days=random.randint(1, 15)),
                "prior_acv": prior_acv,
                "new_acv": new_acv,
                "rate_change_pct": rate_change,
                "status": status,
            }
        )
    return renewals
