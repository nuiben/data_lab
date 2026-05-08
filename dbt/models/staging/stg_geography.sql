with source as (
    select * from {{ source('fintech_raw', 'GEOGRAPHY') }}
),

renamed as (
    select
        zip_code,
        city,
        state_abbr,
        msa_name,
        service_region,
        created_at
    from source
)

select * from renamed
