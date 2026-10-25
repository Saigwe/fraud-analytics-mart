-- Leading-digit shares must sum to 1 within each transaction type.
select tx_type, sum(observed_share) as total_share
from {{ ref('rpt_benford_first_digit') }}
group by tx_type
having abs(sum(observed_share) - 1) > 1e-9
