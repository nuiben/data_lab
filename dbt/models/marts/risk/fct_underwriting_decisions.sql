with decisions as (
    select * from {{ ref('stg_underwriting_decision') }}
),

-- MODEL_VERSION is a clean reference table; reference the source directly.
model_version as (
    select * from {{ source('fintech_raw', 'MODEL_VERSION') }}
),

merchant as (
    select merchant_id, dba_name, segment_code
    from {{ ref('stg_merchant') }}
),

fleet_customer as (
    select customer_id, company_name
    from {{ ref('stg_fleet_customer') }}
)

select
    d.decision_id,
    d.merchant_id,
    m.dba_name                             as merchant_name,
    d.customer_id,
    fc.company_name                        as fleet_company_name,
    d.model_id,
    mv.version                             as model_version,
    mv.name                                as model_name,
    d.is_legacy_model,
    d.decision_date,
    d.outcome,
    d.credit_limit,
    d.score,
    -- Thresholds aligned with M-Score v4 docs.
    -- v2 scores use a slightly different scale — filter with is_legacy_model.
    case
        when d.score >= 0.75 then 'low'
        when d.score >= 0.50 then 'medium'
        when d.score >= 0.25 then 'high'
        else 'very_high'
    end                                    as risk_band,
    d.created_at
from decisions d
left join model_version  mv  on d.model_id = mv.model_id
left join merchant       m   using (merchant_id)
left join fleet_customer fc  using (customer_id)
