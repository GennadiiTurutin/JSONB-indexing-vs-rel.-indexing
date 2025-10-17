CREATE SCHEMA IF NOT EXISTS bench;

CREATE TABLE IF NOT EXISTS bench.results (
  id              BIGSERIAL PRIMARY KEY,
  ts              TIMESTAMPTZ NOT NULL DEFAULT now(),
  label           TEXT        NOT NULL,
  variant         TEXT        NOT NULL,
  run_no          INT         NOT NULL,
  query_sql       TEXT        NOT NULL,
  plan_json       JSONB       NOT NULL,
  planning_ms     NUMERIC,
  execution_ms    NUMERIC,
  actual_rows     BIGINT,
  shared_hits     BIGINT,
  shared_reads    BIGINT,
  shared_dirtied  BIGINT,
  shared_written  BIGINT,
  temp_reads      BIGINT,
  temp_writes     BIGINT,
  heap_fetches    BIGINT,          -- NEW: total heap fetches across plan
  notes           TEXT
);

-- Original index (useful for time-based browsing within label/variant)
CREATE INDEX IF NOT EXISTS bench_results_label_variant_ts_idx
ON bench.results(label, variant, ts);

-- NEW: aligns with your report/query access pattern (ORDER BY variant, run_no)
CREATE INDEX IF NOT EXISTS bench_results_label_variant_run_idx
ON bench.results(label, variant, run_no);
