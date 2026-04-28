-- Embedded Business Risk Financing Platform — PostgreSQL schema

-- ── Dimensions ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS dim_products (
    product_id  VARCHAR(8)    PRIMARY KEY,
    name        VARCHAR(64)   NOT NULL,
    description TEXT          NOT NULL,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS dim_clients (
    client_id    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name VARCHAR(128)  NOT NULL,
    ein          VARCHAR(10),
    sic_code     VARCHAR(4),
    industry     VARCHAR(64),
    size_band    VARCHAR(16)   NOT NULL CHECK (size_band IN ('Micro', 'SMB', 'Mid-Market')),
    state_abbr   CHAR(2)       NOT NULL,
    created_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ── Facts ─────────────────────────────────────────────────────────────────────

-- One row per CRM opportunity; drives risk class and feeds fact_quotes.
CREATE TABLE IF NOT EXISTS fact_coc_signals (
    signal_id                   UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id                   UUID          NOT NULL REFERENCES dim_clients(client_id),
    opportunity_date            DATE          NOT NULL,
    cash_flow_concentration_pct NUMERIC(5,4)  NOT NULL CHECK (cash_flow_concentration_pct BETWEEN 0 AND 1),
    customer_concentration_pct  NUMERIC(5,4)  NOT NULL CHECK (customer_concentration_pct BETWEEN 0 AND 1),
    industry_volatility_index   NUMERIC(4,2)  NOT NULL CHECK (industry_volatility_index BETWEEN 1 AND 10),
    leverage_ratio              NUMERIC(5,2)  NOT NULL CHECK (leverage_ratio >= 0),
    owner_succession_risk       BOOLEAN       NOT NULL,
    regulatory_exposure_score   NUMERIC(4,3)  NOT NULL CHECK (regulatory_exposure_score BETWEEN 0 AND 1),
    coc_score                   NUMERIC(8,4)  NOT NULL,
    risk_class                  VARCHAR(16)   NOT NULL CHECK (risk_class IN ('Preferred', 'Standard', 'Elevated', 'Watch')),
    opportunity_status          VARCHAR(16)   NOT NULL CHECK (opportunity_status IN ('Open', 'Qualified', 'Closed-Won', 'Closed-Lost')),
    created_at                  TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS fact_quotes (
    quote_id               UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    signal_id              UUID          NOT NULL REFERENCES fact_coc_signals(signal_id),
    client_id              UUID          NOT NULL REFERENCES dim_clients(client_id),
    product_id             VARCHAR(8)    NOT NULL REFERENCES dim_products(product_id),
    quote_date             DATE          NOT NULL,
    seats                  INTEGER       NOT NULL CHECK (seats > 0),
    annual_contract_value  NUMERIC(12,2) NOT NULL CHECK (annual_contract_value > 0),
    status                 VARCHAR(16)   NOT NULL CHECK (status IN ('Quoted', 'Expired', 'Declined')),
    expires_at             DATE          NOT NULL,
    created_at             TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS fact_sold_policies (
    policy_id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    quote_id               UUID          NOT NULL REFERENCES fact_quotes(quote_id),
    client_id              UUID          NOT NULL REFERENCES dim_clients(client_id),
    product_id             VARCHAR(8)    NOT NULL REFERENCES dim_products(product_id),
    effective_date         DATE          NOT NULL,
    expiration_date        DATE          NOT NULL CHECK (expiration_date > effective_date),
    annual_contract_value  NUMERIC(12,2) NOT NULL CHECK (annual_contract_value > 0),
    seats                  INTEGER       NOT NULL CHECK (seats > 0),
    status                 VARCHAR(16)   NOT NULL CHECK (status IN ('Active', 'Lapsed', 'Cancelled')),
    created_at             TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS fact_renewals (
    renewal_id      UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id       UUID          NOT NULL REFERENCES fact_sold_policies(policy_id),
    renewal_date    DATE          NOT NULL,
    prior_acv       NUMERIC(12,2) NOT NULL CHECK (prior_acv > 0),
    new_acv         NUMERIC(12,2) CHECK (new_acv > 0),
    rate_change_pct NUMERIC(6,4),
    status          VARCHAR(16)   NOT NULL CHECK (status IN ('Pending', 'Retained', 'Churned', 'Repriced')),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_coc_signals_client  ON fact_coc_signals (client_id);
CREATE INDEX IF NOT EXISTS idx_coc_signals_date    ON fact_coc_signals (opportunity_date);
CREATE INDEX IF NOT EXISTS idx_quotes_client       ON fact_quotes (client_id);
CREATE INDEX IF NOT EXISTS idx_quotes_product      ON fact_quotes (product_id);
CREATE INDEX IF NOT EXISTS idx_quotes_date         ON fact_quotes (quote_date);
CREATE INDEX IF NOT EXISTS idx_policies_client     ON fact_sold_policies (client_id);
CREATE INDEX IF NOT EXISTS idx_policies_status     ON fact_sold_policies (status);
CREATE INDEX IF NOT EXISTS idx_renewals_policy     ON fact_renewals (policy_id);
CREATE INDEX IF NOT EXISTS idx_renewals_date       ON fact_renewals (renewal_date);
