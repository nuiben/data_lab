with settlement as (
    select * from {{ ref('stg_settlement') }}
),

account as (
    select * from {{ ref('stg_account') }}
),

merchant as (
    select * from {{ ref('stg_merchant') }}
)

select
    settlement.settlement_id,
    settlement.account_id,
    account.account_type,
    account.merchant_id,
    merchant.dba_name                   as merchant_name,
    merchant.segment_code,
    settlement.batch_date,
    settlement.settlement_date,
    settlement.settlement_lag_days,
    settlement.gross_amount,
    settlement.fee_amount,
    settlement.net_amount,
    settlement.transaction_count,
    -- Safe division: fee as a fraction of gross (Snowflake-specific div0).
    div0(settlement.fee_amount, settlement.gross_amount) as fee_rate,
    settlement.source_system
from settlement
left join account  using (account_id)
left join merchant using (merchant_id)
