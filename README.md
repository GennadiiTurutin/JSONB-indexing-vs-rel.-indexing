# JSONB vs Relational Benchmarks (PostgreSQL 17)

## Introduction
Compare JSONB queries vs relational columns across 10 scenarios (S1–S10) with both indexed and unindexed variants. 
This project seeds synthetic data, runs repeatable benchmarks, exports metrics to Excel, visualizes them, and performs a statistical superiority test.

## Overview
In this project we will estimate the performance of each design by running 10 scenarios.

Each scenario is executed in four variants: 
* jsonb_indexed 
* jsonb_unindexed
* rel_indexed 
* rel_unindexed.

## Scenario 1 (S1) Equality on text + numeric inequality

## Scenario 2 (S2) LIKE prefix (left-anchored)

## Scenario 3 (S3) Substring contains (ILIKE %…%) via trigram

## Scenario 4 (S4) Timestamp range

## Scenario 5 (S5) Array AND (must contain BOTH aml and priority)

## Scenario 6 (S6) Array OR (any overlap with {aml, priority})

## Scenario 7 (S7) Multi-key AND (two keys)

## Scenario 8 (S8) Multi-key AND (three keys: text + boolean + number)

## Scenario 9 (S9) OR across keys

## Scenario 10 (S10) Top-N ordering within a group


## Prerequisites

Docker + Docker Compose

Python 3.11+

python -m venv venv
source venv/bin/activate
pip install -r requirements.txt 
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

4) Shut down
docker compose down -v

What gets benchmarked

Scenarios (S1–S10): equality + inequality, LIKE prefix, substring (trigram), timestamp range, array AND / OR, multi-key AND, OR across keys, top-N within a group.

Warmups: each scenario warms up (p_warmup) before timing (p_runs) to stabilize caches and JIT noise.

# → exports/performance_run_<N>.xlsx (sheet: "summary")

The Excel file aggregates p50/p95/avg and buffer counters per (label, variant).

python3 viz_single_run.py \
  --file exports/performance_run_1000000.xlsx \
  --labels "jsonb_ind" "jsonb_unind" "rel_ind" "rel_unind" \
  --metric p95_ms \
  --ylabel none \
  --ratio 0.655

# Scaling graph
python3 viz_scaling.py --glob "exports/performance_run_*.xlsx" \
  --outdir viz_scaling \
  --metric p95_ms \
  --ylabel none \
  --ratio 0.655 \
  --indexing indexed


# Relative performance graph
python3 make_relative_table.py \
  --csv ./viz_single_grouped/p95_ms_wide.csv \
  --title "Relative Performance (p95)" \
  --out ./relative_table.png

# Visualization of association between shared hits and latency
python3 viz_hits.py --csv bench_results.csv --n 1000000 --outdir viz_bench_1mio

# Formal one-sided test
python3 test_superiority.py --csv bench_results.csv --label-rel "rel_indexed" --label-jsonb "jsonb_indexed" --n 1000000 --delta 0.10 --alpha 0.05 --image