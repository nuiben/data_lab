# data_lab justfile
# Run `just --list` to see all recipes.

set dotenv-load

# Default: list recipes
default:
    @just --list

# ── Rust ──────────────────────────────────────────────────

# Build all Rust crates
rust-build:
    cd rust && cargo build

# Run Rust tests
rust-test:
    cd rust && cargo test

# Lint Rust (clippy + fmt check)
rust-lint:
    cd rust && cargo clippy --all-targets --all-features -- -D warnings
    cd rust && cargo fmt --check

# Auto-fix Rust formatting
rust-fmt:
    cd rust && cargo fmt

# ── Python ────────────────────────────────────────────────

# Install Python deps with uv
py-install:
    cd python && uv sync --all-extras

# Run Python tests
py-test:
    cd python && uv run pytest

# Lint Python (ruff check + format check)
py-lint:
    cd python && uv run ruff check .
    cd python && uv run ruff format --check .

# Auto-fix Python formatting and imports
py-fmt:
    cd python && uv run ruff check --fix .
    cd python && uv run ruff format .

# Type-check Python
py-typecheck:
    cd python && uv run mypy data_lab/

# ── Combined ──────────────────────────────────────────────

# Run all lints (CI equivalent)
lint: rust-lint py-lint

# Run all tests
test: rust-test py-test

# ── AWS (manual sandbox setup) ────────────────────────────
# These are a lightweight alternative to IaC while infra tooling is TBD.
# Requires: AWS_PROFILE and DATA_LAB_S3_BUCKET set in .env

# Create the S3 bucket (versioning + encryption enabled)
aws-bucket-create:
    aws s3api create-bucket \
        --bucket "$DATA_LAB_S3_BUCKET" \
        --region "${AWS_REGION:-us-east-1}" \
        --create-bucket-configuration LocationConstraint="${AWS_REGION:-us-east-1}"
    aws s3api put-bucket-versioning \
        --bucket "$DATA_LAB_S3_BUCKET" \
        --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption \
        --bucket "$DATA_LAB_S3_BUCKET" \
        --server-side-encryption-configuration \
        '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Package the example Lambda into a zip
aws-lambda-package:
    cd python/lambdas/example_trigger && \
        pip install -r requirements.txt -t ./package --quiet && \
        cp handler.py ./package/ && \
        cd package && zip -r ../function.zip . -x "*.pyc" && \
        cd .. && rm -rf package

# Deploy (create or update) the example Lambda
aws-lambda-deploy: aws-lambda-package
    aws lambda create-function \
        --function-name "data-lab-example-trigger" \
        --runtime python3.12 \
        --handler handler.handler \
        --zip-file fileb://python/lambdas/example_trigger/function.zip \
        --role "${LAMBDA_ROLE_ARN}" \
        --environment "Variables={DATA_LAB_S3_BUCKET=$DATA_LAB_S3_BUCKET,LOG_LEVEL=INFO}" \
        2>/dev/null || \
    aws lambda update-function-code \
        --function-name "data-lab-example-trigger" \
        --zip-file fileb://python/lambdas/example_trigger/function.zip

# Invoke the example Lambda and print the response
aws-lambda-invoke:
    aws lambda invoke \
        --function-name "data-lab-example-trigger" \
        --log-type Tail \
        /tmp/lambda_response.json && \
    cat /tmp/lambda_response.json

# Package the export-step Lambda (bundles the data-lab package + handler)
aws-lambda-export-package:
    cd python && \
        pip install . -t lambdas/export_step/package --quiet && \
        cp lambdas/export_step/handler.py lambdas/export_step/package/ && \
        cd lambdas/export_step/package && zip -r ../function.zip . -x "*.pyc" && \
        cd .. && rm -rf package

# Deploy (create or update) the export-step Lambda
aws-lambda-export-deploy: aws-lambda-export-package
    aws lambda create-function \
        --function-name "data-lab-export-step" \
        --runtime python3.12 \
        --handler handler.handler \
        --zip-file fileb://python/lambdas/export_step/function.zip \
        --role "${LAMBDA_ROLE_ARN}" \
        --environment "Variables={DATA_LAB_S3_BUCKET=$DATA_LAB_S3_BUCKET,POSTGRES_HOST=$POSTGRES_HOST,POSTGRES_PORT=$POSTGRES_PORT,POSTGRES_USER=$POSTGRES_USER,POSTGRES_PASSWORD=$POSTGRES_PASSWORD,POSTGRES_DB=$POSTGRES_DB,AWS_REGION=$AWS_REGION}" \
        2>/dev/null || \
    aws lambda update-function-code \
        --function-name "data-lab-export-step" \
        --zip-file fileb://python/lambdas/export_step/function.zip

# Package the load-step Lambda (bundles the data-lab package + handler)
aws-lambda-load-package:
    cd python && \
        pip install . -t lambdas/load_step/package --quiet && \
        cp lambdas/load_step/handler.py lambdas/load_step/package/ && \
        cd lambdas/load_step/package && zip -r ../function.zip . -x "*.pyc" && \
        cd .. && rm -rf package

# Deploy (create or update) the load-step Lambda
aws-lambda-load-deploy: aws-lambda-load-package
    aws lambda create-function \
        --function-name "data-lab-load-step" \
        --runtime python3.12 \
        --handler handler.handler \
        --zip-file fileb://python/lambdas/load_step/function.zip \
        --role "${LAMBDA_ROLE_ARN}" \
        --environment "Variables={DATA_LAB_S3_BUCKET=$DATA_LAB_S3_BUCKET,POSTGRES_HOST=$POSTGRES_HOST,POSTGRES_PORT=$POSTGRES_PORT,POSTGRES_USER=$POSTGRES_USER,POSTGRES_PASSWORD=$POSTGRES_PASSWORD,POSTGRES_DB=$POSTGRES_DB,SNOWFLAKE_ACCOUNT=$SNOWFLAKE_ACCOUNT,SNOWFLAKE_USER=$SNOWFLAKE_USER,SNOWFLAKE_PASSWORD=$SNOWFLAKE_PASSWORD,SNOWFLAKE_WAREHOUSE=$SNOWFLAKE_WAREHOUSE,SNOWFLAKE_DATABASE=$SNOWFLAKE_DATABASE,SNOWFLAKE_SCHEMA=$SNOWFLAKE_SCHEMA,SNOWFLAKE_ROLE=$SNOWFLAKE_ROLE,AWS_REGION=$AWS_REGION}" \
        2>/dev/null || \
    aws lambda update-function-code \
        --function-name "data-lab-load-step" \
        --zip-file fileb://python/lambdas/load_step/function.zip

# Deploy both pipeline Lambdas and the state machine
aws-pipeline-deploy: aws-lambda-export-deploy aws-lambda-load-deploy aws-sfn-deploy

# Deploy (create or update) the Step Functions state machine
aws-sfn-deploy:
    #!/usr/bin/env bash
    set -euo pipefail
    ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    REGION=${AWS_REGION:-us-east-1}
    ARN="arn:aws:states:${REGION}:${ACCOUNT}:stateMachine:data-lab-pipeline"
    aws stepfunctions create-state-machine \
        --name "data-lab-pipeline" \
        --definition file://infra/state_machines/pipeline.asl.json \
        --role-arn "${SFN_ROLE_ARN}" \
        --type STANDARD \
        2>/dev/null || \
    aws stepfunctions update-state-machine \
        --state-machine-arn "${ARN}" \
        --definition file://infra/state_machines/pipeline.asl.json
    echo "State machine: ${ARN}"

# Start a pipeline execution
aws-sfn-start:
    #!/usr/bin/env bash
    set -euo pipefail
    ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    REGION=${AWS_REGION:-us-east-1}
    ARN="arn:aws:states:${REGION}:${ACCOUNT}:stateMachine:data-lab-pipeline"
    aws stepfunctions start-execution \
        --state-machine-arn "${ARN}" \
        --name "run-$(date +%Y%m%d-%H%M%S)"

# List the 5 most recent pipeline executions
aws-sfn-status:
    #!/usr/bin/env bash
    set -euo pipefail
    ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    REGION=${AWS_REGION:-us-east-1}
    ARN="arn:aws:states:${REGION}:${ACCOUNT}:stateMachine:data-lab-pipeline"
    aws stepfunctions list-executions \
        --state-machine-arn "${ARN}" \
        --max-results 5

# ── UI ────────────────────────────────────────────────────

# Install UI dependencies
ui-install:
    cd ui && npm install

# Start the Next.js dev server (http://localhost:3000)
ui-dev:
    cd ui && npm run dev

# Production build
ui-build:
    cd ui && npm run build

# Type-check the UI
ui-typecheck:
    cd ui && npm run typecheck

# ── Seed data ─────────────────────────────────────────────

# Generate and load XMOB seed data into local Postgres
seed m="120" c="80" s="42":
    cd python && uv run python -m data_lab.seed --merchants {{m}} --customers {{c}} --seed {{s}}

# ── Export ────────────────────────────────────────────────

# Export Postgres tables to Parquet and upload to S3
export:
    cd python && uv run python -m data_lab.export

# Load Postgres tables into Snowflake (requires Snowflake credentials in .env)
load-snowflake:
    cd python && uv run python -m data_lab.load

# Show Parquet files exported to S3 (requires AWS credentials)
rust-export-status prefix="fintech/":
    cd rust && cargo run -q --bin data_lab -- export-status --prefix {{prefix}}

# ── Database ──────────────────────────────────────────────

# Start local Postgres + pgAdmin
db-up:
    docker compose up -d

# Stop local Postgres + pgAdmin (data volume preserved)
db-down:
    docker compose down

# Destroy containers and data volume, then restart fresh
db-reset:
    docker compose down -v
    docker compose up -d

# Open a psql shell in the running Postgres container
db-psql:
    docker compose exec postgres psql -U "${POSTGRES_USER:-data_lab}" -d "${POSTGRES_DB:-data_lab}"

# Re-apply schema files against the running Postgres container
db-migrate:
    #!/usr/bin/env bash
    set -euo pipefail
    for f in $(ls data/schemas/postgres/*.sql | sort); do
        echo "Applying $f..."
        docker compose exec -T postgres psql \
            -U "${POSTGRES_USER:-data_lab}" \
            -d "${POSTGRES_DB:-data_lab}" < "$f"
    done

# ── Utilities ─────────────────────────────────────────────

# Wire up .githooks so git uses the committed hooks
install-hooks:
    git config core.hooksPath .githooks
    @echo "Hooks installed."

# Validate .env.example has no real secrets (basic check)
check-env:
    @grep -E '(PASSWORD|SECRET|KEY)\s*=\s*.+' .env.example && echo "WARNING: .env.example may contain real secrets" || echo "env.example looks clean"
