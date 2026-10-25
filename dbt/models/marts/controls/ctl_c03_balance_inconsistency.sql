-- C03: a funded sender account whose balance movement does not match the amount (ledger integrity).
select
    tx_id,
    'C03' as control_id,
    'sender balance off by ' || cast(round(orig_balance_error, 2) as varchar) as evidence
from {{ ref('fct_transactions') }}
where tx_type in ('TRANSFER', 'CASH_OUT')
  and orig_balance_before > 0
  and abs(orig_balance_error) > 0.01
