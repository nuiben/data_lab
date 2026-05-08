# CLAUDE.md — data_lab

## Project

Homelab data engineering sandbox built around the fictional **XMOB & Co.** FinTech. Three business lines: Payments & Settlement (P&S), Fleet & Commercial Cards (FCC), Risk & Underwriting (RUS). Full domain model is in `business_context.md`.

## Tech stack

| Layer | Tool | Notes |
|---|---|---|
| Task runner | `just` | Never `make`. Run `just --list` to see all recipes. |
| Python | `uv` | Always `uv run <cmd>`, never bare `python`. Package at `python/`. |
| Rust | Cargo workspace | Three crates: `data_lab_core`, `connectors`, `cli`. |
| Local DB | Docker + Postgres | `just db-up` / `just db-down`. |
| Warehouse | Snowflake | Column names are uppercase in DDL and on the wire. |
| Transform | dbt | Project at `dbt/`. Targets: Snowflake (`dev`/`prod`) and DuckDB (`local`). |
| UI | Next.js 15 | At `ui/`. `just ui-dev` → localhost:3000. |

## Common commands

```bash
just seed                 # generate XMOB data into local Postgres
just export               # Postgres → S3 Parquet
just load-snowflake       # Postgres → Snowflake
just dbt-run              # run all dbt models (Snowflake)
just dbt-seed-local       # pull Postgres → data/local.duckdb
just dbt-local            # run + test dbt against DuckDB (no cloud needed)
just test                 # Rust + Python tests
just lint                 # Rust clippy/fmt + Python ruff/mypy
```

## Code conventions

- **No comments** unless the WHY is non-obvious. Names explain the what.
- **No docstrings** on internal functions.
- Python: `ruff` for lint/format, `mypy` strict mode, line length 100.
- Rust: `clippy --all-targets`, `cargo fmt`.
- Run `just lint` before committing — the pre-commit hook runs it anyway.

## dbt conventions

- **Staging** (`models/staging/stg_*.sql`): views, one per source table, no joins, no business logic. Lowercase enums, normalize types.
- **Marts** (`models/marts/{payments,fleet,risk}/`): tables, named `fct_*` or `dim_*`, all joins and business logic here.
- **Cross-adapter SQL** — never use Snowflake-specific functions directly:
  - Use `{{ convert_timezone('tz_from', 'tz_to', col) }}` not `CONVERT_TIMEZONE()`
  - Use `{{ safe_divide(num, den) }}` not `div0()`
  - Both macros dispatch to the right SQL for Snowflake and DuckDB.
- **Sources** reference `{{ source('fintech_raw', 'TABLE_NAME') }}` (uppercase table names match Snowflake DDL).
- **Mart models** reference `{{ ref('stg_...') }}` — no raw source calls except `MODEL_VERSION` in `fct_underwriting_decisions`.

## XMOB data quality issues

These are intentionally baked into the seed data. They affect how you write queries and models:

| Issue | Where | Impact |
|---|---|---|
| AcquireNet timestamps are US/Eastern; PaymentCore is UTC | `TXN.TRANSACTED_AT` | Always use the `convert_timezone` macro in `stg_txn` — never raw timestamps in marts |
| ~12% customer ID collision between P&S and FCC | `ACCOUNT.CUSTOMER_ID` vs `FLEET_CUSTOMER.CUSTOMER_ID` | Never join on `customer_id` without filtering to a single business line |
| ~8% of underwriting decisions use M-Score v2 | `UNDERWRITING_DECISION.MODEL_ID = 'M-SCORE-V2'` | v2 and v4 score scales differ — always propagate `is_legacy_model` into risk marts |
| FCC overrides MCC codes | `MCC_CODE.HAS_OVERRIDE = true` | Cross-line MCC analysis must check the override flag |
| Settlement lag differs by business line | `SETTLEMENT` | P&S is T+1, FCC is T+3 — don't alert on lag without a business-line filter |

## Agents

Project agents are in `.claude/agents/`. They are specialists — delegate to them when their domain is relevant:

- **derek** — dbt model review, SQL quality, pipeline architecture
- **carla** — data quality, RUS business line, XMOB-specific anomalies
- **jenna** — scoping, prioritization, stakeholder framing
- **jim** — financial controls, settlement reconciliation, revenue recognition, audit trail
- **carl** — FP&A: monthly P&L, volume/fee-rate analysis, earnings reporting
- **dbt-reviewer** — systematic dbt checklist (structure, tests, docs, cross-adapter safety)
- **pipeline-debug** — diagnosing failures in seed/export/load/dbt

## Environment

Credentials live in `.env` (never committed). See `.env.example` for required variables. Snowflake, AWS, and Postgres credentials are all loaded via `set dotenv-load` in the justfile.
