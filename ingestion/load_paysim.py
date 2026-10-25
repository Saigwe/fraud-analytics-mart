"""Load the PaySim CSV into DuckDB `bronze.paysim_transactions`.

PaySim (Lopez-Rojas, Elmir & Axelsson, 2016) simulates 30 days of mobile-money transactions
(6.36M rows) from real transaction logs of an African mobile-money service. It has no transaction
id, so the loader adds `tx_id` from a deterministic ordering of the columns.

Get the file from Kaggle (sign-in needed): https://www.kaggle.com/datasets/ealaxi/paysim1
and save it as data/raw/paysim.csv (or pass --csv).

Usage
    python ingestion/load_paysim.py --db warehouse/fraud_analytics_mart.duckdb --csv data/raw/paysim.csv
"""
from __future__ import annotations

import argparse
import time
from pathlib import Path

import duckdb

COLUMNS = ["step", "type", "amount", "nameOrig", "oldbalanceOrg", "newbalanceOrig",
           "nameDest", "oldbalanceDest", "newbalanceDest", "isFraud", "isFlaggedFraud"]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--db", default="warehouse/fraud_analytics_mart.duckdb")
    ap.add_argument("--csv", default="data/raw/paysim.csv")
    args = ap.parse_args()

    csv = Path(args.csv)
    if not csv.exists():
        raise SystemExit(f"{csv} not found. Download PaySim from Kaggle (see this file's docstring).")

    t0 = time.perf_counter()
    Path(args.db).parent.mkdir(parents=True, exist_ok=True)
    with duckdb.connect(args.db) as con:
        header = con.execute(f"select * from read_csv('{csv.as_posix()}', header=true) limit 0").description
        found = [c[0] for c in header]
        if found != COLUMNS:
            raise SystemExit(f"unexpected columns: {found}")
        con.execute("create schema if not exists bronze")
        con.execute(f"""
            create or replace table bronze.paysim_transactions as
            select
                row_number() over (order by step, nameOrig, nameDest, type, amount, oldbalanceOrg) as tx_id,
                *
            from read_csv('{csv.as_posix()}', header=true)
        """)
        rows, frauds = con.execute(
            "select count(*), sum(isFraud) from bronze.paysim_transactions").fetchone()
    print(f"bronze.paysim_transactions {rows:,} rows, {frauds:,} fraud, loaded in {time.perf_counter() - t0:.1f}s")


if __name__ == "__main__":
    main()
