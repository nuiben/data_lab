with source as (
    select * from {{ source('fintech_raw', 'RISK_SCORE') }}
),

renamed as (
    select
        score_id,
        merchant_id,
        customer_id,
        model_id,
        score_date,
        score,
        lower(risk_band) as risk_band,
        created_at
    from source
)

select * from renamed
