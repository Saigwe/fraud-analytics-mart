-- Answer key: every planted duplicate (tx_id ending in 'D') must be caught by the control.
select t.tx_id
from {{ ref('stg_bronze__transactions') }} t
left join {{ ref('rpt_duplicate_payments') }} d on d.tx_id = t.tx_id
where t.tx_id like '%D' and d.tx_id is null
