with merchant as (
    select * from {{ ref('stg_merchant') }}
),

geography as (
    select * from {{ ref('stg_geography') }}
),

mcc as (
    select * from {{ ref('stg_mcc_code') }}
),

txn_stats as (
    select
        merchant_id,
        count(*)                                                    as total_transactions,
        sum(amount)                                                 as total_txn_volume,
        avg(amount)                                                 as avg_txn_amount,
        min(transacted_at)                                          as first_transaction_at,
        max(transacted_at)                                          as last_transaction_at,
        count(distinct date_trunc('month', transacted_at)::date)    as active_months
    from {{ ref('stg_txn') }}
    where status = 'settled'
    group by 1
)

select
    m.merchant_id,
    m.company_name,
    m.dba_name,
    m.ein,
    m.mcc,
    mcc.description                                 as mcc_description,
    mcc.xmob_group,
    m.zip_code,
    g.city,
    g.state_abbr,
    g.service_region,
    m.segment_code,
    m.status,
    m.onboarded_at,
    m.source_system,
    coalesce(ts.total_transactions, 0)              as total_transactions,
    coalesce(ts.total_txn_volume, 0)                as total_txn_volume,
    ts.avg_txn_amount,
    ts.first_transaction_at,
    ts.last_transaction_at,
    coalesce(ts.active_months, 0)                   as active_months
from merchant m
left join geography  g   on m.zip_code = g.zip_code
left join mcc            using (mcc)
left join txn_stats  ts  using (merchant_id)
