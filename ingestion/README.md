# Ingestion

`load_paysim.py` loads the PaySim CSV into `bronze.paysim_transactions`. The table has the original
11 columns plus a deterministic `tx_id`, because PaySim has no transaction id.

1. Download PaySim from [Kaggle](https://www.kaggle.com/datasets/ealaxi/paysim1). A free sign-in is needed.
2. Unzip it to `data/raw/paysim.csv`. The `data/` folder is gitignored.
3. Run `make bronze`, or the whole pipeline with `make all`.

CI never downloads anything. It uses `tests/fixtures/make_paysim_fixture.py`, which writes the same table shape.
