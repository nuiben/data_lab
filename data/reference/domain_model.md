# data_lab Domain Model — Option A: Embedded Business Risk Financing Platform

A B2B FinTech company that assesses risk and originates structured financial agreements for SMBs, distributed through
broker/advisor channels. Risk-linked financial agreements trigger payouts based on
measurable business events — not insurance policies.

---

## Product Translation Table

| Fictional Product (FinTech)            | Code  | Insurance Analog     | Risk Trigger / Description                                      |
|----------------------------------------|-------|----------------------|-----------------------------------------------------------------|
| Revenue Continuity Agreement           | RCA   | LTD                  | Revenue drops >30% for 90+ consecutive days                     |
| Bridge Liquidity Facility              | BLF   | STD                  | Short-term cash flow gap, duration <90 days                     |
| Key Person Retention Contract          | KPRC  | Voluntary Term Life  | C-suite departure or incapacitation event                       |
| Operational Disruption Contract        | ODC   | Hospital Indemnity   | Unplanned operational shutdown (facility, system, etc.)         |
| Dependency Chain Reserve               | DCR   | Dependent Life       | Critical supplier or customer failure                           |
| Enterprise Continuity Agreement        | ECA   | Group Term Life      | Catastrophic business event (acquisition, dissolution, etc.)    |
| Trigger Event Contract                 | TEC   | Critical Illness     | Named event: cyber breach, litigation, regulatory action        |
| Workforce Transition Reserve           | WTR   | PFML                 | Mass workforce event or regulatory mandate                      |

---

## Risk Scoring — Commercial Opportunity Complexity (COC)

Analog to "Sales Enablement Complexity" (SEC) from the insurance model.
CRM-fed actuarial scoring evaluated at the quote stage.

| COC Feature                  | Insurance Analog         | Notes                                              |
|------------------------------|--------------------------|----------------------------------------------------|
| Cash flow concentration      | Tobacco usage %          | % revenue from top cash flow source                |
| Customer concentration       | Alcohol usage %          | % revenue from single customer (flag if >40%)      |
| Industry volatility index    | SIC risk score           | Derived from SIC code + macro cycle data           |
| Leverage ratio               | BMI / health class proxy | Total debt / EBITDA; thresholds drive risk class   |
| Owner succession risk        | Chronic condition flag   | Key-man dependency, no documented succession plan  |
| Regulatory exposure score    | Tobacco state adj.       | Industry-specific regulatory risk (fintech, health)|

### Risk Classes

| Class       | Description                                                  |
|-------------|--------------------------------------------------------------|
| Preferred   | Low COC score — favorable metrics across all features        |
| Standard    | Moderate COC — acceptable risk, standard pricing             |
| Elevated    | High COC in 1-2 features — modified terms or surcharge       |
| Watch       | COC flags in 3+ features — manual underwriter review         |

---

## Funnel Stages

```
Opportunity (CRM) → Quote → Sold/Bound → Active → Renewal → Retained/Churned
```

| Stage      | Table              | Key Status Values                          |
|------------|--------------------|--------------------------------------------|
| Opportunity| fact_coc_signals   | Open, Qualified, Closed-Won, Closed-Lost   |
| Quote      | fact_quotes        | Quoted, Expired, Declined                  |
| Policy     | fact_sold_policies | Active, Lapsed, Cancelled                  |
| Renewal    | fact_renewals      | Pending, Retained, Churned, Repriced       |

---

## Faker Generation Notes

### Client (Employer Group analog)
- `company()` — business name
- `ein()` or fake UUID — client ID
- SIC code: sample from a curated list (manufacturing, healthcare, retail, fintech, logistics)
- Employee count / revenue band: categorical (Micro <10, SMB 10-250, Mid-Market 250-2500)
- State: `state_abbr()`

### Quotes
- 1-4 products per client group per cycle
- Conversion rate to sold: ~25-35% overall, varies by product
  - RCA/BLF: ~35% (high demand)
  - TEC/WTR: ~18% (niche, complex)
- Quote date: spread over trailing 24 months

### COC Signals (per opportunity)
- `cash_flow_concentration_pct`: normal(0.45, 0.15), clamp [0.05, 0.95]
- `customer_concentration_pct`: normal(0.30, 0.20), clamp [0.05, 0.95]
- `industry_volatility_index`: float [1.0, 10.0], seeded by SIC bucket
- `leverage_ratio`: normal(2.5, 1.2), clamp [0.1, 8.0]
- `owner_succession_risk`: bool, ~30% True for micro/SMB
- `regulatory_exposure_score`: float [0.0, 1.0]
- `coc_score`: weighted sum of above → maps to risk class

### Renewals
- Retention rate: ~72% overall
  - Preferred class: ~88%
  - Standard: ~74%
  - Elevated: ~58%
  - Watch: ~38%
- Rate change at renewal: normal(0.03, 0.04) — avg 3% increase

---

## Schema Targets (Snowflake / DuckDB)

```
dim_products            -- product codes, names, descriptions
dim_clients             -- client_id, name, SIC, size_band, state, industry
fact_quotes             -- quote_id, client_id, product_id, quote_date, lives/seats, status
fact_sold_policies      -- policy_id, quote_id, effective_date, annual_contract_value, seats
fact_renewals           -- renewal_id, policy_id, renewal_date, prior_acv, new_acv, retained
fact_coc_signals        -- opportunity_id, all COC features, coc_score, risk_class
```
