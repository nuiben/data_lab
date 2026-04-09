# data_lab

A homelab sandbox for experimenting with AWS (S3, Lambda, EventBridge), Snowflake,
and performance-oriented data work in Rust, with Python as the glue layer.

## Repository Layout

```
data_lab/
├── rust/          # Cargo workspace — core types, S3 connector, CLI binary
├── python/        # uv-managed package — connectors, Lambda handlers, notebooks
├── infra/         # Terraform — S3 bucket, Lambda + EventBridge schedule
├── data/          # Reference schemas (SQL) and seed data (CSV)
└── docs/          # Architecture notes, runbooks
```

## Prerequisites

| Tool        | Install                                                    | Purpose              |
|-------------|------------------------------------------------------------|----------------------|
| Rust        | `rustup`                                                   | Cargo workspace      |
| uv          | `curl -LsSf https://astral.sh/uv/install.sh \| sh`        | Python env           |
| just        | `cargo install just`                                       | Task runner          |
| AWS CLI     | `brew install awscli`                                      | Local AWS auth       |

## Quick Start

```bash
cp .env.example .env          # fill in your credentials
just py-install               # install Python deps
just rust-build               # compile Rust workspace
just test                     # run all tests
just aws-bucket-create        # provision sandbox S3 bucket (see infra/README.md)
```

## Environment Variables

See `.env.example` for all required variables. Never commit `.env`.
