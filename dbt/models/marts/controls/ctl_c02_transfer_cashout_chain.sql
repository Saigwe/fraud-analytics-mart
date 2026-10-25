-- C02: a TRANSFER and a CASH_OUT of exactly the same amount in the same hour: money moved to a
-- second account and withdrawn at once (a mule chain). Both legs are flagged.
with transfers as (
    select tx_id, step, amount from {{ ref('fct_transactions') }} where tx_type = 'TRANSFER'
),

cash_outs as (
    select tx_id, step, amount from {{ ref('fct_transactions') }} where tx_type = 'CASH_OUT'
),

pairs as (
    select t.tx_id as transfer_tx_id, c.tx_id as cash_out_tx_id
    from transfers t
    join cash_outs c on c.step = t.step and c.amount = t.amount
)

select transfer_tx_id as tx_id, 'C02' as control_id,
       'transfer leg; cash-out tx ' || cast(min(cash_out_tx_id) as varchar) as evidence
from pairs
group by transfer_tx_id

union all

select cash_out_tx_id, 'C02', 'cash-out leg; transfer tx ' || cast(min(transfer_tx_id) as varchar)
from pairs
group by cash_out_tx_id
