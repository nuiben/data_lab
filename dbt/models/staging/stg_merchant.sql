with source as (
    select * from {{ source('fintech_raw', 'MERCHANT') }}
),

renamed as (
    select
        merchant_id,
        company_name,
        coalesce(dba_name, company_name) as dba_name,
        ein,
        mcc,
        zip_code,
        segment_code,
        lower(status)        as status,
        onboarded_at,
        lower(source_system) as source_system,
        created_at
    from source
)

select * from renamed
