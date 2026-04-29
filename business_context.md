# XMOB & Co. — Business Context

> **Purpose of this document.** This is the canonical business context for the Datalab project. All synthetic data, schema designs, and analytical artifacts in this repo should reference XMOB as if it were a real company. AI assistants working in this repo should treat this document as authoritative ground truth for domain decisions: when generating sample data, drafting requirements, or proposing schema changes, align with the entities, processes, and vocabulary defined here.

---

## 1. Company Overview

**XMOB & Co., Inc.** (NYSE: XMOB) is a publicly traded mid-cap fintech headquartered in Charlotte, North Carolina, with secondary offices in Atlanta, Dallas, and Denver. Founded in 2008 by two former regional bank executives, XMOB survived the financial crisis by pivoting from straight commercial lending into a diversified payments and risk-services platform.

| Field | Value |
|---|---|
| Founded | 2008 |
| Headquarters | Charlotte, NC |
| Employees | ~2,400 |
| Revenue (FY2025) | $1.34B |
| Customers | ~58,000 active commercial accounts |
| Ticker | XMOB (NYSE) |
| Regulators | OCC, FinCEN, state DFS agencies, PCI-DSS, SOC 2 Type II |

**Mission statement (official):** "To make the movement of money simpler, safer, and smarter for the businesses that keep America moving."

**Mission statement (how engineers describe it):** "We process payments and underwrite risk for trucking companies, mostly."

---

## 2. History & Origin Story

XMOB was founded by **Robert "Bob" Halpern** (former SVP at a regional bank in the Southeast) and **Diane Marwick** (former commercial credit officer). The founding thesis was that mid-market commercial customers — particularly fleet operators, regional logistics companies, and B2B distributors — were underserved by both megabanks and consumer-focused fintechs.

The "we survived '08 by being scrappy" narrative is now corporate mythology, invoked at every all-hands and quarterly earnings call. Newer engineers tend to roll their eyes at this; long-tenured employees genuinely believe it.

**Key milestones:**

- **2008** — Founded as XMOB Commercial Solutions; original product was a B2B payment processing platform.
- **2011** — Acquired SouthState Card Services, gaining the fleet card business (now ~30% of revenue).
- **2014** — Launched Risk Analytics division; first proprietary underwriting model (M-Score v1) goes live.
- **2017** — IPO on NYSE; raised $410M.
- **2020** — Acquired NorthRail Data, a logistics analytics startup, to enhance fleet telematics integration. Integration is still considered "ongoing" five years later.
- **2022** — Launched XMOB Connect, an API platform for embedded finance partners.
- **2024** — Rolled out M-Score v4, the current production underwriting model. Replaced legacy on-prem risk engine with a cloud-native pipeline (Snowflake + AWS).
- **2025** — Announced Datalab initiative to consolidate analytics tooling and build a unified semantic layer.

---

## 3. Business Lines

XMOB operates three reportable business segments. Each has its own P&L, leadership, and technology stack — which is the source of much of the data integration pain that the Datalab project is meant to address.

### 3.1 Payments & Settlement (P&S)

B2B payment processing, ACH origination, wire transfers, and merchant acquiring services. High volume, low margin, latency-sensitive.

- **Customers:** ~38,000 commercial merchants and corporate originators.
- **Volume:** ~$240B in annual processed volume.
- **Key systems:** PaymentCore (in-house, Java/Kotlin), AcquireNet (legacy Cobol-on-mainframe, partially wrapped in REST APIs), several third-party processor integrations.
- **Data domain owners:** P&S Data Platform team.

### 3.2 Fleet & Commercial Cards (FCC)

Fuel cards, fleet management cards, and expense-control cards primarily serving the trucking, logistics, and commercial services industries. This is the highest-margin business line and XMOB's most differentiated product.

- **Customers:** ~14,000 fleet operators, totaling ~480,000 active cards.
- **Volume:** ~$18B in annual card volume.
- **Key systems:** FleetOne (card management platform, originally from the SouthState acquisition, modernized in 2019), MCC enrichment service, fraud rules engine (Drools-based, increasingly seen as a liability), telematics ingestion pipeline (NorthRail-era, partially integrated).
- **Data domain owners:** FCC Analytics team.

### 3.3 Risk & Underwriting Services (RUS)

Proprietary credit risk modeling, merchant underwriting, portfolio monitoring, and risk-as-a-service offerings sold both internally and to external financial institution partners. Parallel in spirit to actuarial functions in insurance: lots of model governance, regulatory scrutiny, and tension between data scientists and traditional credit officers.

- **Customers:** Internal (every XMOB merchant/fleet customer is scored), plus ~140 external FI partners.
- **Volume:** ~3.2M underwriting decisions per year; ~58,000 portfolio accounts continuously monitored.
- **Key systems:** M-Score v4 (current model, Python + Snowflake), legacy M-Score v2 (still running for grandfathered portfolios), Risk Data Mart (Snowflake), Model Governance Hub (in-house).
- **Data domain owners:** Risk Engineering and Risk Analytics teams.

---

## 4. Org Structure

XMOB's executive team:

- **CEO** — Bob Halpern (co-founder, still active despite years of "succession planning" talk)
- **President & COO** — Diane Marwick (co-founder)
- **CFO** — Lena Okonkwo (joined 2019 from a Big Four)
- **Chief Risk Officer** — Marcus Chen (joined 2021; champion of the M-Score v4 rebuild)
- **Chief Technology Officer** — Priya Ramaswamy (joined 2022; visible advocate of the Datalab initiative)
- **Chief Data Officer** — Tom Bradley (joined 2023; the role is new and his mandate is contested)
- **General Counsel** — Howard Vance

**Datalab-relevant org structure (under the CTO and CDO):**

```
CTO — Priya Ramaswamy
├── VP Engineering, P&S — Raj Patel
├── VP Engineering, FCC — Sandra Liu
├── VP Engineering, RUS — Ahmed Khalil
├── VP Platform Engineering — Joel Friedman
└── VP Infrastructure & Security — Karen Boyd

CDO — Tom Bradley
├── Director, Datalab (new) — Jenna Park
├── Director, BI & Analytics — Mike Donnelly
├── Director, Data Governance — Aisha Robinson
└── Director, ML Platform — vacant (open req since Q1 2025)
```

The friction point worth documenting: **Datalab reports into the CDO**, but most of the data engineering talent and infrastructure ownership lives under the CTO. Cross-org dependencies are constant and political.

---

## 5. Key Personas

These personas are referenced throughout the Datalab repo for user-story writing, requirements docs, and synthetic-data generation.

### 5.1 Internal personas

**Jenna Park** — Director of Datalab. Hired in late 2024 specifically to lead this initiative. Former data platform lead at a larger fintech. Pragmatic, technical, navigating significant political headwinds.

**Mike Donnelly** — Director of BI & Analytics. Twelve-year XMOB veteran. Owns most existing reporting. Skeptical of Datalab; not openly hostile but quietly defensive of his team's existing Tableau footprint.

**Carla Reyes** — Senior Risk Analyst (RUS). Power user of the existing risk data mart. Vocal about data quality issues, especially around the v2/v4 model coexistence. Ideal early Datalab customer.

**Derek Mwangi** — Staff Data Engineer (Datalab team). The technical lead implementing the hybrid AWS + Snowflake architecture. Strong opinions about dbt, semantic layers, and naming conventions.

**Tasha Boone** — VP of Fleet Operations (Customer-facing leadership). Cares about MCC code accuracy, fraud false-positive rates, and the latency of card authorization decisions.

**Henry Latham** — Senior Credit Officer (RUS). Represents the traditional underwriting perspective. Skeptical of model-driven decisions; wants explanations he can defend to regulators.

### 5.2 External personas (XMOB's customers)

**Apex Logistics LLC** (large fleet customer): 2,400-truck regional carrier. Uses XMOB fleet cards across all drivers. High volume, demands rich telematics integration and granular spend controls.

**Gulfstream Distributors** (mid-market merchant): Wholesale distributor processing ~$80M/year in B2B payments. Standard ACH/wire customer with occasional fraud disputes.

**First Heritage Bank** (FI partner): Regional bank licensing M-Score for their own commercial underwriting. Demands SOC 2 evidence on every contract renewal.

---

## 6. Data Domains

These are the core data domains the Datalab project will model. Names and conventions here should be treated as authoritative.

### 6.1 Core entities

| Entity | Description | Source system(s) |
|---|---|---|
| `merchant` | A commercial entity that accepts payments through XMOB | PaymentCore, AcquireNet |
| `fleet_customer` | A commercial entity holding a fleet card program | FleetOne |
| `account` | A funding/settlement account associated with a customer | PaymentCore, FleetOne |
| `card` | An individual issued card (fleet, fuel, or expense) | FleetOne |
| `transaction` | A payment or card transaction event | PaymentCore, FleetOne, AcquireNet |
| `settlement` | A batched movement of funds | PaymentCore |
| `underwriting_decision` | A point-in-time risk decision for a customer | M-Score v4, M-Score v2 |
| `risk_score` | A continuous risk metric, refreshed daily | M-Score v4 |
| `dispute` | A chargeback, fraud claim, or merchant dispute | PaymentCore, FleetOne |
| `partner` | An external FI or platform consuming XMOB APIs | XMOB Connect |

### 6.2 Reference data

| Entity | Description |
|---|---|
| `mcc_code` | Merchant category codes (ISO 18245) with XMOB-specific groupings |
| `geography` | ZIP, MSA, state, region (with XMOB's custom "service region" overlay) |
| `industry_segment` | XMOB's internal NAICS rollup |
| `product_catalog` | XMOB SKUs (cards, payment products, risk services) |
| `model_version` | Registry of underwriting model versions and effective dates |

### 6.3 Known data quality issues (real-world texture)

- **Customer ID collision**: P&S and FCC each have their own customer master. ~12% of customers exist in both with different IDs and no canonical mapping yet. The Datalab `dim_customer` will need to reconcile this.
- **MCC drift**: Acquired MCC codes are sometimes stale or misclassified, especially for fuel-adjacent merchants. The FCC team maintains an override table.
- **M-Score v2/v4 coexistence**: ~8% of accounts are still scored by v2 due to grandfathering. Reports must clearly distinguish.
- **Timezone handling**: AcquireNet emits transactions in Eastern time without TZ markers; PaymentCore uses UTC. This has caused at least three production incidents.
- **Settlement date semantics**: "Settlement date" means different things in P&S (T+1 ACH effective date) vs. FCC (T+2 funding date). The semantic layer must disambiguate.

---

## 7. Glossary

| Term | Definition |
|---|---|
| **ACH** | Automated Clearing House — batch electronic funds transfer network |
| **AcquireNet** | Legacy mainframe acquiring platform; partially wrapped in REST APIs |
| **Authorization** | Real-time approval check on a card transaction (precedes settlement) |
| **BIN** | Bank Identification Number — first 6–8 digits of a card |
| **Chargeback** | Forced reversal of a card transaction initiated by the cardholder's issuer |
| **Datalab** | The internal initiative to build a unified analytics platform |
| **Decision (underwriting)** | A point-in-time approve/decline/refer outcome from M-Score |
| **Dispute** | Umbrella term for chargebacks, fraud claims, and merchant-initiated disputes |
| **Effective date** | The date a financial movement is considered to have occurred |
| **Embedded finance** | XMOB Connect's offering: white-label payments/risk APIs for partners |
| **FCC** | Fleet & Commercial Cards business segment |
| **Fleet card** | A commercial card with built-in spend controls (often fuel-restricted) |
| **FleetOne** | The card management platform; FCC's system of record |
| **Fraud rules engine** | Drools-based rules system for real-time fraud screening |
| **Funding date** | The date funds actually move into the customer's account |
| **MCC** | Merchant Category Code — ISO 18245 four-digit merchant classifier |
| **MCC override** | XMOB-internal MCC reassignment, maintained by FCC ops |
| **Merchant** | A commercial entity accepting payments through XMOB |
| **XMOB Connect** | API platform for embedded finance partners |
| **Model governance** | The framework for approving, monitoring, and retiring risk models |
| **M-Score** | XMOB's proprietary risk score; v4 is current, v2 is grandfathered |
| **NorthRail** | Acquired logistics analytics platform; powers telematics ingestion |
| **Originator** | An entity initiating an ACH credit or debit |
| **P&S** | Payments & Settlement business segment |
| **PaymentCore** | The modern in-house payments platform; P&S's primary system of record |
| **Portfolio monitoring** | Ongoing risk score refresh on existing accounts (vs. point-in-time underwriting) |
| **Refer (decision)** | Underwriting outcome that requires manual credit officer review |
| **RUS** | Risk & Underwriting Services business segment |
| **Settlement** | The batched movement of funds following authorized transactions |
| **Service region** | XMOB's custom geographic overlay (does not map cleanly to MSA) |
| **SouthState** | The card services company acquired in 2011; FleetOne origin |
| **T+1 / T+2** | Settlement convention: funds move 1 (or 2) business days after transaction |
| **Telematics** | Vehicle-derived data (location, fuel level, odometer) ingested for fleet customers |

---

## 8. How AI assistants should use this document

When generating code, schemas, requirements, or sample data in this repo:

1. **Use XMOB-specific names.** Refer to PaymentCore, FleetOne, M-Score, etc., not generic "the payments system." This builds repo-wide consistency.
2. **Respect the three-business-line structure.** When asked to generate sample customers or transactions, distribute across P&S, FCC, and RUS in proportions roughly matching the volume figures in §3.
3. **Honor the documented data quality issues.** Synthetic data should *include* the known messes (customer ID collisions, MCC drift, M-Score v2/v4 coexistence, timezone inconsistencies). That's the whole point of a realistic Datalab — clean data wouldn't exercise the pipeline.
4. **Use the glossary terms consistently.** Don't invent new vocabulary when an established term exists.
5. **Stay grounded in the personas.** When writing user stories, attribute them to a named persona from §5.
6. **Treat regulatory framing as real.** SOC 2, PCI-DSS, OCC oversight, model governance — these aren't decoration. They should shape requirements like access controls, audit logging, and lineage.

This is a living document. Extend it (don't contradict it) when new domains, personas, or systems are introduced.
