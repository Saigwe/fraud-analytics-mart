-- How well each control finds fraud, measured against PaySim's isFraud label. Every catalogue control
-- gets a row, even with no alerts. Rows for rule sets:
--   PRODUCTION_RULES = flagged by a control whose lifecycle is 'production'
--   ALL_RULES        = flagged by any control
--   INCUMBENT        = PaySim's own isFlaggedFraud rule (the baseline to beat)
with labels as (
    select tx_id, is_fraud, is_flagged_by_incumbent from {{ ref('fct_transactions') }}
),

total as (
    select count(*) filter (where is_fraud) as frauds from labels
),

catalogue as (
    select control_id, lifecycle from {{ ref('control_catalogue') }}
),

alerts as (
    select control_id, tx_id from {{ ref('rpt_control_exceptions') }}
    union all
    select distinct 'ALL_RULES', tx_id from {{ ref('rpt_control_exceptions') }}
    union all
    select distinct 'PRODUCTION_RULES', e.tx_id
    from {{ ref('rpt_control_exceptions') }} e
    join catalogue c on c.control_id = e.control_id
    where c.lifecycle = 'production'
    union all
    select 'INCUMBENT', tx_id from labels where is_flagged_by_incumbent
),

scored as (
    select a.control_id, count(*) as alerts, count(*) filter (where l.is_fraud) as true_positives
    from alerts a
    join labels l on l.tx_id = a.tx_id
    group by 1
),

rows_wanted as (
    select control_id, lifecycle from catalogue
    union all
    select x, null from (values ('PRODUCTION_RULES'), ('ALL_RULES'), ('INCUMBENT')) v(x)
)

select
    r.control_id,
    r.lifecycle,
    coalesce(s.alerts, 0)                                                   as alerts,
    coalesce(s.true_positives, 0)                                           as true_positives,
    cast(coalesce(s.true_positives, 0) as double) / nullif(s.alerts, 0)     as precision,
    cast(coalesce(s.true_positives, 0) as double) / nullif(t.frauds, 0)     as recall
from rows_wanted r
left join scored s on s.control_id = r.control_id
cross join total t
