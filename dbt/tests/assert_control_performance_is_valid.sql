-- True positives can't exceed alerts, precision and recall are proportions, and every control reports.
select control_id, 'invalid metrics' as problem
from {{ ref('rpt_control_performance') }}
where true_positives > alerts
   or precision not between 0 and 1
   or recall not between 0 and 1

union all

select c.control_id, 'control missing from performance report'
from {{ ref('control_catalogue') }} c
left join {{ ref('rpt_control_exceptions') }} e on e.control_id = c.control_id
left join {{ ref('rpt_control_performance') }} p on p.control_id = c.control_id
where e.control_id is not null and p.control_id is null
group by 1
