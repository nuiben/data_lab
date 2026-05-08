with txn as (
    -- Card transactions only; P&S transactions without a card_id are excluded.
    select * from {{ ref('stg_txn') }}
    where card_id is not null
),

card as (
    select * from {{ ref('stg_card') }}
),

fleet_customer as (
    select * from {{ ref('stg_fleet_customer') }}
),

mcc as (
    select * from {{ ref('stg_mcc_code') }}
)

select
    txn.transaction_id,
    txn.account_id,
    txn.card_id,
    card.card_type,
    card.driver_name,
    card.vehicle_id,
    card.customer_id,
    fc.company_name                               as fleet_company_name,
    fc.fleet_size,
    txn.merchant_id,
    txn.amount,
    txn.mcc,
    mcc.description                               as mcc_description,
    mcc.xmob_group,
    txn.transaction_type,
    txn.status,
    txn.transacted_at,
    date_trunc('day', txn.transacted_at)::date    as txn_date,
    date_trunc('month', txn.transacted_at)::date  as txn_month,
    txn.source_system
from txn
left join card           using (card_id)
left join fleet_customer fc using (customer_id)
left join mcc            using (mcc)
