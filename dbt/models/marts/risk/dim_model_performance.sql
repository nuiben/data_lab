-- Monthly approval rates and score distributions by model version.
-- Use this to track the M-Score v2→v4 migration: if is_legacy_model rows
-- show a materially different approval_rate, the migration is affecting outcomes.
with decisions as (
    select * from {{ ref('stg_underwriting_decision') }}
)

select
    model_id,
    is_legacy_model,
    date_trunc('month', decision_date)::date                         as decision_month,
    count(*)                                                         as total_decisions,
    count(*) filter (where outcome = 'approved')                     as approved_count,
    count(*) filter (where outcome = 'declined')                     as declined_count,
    count(*) filter (where outcome = 'review')                       as review_count,
    div0(
        count(*) filter (where outcome = 'approved'),
        count(*)
    )                                                                as approval_rate,
    avg(score)                                                       as avg_score,
    avg(credit_limit) filter (where outcome = 'approved')            as avg_approved_credit_limit
from decisions
group by 1, 2, 3
order by decision_month desc, model_id
