with source as (
    select * from {{ source('fintech_raw', 'ACCOUNT') }}
),

renamed as (
    select
        account_id,
        merchant_id,
        customer_id,
        lower(account_type)  as account_type,
        routing_number,
        lower(status)        as status,
        opened_at,
        lower(source_system) as source_system,
        created_at
    from source
)

select * from renamed
