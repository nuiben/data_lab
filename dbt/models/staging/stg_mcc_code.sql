with source as (
    select * from {{ source('fintech_raw', 'MCC_CODE') }}
),

renamed as (
    select
        mcc,
        description,
        xmob_group,
        has_override,
        created_at
    from source
)

select * from renamed
