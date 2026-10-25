-- True positives can't exceed alerts, precision and recall are proportions, and every catalogue control
-- plus the three rule-set rows is reported.
select control_id, 'invalid metrics' as problem
from {{ ref('rpt_control_performance') }}
where true_positives > alerts
   or precision not between 0 and 1
   or recall not between 0 and 1

union all

select c.control_id, 'missing from performance report'
from (
    select control_id from {{ ref('control_catalogue') }}
    union all
    select x from (values ('PRODUCTION_RULES'), ('ALL_RULES'), ('INCUMBENT')) v(x)
) c
left join {{ ref('rpt_control_performance') }} p on p.control_id = c.control_id
where p.control_id is null
