-- C05: the same sender, receiver, type and amount again within duplicate_window_steps hours.
with t as (
    select
        tx_id,
        step,
        lag(tx_id) over w as prior_tx_id,
        lag(step) over w  as prior_step
    from {{ ref('fct_transactions') }}
    window w as (partition by orig_account, dest_account, tx_type, amount order by step, tx_id)
)

select tx_id, 'C05' as control_id, 'repeat of tx ' || cast(prior_tx_id as varchar) as evidence
from t
where prior_tx_id is not null
  and step - prior_step <= {{ var('duplicate_window_steps') }}
