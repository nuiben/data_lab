with source as (
    select * from {{ source('fintech_raw', 'TXN') }}
),

renamed as (
    select
        transaction_id,
        account_id,
        merchant_id,
        card_id,
        amount,
        mcc,
        lower(transaction_type)  as transaction_type,
        lower(status)            as status,

        -- AcquireNet sends Eastern time; PaymentCore sends UTC.
        -- Normalize to UTC here so marts don't branch on source_system.
        case
            when source_system = 'AcquireNet'
                then convert_timezone('America/New_York', 'UTC', transacted_at)
            else transacted_at
        end                      as transacted_at,

        lower(source_system)     as source_system,
        created_at
    from source
)

select * from renamed
