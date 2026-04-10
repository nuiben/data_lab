# data_lab justfile
# Run `just --list` to see all recipes.

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

# ── Utilities ─────────────────────────────────────────────

# Validate .env.example has no real secrets (basic check)
check-env:
    @grep -E '(PASSWORD|SECRET|KEY)\s*=\s*.+' .env.example && echo "WARNING: .env.example may contain real secrets" || echo "env.example looks clean"
