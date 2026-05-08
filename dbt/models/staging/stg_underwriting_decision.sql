with source as (
    select * from {{ source('fintech_raw', 'UNDERWRITING_DECISION') }}
),

renamed as (
    select
        decision_id,
        merchant_id,
        customer_id,
        model_id,
        -- Flag legacy v2 decisions so analysts can filter or segment separately.
        model_id = 'M-SCORE-V2' as is_legacy_model,
        decision_date,
        lower(outcome)          as outcome,
        credit_limit,
        score,
        created_at
    from source
)

select * from renamed
