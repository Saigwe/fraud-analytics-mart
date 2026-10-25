-- C04: the simple threshold rule: any TRANSFER above large_transfer_threshold.
select
    tx_id,
    'C04' as control_id,
    'transfer above {{ var("large_transfer_threshold") }}' as evidence
from {{ ref('fct_transactions') }}
where tx_type = 'TRANSFER'
  and amount > {{ var('large_transfer_threshold') }}
