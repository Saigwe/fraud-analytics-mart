PY ?= python
DB ?= warehouse/fraud_analytics_mart.duckdb
CSV ?= data/raw/paysim.csv
DBT = cd dbt && DUCKDB_PATH=../$(DB) dbt

.PHONY: all fixture-all bronze bronze-fixture dbt dbt-fixture ml clean

all: bronze dbt ml                              ## real PaySim (download it first, see README)
fixture-all: bronze-fixture dbt-fixture ml      ## PaySim-shaped fixture, no download (CI)

bronze:
	$(PY) ingestion/load_paysim.py --db $(DB) --csv $(CSV)

bronze-fixture:
	$(PY) tests/fixtures/make_paysim_fixture.py --db $(DB)

dbt:
	$(DBT) build --profiles-dir .

dbt-fixture:
	$(DBT) build --profiles-dir . --vars '{is_fixture: true}'

ml:
	$(PY) analysis/ml_vs_rules.py --db $(DB)

clean:
	rm -rf warehouse dbt/target dbt/logs
