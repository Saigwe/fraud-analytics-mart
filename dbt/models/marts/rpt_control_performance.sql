-- How well each control finds fraud, measured against PaySim's isFraud label.
-- ANY_RULE = flagged by at least one control; INCUMBENT = PaySim's own isFlaggedFraud rule.
with labels as (
    select tx_id, is_fraud, is_flagged_by_incumbent from {{ ref('fct_transactions') }}
),

total as (
    select count(*) filter (where is_fraud) as frauds from labels
),

alerts as (
    select control_id, tx_id from {{ ref('rpt_control_exceptions') }}
    union all
    select distinct 'ANY_RULE', tx_id from {{ ref('rpt_control_exceptions') }}
    union all
    select 'INCUMBENT', tx_id from labels where is_flagged_by_incumbent
),

scored as (
    select a.control_id, count(*) as alerts, count(*) filter (where l.is_fraud) as true_positives
    from alerts a
    join labels l on l.tx_id = a.tx_id
    group by 1
)

select
    s.control_id,
    s.alerts,
    s.true_positives,
    cast(s.true_positives as double) / nullif(s.alerts, 0)  as precision,
    cast(s.true_positives as double) / nullif(t.frauds, 0)  as recall
from scored s
cross join total t
