"""Write a small PaySim-shaped fixture to DuckDB `bronze.paysim_transactions`, plus an answer key.

Same columns as the real PaySim load, so CI runs every model without the 470 MB download.
Planted patterns (recorded in `bronze.fixture_answer_key`, read only by fixture-only tests):
- mule_chain        : a TRANSFER that empties an account, then a CASH_OUT of the same amount in the same step
- duplicate_payment : the same payment re-sent one step later
- fan_in            : one destination receiving TRANSFERs from 5 different accounts in one day

Usage
    python tests/fixtures/make_paysim_fixture.py --db warehouse/fraud_analytics_mart.duckdb
"""
from __future__ import annotations

import argparse
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd

TYPES = ["CASH_IN", "CASH_OUT", "DEBIT", "PAYMENT", "TRANSFER"]
TYPE_P = [0.22, 0.35, 0.01, 0.34, 0.08]


def normal_rows(rng: np.random.Generator, n: int) -> list[dict]:
    rows = []
    for i in range(n):
        tx_type = rng.choice(TYPES, p=TYPE_P)
        amount = round(float(rng.lognormal(9.5, 1.3)), 2)
        old_orig = round(float(rng.lognormal(9.0, 2.0)), 2) if rng.random() < 0.7 else 0.0
        if tx_type == "CASH_IN":
            new_orig = round(old_orig + amount, 2)
        else:
            new_orig = round(max(old_orig - amount, 0.0), 2)
        dest = f"M{rng.integers(1e8, 1e9)}" if tx_type == "PAYMENT" else f"C{rng.integers(1e8, 1e9)}"
        old_dest = 0.0 if dest.startswith("M") else round(float(rng.lognormal(10, 2)), 2)
        new_dest = old_dest if dest.startswith("M") else round(old_dest + (amount if tx_type != "CASH_IN" else -amount), 2)
        rows.append(dict(step=int(rng.integers(1, 744)), type=tx_type, amount=amount,
                         nameOrig=f"C{rng.integers(1e8, 1e9)}", oldbalanceOrg=old_orig, newbalanceOrig=new_orig,
                         nameDest=dest, oldbalanceDest=old_dest, newbalanceDest=max(new_dest, 0.0),
                         isFraud=0, isFlaggedFraud=0))
    return rows


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--db", required=True)
    ap.add_argument("--rows", type=int, default=20000)
    ap.add_argument("--seed", type=int, default=1414)
    args = ap.parse_args()
    rng = np.random.default_rng(args.seed)

    rows, key = normal_rows(rng, args.rows), []

    for i in range(40):  # mule chains: drain by TRANSFER, then CASH_OUT the same amount
        step, amount = int(rng.integers(1, 744)), round(float(rng.lognormal(11, 1)), 2)
        victim, mule = f"C9{i:08d}", f"C8{i:08d}"
        rows.append(dict(step=step, type="TRANSFER", amount=amount, nameOrig=victim, oldbalanceOrg=amount,
                         newbalanceOrig=0.0, nameDest=mule, oldbalanceDest=0.0, newbalanceDest=0.0,
                         isFraud=1, isFlaggedFraud=int(amount > 200000)))
        rows.append(dict(step=step, type="CASH_OUT", amount=amount, nameOrig=f"C7{i:08d}", oldbalanceOrg=amount,
                         newbalanceOrig=0.0, nameDest=f"C6{i:08d}", oldbalanceDest=0.0, newbalanceDest=amount,
                         isFraud=1, isFlaggedFraud=0))
        key.append(dict(pattern="mule_chain", nameOrig=victim, step=step))

    for i in range(10):  # the same payment sent twice, one step apart
        base = dict(normal_rows(rng, 1)[0], type="PAYMENT", nameOrig=f"C5{i:08d}", nameDest=f"M5{i:08d}")
        base["oldbalanceDest"] = base["newbalanceDest"] = 0.0
        rows += [base, dict(base, step=base["step"] + 1)]
        key.append(dict(pattern="duplicate_payment", nameOrig=base["nameOrig"], step=base["step"] + 1))

    mule = "C400000001"  # fan-in: 5 senders to one account on one day
    for i in range(5):
        r = normal_rows(rng, 1)[0]
        rows.append(dict(r, type="TRANSFER", step=100 + i, nameOrig=f"C41{i:07d}", nameDest=mule))
    key.append(dict(pattern="fan_in", nameOrig=mule, step=100))

    df = pd.DataFrame(rows).sort_values(["step", "nameOrig", "nameDest", "type", "amount", "oldbalanceOrg"])
    df.insert(0, "tx_id", np.arange(1, len(df) + 1))
    Path(args.db).parent.mkdir(parents=True, exist_ok=True)
    with duckdb.connect(args.db) as con:
        con.execute("create schema if not exists bronze")
        for name, frame in {"paysim_transactions": df, "fixture_answer_key": pd.DataFrame(key)}.items():
            con.register("frame", frame)
            con.execute(f"create or replace table bronze.{name} as select * from frame")
            con.unregister("frame")
            print(f"bronze.{name:<22} {len(frame):>7,} rows")


if __name__ == "__main__":
    main()
