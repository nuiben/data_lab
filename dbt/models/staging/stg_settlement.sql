with source as (
    select * from {{ source('fintech_raw', 'SETTLEMENT') }}
),

renamed as (
    select
        settlement_id,
        account_id,
        batch_date,
        settlement_date,
        gross_amount,
        fee_amount,
        net_amount,
        transaction_count,
        -- Settlement lag differs by business line: P&S is T+1, FCC is T+3.
        -- Flag outliers in marts rather than filtering here.
        datediff('day', batch_date, settlement_date) as settlement_lag_days,
        lower(source_system)                         as source_system,
        created_at
    from source
)

select * from renamed
