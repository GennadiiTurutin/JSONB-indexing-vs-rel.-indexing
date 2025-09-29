\set ON_ERROR_STOP on

-- ===========================================================
-- bench.run(label, variant, sql, runs=7, warmup=2,
--           seqscan=NULL, jit=NULL)  RETURNS void
--
-- Executes the given SQL with:
--   EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
-- Warmups are not recorded. Each recorded run is inserted
-- into bench.results with timing + buffer metrics + plan JSON.
-- ===========================================================
CREATE OR REPLACE FUNCTION bench.run(
  p_label   TEXT,
  p_variant TEXT,
  p_sql     TEXT,
  p_runs    INT DEFAULT 7,
  p_warmup  INT DEFAULT 2,
  p_seqscan BOOLEAN DEFAULT NULL,
  p_jit     BOOLEAN DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql AS
$$
DECLARE
  i           INT;
  j           JSON;     -- EXPLAIN output (FORMAT JSON)
  root        JSONB;    -- top-level JSONB object
  root_plan   JSONB;    -- top-level Plan node
  v_planning  NUMERIC;
  v_exec      NUMERIC;
  v_rows      BIGINT;
  v_hit       BIGINT;
  v_read      BIGINT;
  v_dirty     BIGINT;
  v_write     BIGINT;
  v_tmp_r     BIGINT;
  v_tmp_w     BIGINT;
BEGIN
  -- Session-local toggles (optional)
  IF p_seqscan IS NOT NULL THEN
    EXECUTE format('SET LOCAL enable_seqscan = %s',
                   CASE WHEN p_seqscan THEN 'on' ELSE 'off' END);
  END IF;

  IF p_jit IS NOT NULL THEN
    EXECUTE format('SET LOCAL jit = %s',
                   CASE WHEN p_jit THEN 'on' ELSE 'off' END);
  END IF;

  -- Warmup runs (not recorded)
  FOR i IN 1..GREATEST(p_warmup, 0) LOOP
    EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ' || p_sql INTO j;
  END LOOP;

  -- Recorded runs
  FOR i IN 1..GREATEST(p_runs, 1) LOOP
    EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ' || p_sql INTO j;

    -- Parse the JSON once
    root      := (j::jsonb)->0;
    root_plan := root->'Plan';

    v_planning := NULLIF(root->>'Planning Time','')::numeric;
    v_exec     := COALESCE(NULLIF(root->>'Execution Time','')::numeric,
                           NULLIF(root_plan->>'Actual Total Time','')::numeric);

    v_rows   := NULLIF(root_plan->>'Actual Rows','')::bigint;
    v_hit    := COALESCE(NULLIF(root_plan->>'Shared Hit Blocks','')::bigint, 0);
    v_read   := COALESCE(NULLIF(root_plan->>'Shared Read Blocks','')::bigint, 0);
    v_dirty  := COALESCE(NULLIF(root_plan->>'Shared Dirtied Blocks','')::bigint, 0);
    v_write  := COALESCE(NULLIF(root_plan->>'Shared Written Blocks','')::bigint, 0);
    v_tmp_r  := COALESCE(NULLIF(root_plan->>'Temp Read Blocks','')::bigint, 0);
    v_tmp_w  := COALESCE(NULLIF(root_plan->>'Temp Written Blocks','')::bigint, 0);

    INSERT INTO bench.results (
      label, variant, run_no, query_sql, plan_json,
      planning_ms, execution_ms, actual_rows,
      shared_hits, shared_reads, shared_dirtied, shared_written,
      temp_reads, temp_writes
    )
    VALUES (
      p_label, p_variant, i, p_sql, j::jsonb,
      v_planning, v_exec, v_rows,
      v_hit, v_read, v_dirty, v_write,
      v_tmp_r, v_tmp_w
    );
  END LOOP;
END;
$$;

-- =======================================
-- bench.clear(label)  RETURNS void
-- Deletes prior results for a label.
-- =======================================
CREATE OR REPLACE FUNCTION bench.clear(p_label TEXT) RETURNS VOID
LANGUAGE plpgsql AS
$$
BEGIN
  DELETE FROM bench.results WHERE label = p_label;
END;
$$;

DO $$ BEGIN RAISE NOTICE 'bench functions created: bench.run, bench.clear'; END $$;
