with fleet_customer as (
    select * from {{ ref('stg_fleet_customer') }}
),

geography as (
    select * from {{ ref('stg_geography') }}
),

card_stats as (
    select
        customer_id,
        count(*)                                          as total_cards,
        count(*) filter (where status = 'active')         as active_cards
    from {{ ref('stg_card') }}
    group by 1
),

txn_stats as (
    select
        c.customer_id,
        count(t.transaction_id)   as total_transactions,
        sum(t.amount)             as total_spend,
        avg(t.amount)             as avg_txn_amount
    from {{ ref('stg_card') }} c
    join {{ ref('stg_txn') }} t using (card_id)
    where t.status = 'settled'
    group by 1
)

select
    fc.customer_id,
    fc.company_name,
    fc.dot_number,
    fc.fleet_size,
    fc.zip_code,
    g.city,
    g.state_abbr,
    g.service_region,
    fc.segment_code,
    fc.status,
    fc.onboarded_at,
    coalesce(cs.total_cards, 0)          as total_cards,
    coalesce(cs.active_cards, 0)         as active_cards,
    coalesce(ts.total_transactions, 0)   as total_transactions,
    coalesce(ts.total_spend, 0)          as total_spend,
    ts.avg_txn_amount
from fleet_customer fc
left join geography  g   on fc.zip_code = g.zip_code
left join card_stats cs  using (customer_id)
left join txn_stats  ts  using (customer_id)
