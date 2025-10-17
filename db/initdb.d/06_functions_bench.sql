\set ON_ERROR_STOP on

-- 1) Sum BUFFERS/Heap Fetches across ALL plan nodes
CREATE OR REPLACE FUNCTION bench.sum_buffers(p_plan jsonb)
RETURNS TABLE (
  sh_hit       bigint,
  sh_read      bigint,
  sh_dirty     bigint,
  sh_written   bigint,
  tmp_read     bigint,
  tmp_written  bigint,
  heap_fetches bigint
)
LANGUAGE sql AS $$
WITH RECURSIVE t AS (
  SELECT p_plan AS n
  UNION ALL
  SELECT jsonb_array_elements(n->'Plans')
  FROM t
  WHERE n ? 'Plans'
)
SELECT
  COALESCE(SUM((n->>'Shared Hit Blocks')::bigint),0),
  COALESCE(SUM((n->>'Shared Read Blocks')::bigint),0),
  COALESCE(SUM((n->>'Shared Dirtied Blocks')::bigint),0),
  COALESCE(SUM((n->>'Shared Written Blocks')::bigint),0),
  COALESCE(SUM((n->>'Temp Read Blocks')::bigint),0),
  COALESCE(SUM((n->>'Temp Written Blocks')::bigint),0),
  COALESCE(SUM((n->>'Heap Fetches')::bigint),0)
FROM t;
$$;

-- 2) Make sure bench.results has the extra columns we’ll populate
ALTER TABLE bench.results
  ADD COLUMN IF NOT EXISTS heap_fetches bigint,
  ADD COLUMN IF NOT EXISTS plan_hash    text,
  ADD COLUMN IF NOT EXISTS node_type    text,
  ADD COLUMN IF NOT EXISTS index_name   text;

-- 3) bench.run: use sum_buffers(), store heap_fetches, plan_hash, etc.
CREATE OR REPLACE FUNCTION bench.run(
  p_label   TEXT,
  p_variant TEXT,
  p_sql     TEXT,
  p_runs    INT DEFAULT 30,
  p_warmup  INT DEFAULT 2,
  p_seqscan BOOLEAN DEFAULT NULL,
  p_jit     BOOLEAN DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql AS
$$
DECLARE
  i            INT;
  j            JSON;      -- EXPLAIN output (FORMAT JSON)
  root         JSONB;     -- top-level object: {"Plan":{...}, "Planning Time":..., ...}
  root_plan    JSONB;     -- top-level Plan node (may have child Plans[])
  v_planning   NUMERIC;
  v_exec       NUMERIC;
  v_rows       BIGINT;

  -- summed BUFFERS across the tree
  v_sh_hit       BIGINT;
  v_sh_read      BIGINT;
  v_sh_dirty     BIGINT;
  v_sh_written   BIGINT;
  v_tmp_read     BIGINT;
  v_tmp_written  BIGINT;
  v_heap_fetches BIGINT;

  -- handy metadata
  v_node_type TEXT;
  v_index_name TEXT;
  v_plan_hash  TEXT;
  v_plan_for_hash JSONB;
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

  -- Warmups (not recorded)
  FOR i IN 1..GREATEST(p_warmup, 0) LOOP
    EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ' || p_sql INTO j;
  END LOOP;

  -- Recorded runs
  FOR i IN 1..GREATEST(p_runs, 1) LOOP
    EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ' || p_sql INTO j;

    -- Parse once
    root      := (j::jsonb)->0;
    root_plan := root->'Plan';

    v_planning := NULLIF(root->>'Planning Time','')::numeric;
    v_exec     := COALESCE(NULLIF(root->>'Execution Time','')::numeric,
                           NULLIF(root_plan->>'Actual Total Time','')::numeric);
    v_rows     := NULLIF(root_plan->>'Actual Rows','')::bigint;

    -- Sum BUFFERS/Heap Fetches across the entire plan tree
    SELECT sh_hit, sh_read, sh_dirty, sh_written, tmp_read, tmp_written, heap_fetches
      INTO  v_sh_hit, v_sh_read, v_sh_dirty, v_sh_written, v_tmp_read, v_tmp_written, v_heap_fetches
    FROM bench.sum_buffers(root_plan);

    -- Useful metadata from the root
    v_node_type  := root_plan->>'Node Type';
    v_index_name := root_plan->>'Index Name';

    -- Create a "stable-ish" plan hash by removing volatile timing/counter fields at the root.
    -- (Not perfect, but good enough for grouping plan shapes across runs.)
    v_plan_for_hash :=
      jsonb_strip_nulls(
        root_plan
        - 'Actual Total Time'
        - 'Actual Startup Time'
        - 'Actual Rows'
        - 'Actual Loops'
        - 'Plans'           -- child counters vary; hash root shape only
      );
    v_plan_hash := md5(v_plan_for_hash::text);

    INSERT INTO bench.results (
      label, variant, run_no, query_sql, plan_json,
      planning_ms, execution_ms, actual_rows,
      shared_hits, shared_reads, shared_dirtied, shared_written,
      temp_reads, temp_writes,
      heap_fetches, plan_hash, node_type, index_name
    )
    VALUES (
      p_label, p_variant, i, p_sql, j::jsonb,
      v_planning, v_exec, v_rows,
      v_sh_hit, v_sh_read, v_sh_dirty, v_sh_written,
      v_tmp_read, v_tmp_written,
      v_heap_fetches, v_plan_hash, v_node_type, v_index_name
    );
  END LOOP;
END;
$$;

-- 4) Clear function unchanged
CREATE OR REPLACE FUNCTION bench.clear(p_label TEXT) RETURNS VOID
LANGUAGE plpgsql AS
$$
BEGIN
  DELETE FROM bench.results WHERE label = p_label;
END;
$$;

DO $$ BEGIN RAISE NOTICE 'bench functions updated: sum_buffers, run, clear'; END $$;
