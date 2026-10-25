-- Every control hit, one row per control and transaction, with its review status.
-- Status comes from analysts' reviews (seed `exception_reviews`); anything unreviewed is open.
{% set controls = ['ctl_c01_full_balance_drain', 'ctl_c02_transfer_cashout_chain', 'ctl_c03_balance_inconsistency',
                   'ctl_c04_large_transfer', 'ctl_c05_duplicate_payment', 'ctl_c06_fan_in'] %}
with hits as (
    {% for c in controls %}
    select tx_id, control_id, evidence from {{ ref(c) }}
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
)

select
    h.control_id || '-' || cast(h.tx_id as varchar)     as exception_id,
    h.control_id,
    c.control_name,
    c.severity,
    h.tx_id,
    t.tx_ts,
    t.tx_type,
    t.amount,
    t.orig_account,
    t.dest_account,
    h.evidence,
    coalesce(r.status, 'open')                          as status,
    r.reviewed_by,
    r.reviewed_at,
    t.is_fraud                                          as is_fraud_label
from hits h
join {{ ref('fct_transactions') }} t on t.tx_id = h.tx_id
join {{ ref('control_catalogue') }} c on c.control_id = h.control_id
left join {{ ref('exception_reviews') }} r
    on r.exception_id = h.control_id || '-' || cast(h.tx_id as varchar)
