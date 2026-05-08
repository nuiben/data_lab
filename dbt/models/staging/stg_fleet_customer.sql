with source as (
    select * from {{ source('fintech_raw', 'FLEET_CUSTOMER') }}
),

renamed as (
    select
        customer_id,
        company_name,
        dot_number,
        fleet_size,
        zip_code,
        segment_code,
        lower(status) as status,
        onboarded_at,
        created_at
    from source
)

select * from renamed
