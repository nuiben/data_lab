with source as (
    select * from {{ source('fintech_raw', 'CARD') }}
),

renamed as (
    select
        card_id,
        customer_id,
        account_id,
        card_number_last4,
        lower(card_type)  as card_type,
        driver_name,
        vehicle_id,
        lower(status)     as status,
        issued_at,
        created_at
    from source
)

select * from renamed
