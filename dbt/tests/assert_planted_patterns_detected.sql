-- Answer key (CI fixture only): every planted pattern must be caught by the control built for it.
{{ config(enabled=var('is_fixture', false)) }}
with key as (
    select * from {{ source('bronze', 'fixture_answer_key') }}
),

hits as (
    select e.control_id, e.orig_account, e.dest_account, t.step
    from {{ ref('rpt_control_exceptions') }} e
    join {{ ref('fct_transactions') }} t on t.tx_id = e.tx_id
)

select k.*
from key k
where not exists (
    select 1 from hits h
    where (k.pattern = 'mule_chain'        and h.control_id = 'C02' and h.orig_account = k.nameOrig and h.step = k.step)
       or (k.pattern = 'duplicate_payment' and h.control_id = 'C05' and h.orig_account = k.nameOrig and h.step = k.step)
       or (k.pattern = 'fan_in'            and h.control_id = 'C06' and h.dest_account = k.nameOrig)
)
