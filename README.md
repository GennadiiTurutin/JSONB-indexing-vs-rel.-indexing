# JSONB vs Relational Benchmarks (PostgreSQL 17)

## Introduction
Compare JSONB queries vs relational columns across 10 scenarios (S1–S10) with both indexed and unindexed variants. 
This project seeds synthetic data, runs repeatable benchmarks, exports metrics to Excel, visualizes them, and performs a statistical superiority test.


## Table of contents

* Overview
* Prerequisites
* Configuration
* Quick start
* Export to Excel
* Visualizations
* Single run (S1–S10 small-multiples)
* Scaling across sizes
* Superiority test (statistics)


## Overview
In this project we will estimate the performance of each design by running 10 scenarios.

Each scenario is executed in four variants: 
* jsonb_indexed 
* jsonb_unindexed
* rel_indexed 
* rel_unindexed.

Notes: 
* JSONB timestamps are stored as ISO-8601 strings (lexicographic order = chronological). 
* JSONB containment uses GIN(jsonb_path_ops). 
* Trigram cases require pg_trgm + GIN(... gin_trgm_ops). 
* For arrays: AND = must contain all values (@>), OR = any overlap (&& for relational arrays; JSONB uses OR of two @> tests).

## Scenario 1 (S1) Equality on text + numeric inequality

- Goal: classic selective predicate on two fields.
- Predicate shape: text = 'A' AND number > 100.
- Indexes (indexed variants):
* Rel: BTREE on indexed_text_1, indexed_number_1.
* JSONB: functional BTREE on (payload->>'indexed_text_1'), ((payload->>'indexed_number_1')::numeric).

## Scenario 2 (S2) LIKE prefix (left-anchored)

- Goal: prefix search performance.
- Predicate shape: text LIKE 'INV00012%'.
- Indexes (indexed variants):
* Rel: BTREE with text_pattern_ops.
* JSONB: functional BTREE with text_pattern_ops on (payload->>'indexed_text_2').

## Scenario 3 (S3) Substring contains (ILIKE %…%) via trigram

- Goal: full substring search.
- Predicate shape: text ILIKE '%priority%'.
- Indexes (indexed variants):
* Rel: GIN(gin_trgm_ops) on indexed_text_3.
* JSONB: GIN(gin_trgm_ops) on (payload->>'indexed_text_3').

## Scenario 4 (S4) Timestamp range

- Goal: range scan over a time window.
- Predicate shape: ts >= '2025-01-01' AND ts < '2025-02-01'.
- Indexes (indexed variants):
* Rel: BTREE on indexed_timestamp_1 (timestamptz).
* JSONB: functional BTREE on (payload->>'indexed_timestamp_1') (ISO string).

## Scenario 5 (S5) Array AND (must contain BOTH aml and priority)

- Goal: containment on arrays.
- Predicate shape: array @> {'aml','priority'} / JSONB array contains both.
- Indexes (indexed variants):
* Rel: GIN on indexed_text_array_1.
* JSONB: GIN(jsonb_path_ops) on (payload->'indexed_text_array_1').

## Scenario 6 (S6) Array OR (any overlap with {aml, priority})

- Goal: overlap/broader match than S5.
- Predicate shape: Rel: array && {'aml','priority'}; JSONB: @> ['aml'] OR @> ['priority'].
- Indexes (indexed variants):
* Rel: GIN on indexed_text_array_1.
* JSONB: GIN(jsonb_path_ops) on (payload->'indexed_text_array_1').

## Scenario 7 (S7) Multi-key AND (two keys)

- Goal: conjunctive match on two fields.
- Predicate shape: text = 'A' AND boolean = true; JSONB uses single payload @> {...}.
- Indexes (indexed variants):
* Rel: BTREE on indexed_text_1, indexed_boolean_1 (optionally composite).
* JSONB: GIN(jsonb_path_ops) on payload (one probe for two pairs).

## Scenario 8 (S8) Multi-key AND (three keys: text + boolean + number)

- Goal: higher selectivity with three fields.
- Predicate shape: text = 'A' AND boolean = true AND number = 100; JSONB via payload @> {...}.
- Indexes (indexed variants):
* Rel: BTREEs (optionally composite covering) on the three columns.
* JSONB: GIN(jsonb_path_ops) on payload (single containment probe).

## Scenario 9 (S9) OR across keys

- Goal: broader retrieval combining two selective predicates.
- Predicate shape: text = 'A' OR boolean = true; JSONB as OR of two containments.
- Indexes (indexed variants):
* Rel: separate BTREEs on indexed_text_1, indexed_boolean_1 (planner may BitmapOr).
* JSONB: GIN(jsonb_path_ops) on payload (two probes, BitmapOr).

## Scenario 10 (S10) Top-N ordering within a group

- Goal: WHERE … ORDER BY … with index-friendly ordering.
- Predicate shape: WHERE text = 'A' ORDER BY timestamp.
- Indexes (indexed variants):
* Rel: composite index (indexed_text_1, indexed_timestamp_1).
* JSONB: optional composite functional index on ((payload->>'indexed_text_1'), (payload->>'indexed_timestamp_1')) (string ts).



# Statistical proof of ≥10% relational speedup at N ≥ 1,000,000

This project uses a paired, one-sided t-test on log–ratios of execution times to show that relational (indexed) queries are at least 10% faster than JSONB (indexed) for each scenario, and overall.

## Experimental design

Population of interest: Query latencies (in milliseconds) for the 10 benchmark scenarios (S1…S10) on a table with N ≥ 1,000,000 rows.

- Treatments compared:
* rel_indexed = relational schema with appropriate B-tree/GIN indexes
* jsonb_indexed = JSONB schema with corresponding indexes

- Paired runs: For each scenario and run number run_no, we execute both treatments and pair them by (variant, run_no). Pairing controls for time-varying noise (e.g., cache state, background I/O).

- Metric: execution_ms from bench.results for each run.
- Transformation: We analyze the log ratio per pair. 

- Hypotheses (per scenario and overall):
* Null (H₀): θ≥log(0.90) - (Relational is not ≥10% faster; at best equal or slower.)
* Alternative (H₁): 𝜃<log(0.90) - (Relational is ≥10% faster on average.)
This is a one-sided superiority test.

Decision (significance α=0.05): Reject H₀ (claim ≥10% faster) if p<α.

The script performs the above per scenario and again on a pooled dataset (all scenarios combined) to provide an overall conclusion.

```
python test_superiority.py \
  --label-rel   "N=1000000 rel_indexed" \
  --label-jsonb "N=1000000 jsonb_indexed" \
  --alpha 0.05 \
  --delta 0.10
```
The script:
- fetches paired rows from bench.results,
- computes log-ratios per pair,
- runs the one-sided t-test per scenario and overall,
- prints a table with: n_pairs, mean_log_ratio, geomean_ratio, threshold_ratio(=0.90), t_stat, df, p_value, and passes (true if p<α),
- writes superiority_results.csv.

## Interpretation of the output

If geomean_ratio = 0.82, relational is ~18% faster on average.
p_value (one-sided): probability of seeing a mean this low (or lower) if in truth relational is not ≥10% faster.
If p < 0.05, we have statistical evidence to claim ≥10% faster for that scenario.
passes = whether the scenario meets the pre-registered superiority criterion at α=0.05.
The __OVERALL__ row aggregates all pairs from all scenarios, providing a single global claim under the same hypothesis.

## Assumptions

- Paired design validity: Each pair compares runs with the same variant and run_no under near-identical conditions (same DB instance, dataset, OS cache regime), so pairing removes much of the shared noise.
- Independence across pairs: Runs are executed independently (e.g., separated enough to avoid long-range interference). Minor residual dependence typically has limited impact, especially with consistent pairing.
- Finite variance / approximate normality of the mean: The t-test assumes the sample mean of log-ratios is approximately normal.
- The log transform mitigates right-skew and stabilizes variance (latencies are multiplicative).
- With n around 5–10 or more per scenario, the t-test is robust; the script uses Student’s t CDF (SciPy) or a normal approximation if SciPy is absent.
- Stationarity within scenario: The distribution of log-ratios doesn’t drift materially during the runs (warm-ups reduce transient effects).
- Large-N regime controlled: By filtering to the explicit labels N=1000000 …, we ensure all pairs reflect the intended problem size.

## How to run
Statistical test: “REL is ≥ Δ faster than JSONB”

test_superiority.py pairs runs by (variant, run_no) and tests the geometric mean of rel/jsonb using a one-sample t-test on log(rel/jsonb):

H₀: geomean ≥ (1 − Δ)

H₁: geomean < (1 − Δ)

Example (prove REL is ≥20% faster, α=0.05, N=1,000,000):

python test_superiority.py \
  --label-rel   "N=1000000 rel_indexed" \
  --label-jsonb "N=1000000 jsonb_indexed" \
  --delta 0.20 \
  --alpha 0.05

Typical output (per scenario + overall):

Rel vs JSONB (ratio = rel/jsonb). Target ratio <= 0.80 (≥20% faster)
         variant  n_pairs  geomean_ratio  threshold_ratio   p_value  passes
     S6_array_or        7          0.297              0.8  2.2e-07     True
     ...
     __OVERALL__       70          0.402              0.8  2.3e-05     True

## Prerequisites

Docker + Docker Compose

Python 3.11+

python -m venv venv
source venv/bin/activate
pip install -r requirements.txt \
  || pip install pandas numpy matplotlib scipy sqlalchemy psycopg2-binary openpyxl

Configure environment

Create a .env in repo root (Compose and Python will read this):

POSTGRES_DB=ledgerdb
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres

# Client defaults (used by Python; can be omitted—scripts have fallbacks)
PGHOST=127.0.0.1
PGPORT=5433
PGDATABASE=ledgerdb
PGUSER=postgres
PGPASSWORD=postgres

Removing with docker compose down -v deletes all DB data.

# Quick start
1) Start Postgres
docker compose up -d db

# e.g. docker compose run --rm -e ROWS=1000000 seed

3) Run the benchmark suite: python export_bench_to_excel.py 

4) Shut down
docker compose down -v

What gets benchmarked

Scenarios (S1–S10): equality + inequality, LIKE prefix, substring (trigram), timestamp range, array AND / OR, multi-key AND, OR across keys, top-N within a group.

Warmups: each scenario warms up (p_warmup) before timing (p_runs) to stabilize caches and JIT noise.

# → exports/performance_run_<N>.xlsx (sheet: "summary")

The Excel file aggregates p50/p95/avg and buffer counters per (label, variant).

python viz_single_run.py \
  --file exports/performance_run_1000000.xlsx \
  --labels "jsonb_ind" "jsonb_unind" "rel_ind" "rel_unind" \
  --metric p95_ms \
  --ylabel none \
  --ratio 0.655

# Scaling graph
python viz_scaling.py \                     
  --glob "exports/performance_run_*.xlsx" \
  --outdir viz_scaling \
  --metric p95_ms \
  --ylabel none \
  --ratio 0.655


 python3 make_relative_table.py --csv ./viz_single_1mi_grouped/p95_ms_wide.csv


