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
  notes           TEXT
);