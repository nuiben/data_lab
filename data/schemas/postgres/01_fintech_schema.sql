-- XMOB & Co. — Operational Data Model (PostgreSQL sandbox)
-- Represents source-of-truth tables from PaymentCore (P&S),
-- FleetOne (FCC), and the Risk Data Mart (RUS) in production.

-- ── Reference / Dimension ──────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS mcc_code (
    mcc             CHAR(4)       PRIMARY KEY,
    description     VARCHAR(128)  NOT NULL,
    xmob_group      VARCHAR(64)   NOT NULL,
    -- Known MCC drift candidates; FCC maintains an override table in production.
    has_override    BOOLEAN       NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS geography (
    zip_code        CHAR(5)       PRIMARY KEY,
    city            VARCHAR(64)   NOT NULL,
    state_abbr      CHAR(2)       NOT NULL,
    msa_name        VARCHAR(128),
    -- XMOB's custom regional overlay; does not map cleanly to MSA boundaries.
    service_region  VARCHAR(32)   NOT NULL
);

CREATE TABLE IF NOT EXISTS industry_segment (
    segment_code    VARCHAR(8)    PRIMARY KEY,
    naics_prefix    CHAR(2)       NOT NULL,
    name            VARCHAR(64)   NOT NULL
);

CREATE TABLE IF NOT EXISTS model_version (
    model_id        VARCHAR(16)   PRIMARY KEY,
    name            VARCHAR(32)   NOT NULL,
    version         VARCHAR(8)    NOT NULL,
    effective_date  DATE          NOT NULL,
    retired_date    DATE,
    is_current      BOOLEAN       NOT NULL DEFAULT FALSE
);

-- ── Core Entities ─────────────────────────────────────────────────────────────

-- P&S domain: commercial merchants accepting XMOB payments.
CREATE TABLE IF NOT EXISTS merchant (
    merchant_id     UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name    VARCHAR(128)  NOT NULL,
    dba_name        VARCHAR(128),
    ein             VARCHAR(10),
    mcc             CHAR(4)       REFERENCES mcc_code(mcc),
    zip_code        CHAR(5)       REFERENCES geography(zip_code),
    segment_code    VARCHAR(8)    REFERENCES industry_segment(segment_code),
    status          VARCHAR(16)   NOT NULL CHECK (status IN ('Active', 'Suspended', 'Closed')),
    onboarded_at    DATE          NOT NULL,
    source_system   VARCHAR(16)   NOT NULL CHECK (source_system IN ('PaymentCore', 'AcquireNet')),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- FCC domain: commercial fleet card customers (FleetOne).
-- Data quality: ~12% of fleet_customers share a company_name with a merchant
-- but have a different customer_id — no canonical cross-system mapping exists.
CREATE TABLE IF NOT EXISTS fleet_customer (
    customer_id     UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name    VARCHAR(128)  NOT NULL,
    dot_number      VARCHAR(12),
    fleet_size      INTEGER       NOT NULL CHECK (fleet_size > 0),
    zip_code        CHAR(5)       REFERENCES geography(zip_code),
    segment_code    VARCHAR(8)    REFERENCES industry_segment(segment_code),
    status          VARCHAR(16)   NOT NULL CHECK (status IN ('Active', 'Suspended', 'Closed')),
    onboarded_at    DATE          NOT NULL,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Funding / settlement accounts; owned by exactly one merchant or fleet customer.
CREATE TABLE IF NOT EXISTS account (
    account_id      UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id     UUID          REFERENCES merchant(merchant_id),
    customer_id     UUID          REFERENCES fleet_customer(customer_id),
    account_type    VARCHAR(16)   NOT NULL CHECK (account_type IN ('Settlement', 'Funding', 'Reserve')),
    routing_number  CHAR(9),
    status          VARCHAR(16)   NOT NULL CHECK (status IN ('Active', 'Frozen', 'Closed')),
    opened_at       DATE          NOT NULL,
    source_system   VARCHAR(16)   NOT NULL CHECK (source_system IN ('PaymentCore', 'AcquireNet', 'FleetOne')),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT account_has_one_owner CHECK (
        (merchant_id IS NOT NULL)::int + (customer_id IS NOT NULL)::int = 1
    )
);

-- Individual issued cards; FCC domain only (FleetOne).
CREATE TABLE IF NOT EXISTS card (
    card_id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id         UUID        NOT NULL REFERENCES fleet_customer(customer_id),
    account_id          UUID        NOT NULL REFERENCES account(account_id),
    card_number_last4   CHAR(4)     NOT NULL,
    card_type           VARCHAR(16) NOT NULL CHECK (card_type IN ('Fuel', 'Fleet', 'Expense')),
    driver_name         VARCHAR(128),
    vehicle_id          VARCHAR(32),
    status              VARCHAR(16) NOT NULL CHECK (status IN ('Active', 'Suspended', 'Cancelled')),
    issued_at           DATE        NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Payment and card transaction events across all three source systems.
-- Data quality: AcquireNet emits timestamps in Eastern time without a TZ marker.
-- Those rows are stored here as if UTC, making them appear 4-5 hours early.
CREATE TABLE IF NOT EXISTS txn (
    transaction_id      UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id          UUID          NOT NULL REFERENCES account(account_id),
    merchant_id         UUID          REFERENCES merchant(merchant_id),
    card_id             UUID          REFERENCES card(card_id),
    amount              NUMERIC(12,2) NOT NULL,
    mcc                 CHAR(4)       REFERENCES mcc_code(mcc),
    transaction_type    VARCHAR(16)   NOT NULL CHECK (transaction_type IN ('Purchase', 'Refund', 'ACH', 'Wire')),
    status              VARCHAR(16)   NOT NULL CHECK (status IN ('Authorized', 'Settled', 'Declined', 'Voided', 'Disputed')),
    transacted_at       TIMESTAMPTZ   NOT NULL,
    source_system       VARCHAR(16)   NOT NULL CHECK (source_system IN ('PaymentCore', 'AcquireNet', 'FleetOne')),
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Batched fund movements following authorized transactions.
-- Data quality: settlement_date = batch_date+1 for PaymentCore (T+1 ACH),
-- but batch_date+2 for FleetOne (T+2 funding). Reports must account for this.
CREATE TABLE IF NOT EXISTS settlement (
    settlement_id       UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id          UUID          NOT NULL REFERENCES account(account_id),
    batch_date          DATE          NOT NULL,
    settlement_date     DATE          NOT NULL,
    gross_amount        NUMERIC(14,2) NOT NULL,
    fee_amount          NUMERIC(10,2) NOT NULL DEFAULT 0,
    net_amount          NUMERIC(14,2) NOT NULL,
    transaction_count   INTEGER       NOT NULL CHECK (transaction_count > 0),
    source_system       VARCHAR(16)   NOT NULL CHECK (source_system IN ('PaymentCore', 'FleetOne')),
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Point-in-time underwriting decisions from M-Score (RUS domain).
-- Data quality: ~8% of decisions reference MSCORE_V2 (grandfathered accounts).
CREATE TABLE IF NOT EXISTS underwriting_decision (
    decision_id     UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id     UUID          REFERENCES merchant(merchant_id),
    customer_id     UUID          REFERENCES fleet_customer(customer_id),
    model_id        VARCHAR(16)   NOT NULL REFERENCES model_version(model_id),
    decision_date   DATE          NOT NULL,
    outcome         VARCHAR(8)    NOT NULL CHECK (outcome IN ('Approve', 'Decline', 'Refer')),
    credit_limit    NUMERIC(12,2),
    score           NUMERIC(6,4)  CHECK (score BETWEEN 0 AND 1),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT decision_has_one_subject CHECK (
        (merchant_id IS NOT NULL)::int + (customer_id IS NOT NULL)::int = 1
    )
);

-- Daily M-Score refreshes for continuously monitored accounts.
CREATE TABLE IF NOT EXISTS risk_score (
    score_id        UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id     UUID          REFERENCES merchant(merchant_id),
    customer_id     UUID          REFERENCES fleet_customer(customer_id),
    model_id        VARCHAR(16)   NOT NULL REFERENCES model_version(model_id),
    score_date      DATE          NOT NULL,
    score           NUMERIC(6,4)  NOT NULL CHECK (score BETWEEN 0 AND 1),
    risk_band       VARCHAR(16)   NOT NULL CHECK (risk_band IN ('Low', 'Moderate', 'High', 'Critical')),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT score_has_one_subject CHECK (
        (merchant_id IS NOT NULL)::int + (customer_id IS NOT NULL)::int = 1
    )
);

-- Chargebacks, fraud claims, and merchant disputes.
CREATE TABLE IF NOT EXISTS dispute (
    dispute_id      UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id  UUID          NOT NULL REFERENCES txn(transaction_id),
    dispute_type    VARCHAR(16)   NOT NULL CHECK (dispute_type IN ('Chargeback', 'Fraud', 'Merchant')),
    amount          NUMERIC(12,2) NOT NULL,
    opened_at       DATE          NOT NULL,
    resolved_at     DATE,
    outcome         VARCHAR(16)   CHECK (outcome IN ('Won', 'Lost', 'Withdrawn')),
    source_system   VARCHAR(16)   NOT NULL,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- External FIs and platforms consuming XMOB Connect APIs.
CREATE TABLE IF NOT EXISTS partner (
    partner_id      UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(128)  NOT NULL,
    partner_type    VARCHAR(16)   NOT NULL CHECK (partner_type IN ('FI', 'Platform', 'Embedded')),
    contract_start  DATE          NOT NULL,
    contract_end    DATE,
    status          VARCHAR(16)   NOT NULL CHECK (status IN ('Active', 'Pending', 'Terminated')),
    soc2_verified   BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_merchant_status       ON merchant (status);
CREATE INDEX IF NOT EXISTS idx_merchant_source       ON merchant (source_system);
CREATE INDEX IF NOT EXISTS idx_fleet_customer_status ON fleet_customer (status);
CREATE INDEX IF NOT EXISTS idx_account_merchant      ON account (merchant_id);
CREATE INDEX IF NOT EXISTS idx_account_customer      ON account (customer_id);
CREATE INDEX IF NOT EXISTS idx_account_source        ON account (source_system);
CREATE INDEX IF NOT EXISTS idx_card_customer         ON card (customer_id);
CREATE INDEX IF NOT EXISTS idx_card_status           ON card (status);
CREATE INDEX IF NOT EXISTS idx_txn_account           ON txn (account_id);
CREATE INDEX IF NOT EXISTS idx_txn_transacted_at     ON txn (transacted_at);
CREATE INDEX IF NOT EXISTS idx_txn_source            ON txn (source_system);
CREATE INDEX IF NOT EXISTS idx_txn_status            ON txn (status);
CREATE INDEX IF NOT EXISTS idx_settlement_account    ON settlement (account_id);
CREATE INDEX IF NOT EXISTS idx_settlement_batch_date ON settlement (batch_date);
CREATE INDEX IF NOT EXISTS idx_decision_merchant     ON underwriting_decision (merchant_id);
CREATE INDEX IF NOT EXISTS idx_decision_customer     ON underwriting_decision (customer_id);
CREATE INDEX IF NOT EXISTS idx_decision_date         ON underwriting_decision (decision_date);
CREATE INDEX IF NOT EXISTS idx_risk_score_merchant   ON risk_score (merchant_id);
CREATE INDEX IF NOT EXISTS idx_risk_score_customer   ON risk_score (customer_id);
CREATE INDEX IF NOT EXISTS idx_risk_score_date       ON risk_score (score_date);
CREATE INDEX IF NOT EXISTS idx_dispute_transaction   ON dispute (transaction_id);
CREATE INDEX IF NOT EXISTS idx_dispute_type          ON dispute (dispute_type);
