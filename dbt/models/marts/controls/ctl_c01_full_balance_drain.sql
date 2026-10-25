-- C01: a TRANSFER or CASH_OUT that empties the sender's account.
select tx_id, 'C01' as control_id, 'amount equals the full opening balance' as evidence
from {{ ref('fct_transactions') }}
where is_full_drain
