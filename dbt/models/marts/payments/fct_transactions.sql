with txn as (
    select * from {{ ref('stg_txn') }}
),

merchant as (
    select * from {{ ref('stg_merchant') }}
),

account as (
    select * from {{ ref('stg_account') }}
),

mcc as (
    select * from {{ ref('stg_mcc_code') }}
)

select
    txn.transaction_id,
    txn.account_id,
    account.account_type,
    txn.merchant_id,
    merchant.dba_name                              as merchant_name,
    merchant.segment_code,
    txn.card_id,
    txn.amount,
    txn.mcc,
    mcc.description                                as mcc_description,
    mcc.xmob_group,
    mcc.has_override                               as mcc_has_fcc_override,
    txn.transaction_type,
    txn.status,
    txn.transacted_at,
    date_trunc('day', txn.transacted_at)::date     as txn_date,
    date_trunc('month', txn.transacted_at)::date   as txn_month,
    txn.source_system
from txn
left join merchant using (merchant_id)
left join account  using (account_id)
left join mcc      using (mcc)
