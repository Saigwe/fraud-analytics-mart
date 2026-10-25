-- C06: an account receiving TRANSFERs from fan_in_min_senders or more different senders in one day.
with daily as (
    select dest_account, day_index, count(distinct orig_account) as senders
    from {{ ref('fct_transactions') }}
    where tx_type = 'TRANSFER'
    group by 1, 2
    having count(distinct orig_account) >= {{ var('fan_in_min_senders') }}
)

select
    t.tx_id,
    'C06' as control_id,
    cast(d.senders as varchar) || ' senders to ' || t.dest_account || ' that day' as evidence
from {{ ref('fct_transactions') }} t
join daily d
    on d.dest_account = t.dest_account
    and d.day_index = t.day_index
where t.tx_type = 'TRANSFER'
