with source as (
    select * from {{ source('fintech_raw', 'DISPUTE') }}
),

renamed as (
    select
        dispute_id,
        transaction_id,
        lower(dispute_type)                          as dispute_type,
        amount,
        opened_at,
        resolved_at,
        lower(outcome)                               as outcome,
        resolved_at is not null                      as is_resolved,
        case
            when resolved_at is not null
            then datediff('day', opened_at, resolved_at)
        end                                          as resolution_days,
        lower(source_system)                         as source_system,
        created_at
    from source
)

select * from renamed
