\set ON_ERROR_STOP on

-- =========================================================
-- Seeds inv_rel + inv_jsonb with identical values
-- Uses a per-batch TEMP TABLE so both inserts share the same rows
-- =========================================================
CREATE OR REPLACE PROCEDURE bench.seed_both(p_rows BIGINT,
                                            p_batch BIGINT DEFAULT 1000000)
LANGUAGE plpgsql AS $proc$
DECLARE
  batch_start BIGINT := 1;
  batch_end   BIGINT;
BEGIN
  PERFORM set_config('synchronous_commit','off', true);
  PERFORM set_config('jit','off', true);
  PERFORM set_config('maintenance_work_mem','2GB', true);
  PERFORM set_config('work_mem','128MB', true);

  TRUNCATE inv_rel, inv_jsonb RESTART IDENTITY;

  WHILE batch_start <= p_rows LOOP
    batch_end := LEAST(batch_start + p_batch - 1, p_rows);

    CREATE TEMP TABLE _gen_tmp ON COMMIT DROP AS
    SELECT g AS n,
           chr(65 + ((g % 26)::int))                               AS t1,
           'INV' || to_char(((g % 10000000)::int), 'FM0000000')    AS t2,
           (ARRAY['priority','kyc','aml','onboard','custody','tax'])
             [ ((g % 6)::int) + 1 ]                                AS t3,

           -- FIXED timestamp generation (no text->interval cast)
           (now() - (interval '1 day' * (random()*365))) AS ts1,
           (now() - (interval '1 day' * (random()*365))) AS ts2,
           (now() - (interval '1 day' * (random()*365))) AS ts3,

           round((random()*1000000)::numeric, 2)          AS num1,
           round((random()*1000000)::numeric, 2)          AS num2,
           round((random()*1000000)::numeric, 2)          AS num3,

           (g % 2 = 0) AS b1,
           (g % 3 = 0) AS b2,
           (g % 5 = 0) AS b3,

           (SELECT ARRAY(
              SELECT t FROM unnest(ARRAY['kyc','aml','custody','onboard','priority','tax']) t
              WHERE (abs(hashtext(t||g::text)) % 100) < 35
            )) AS arr1,
           (SELECT ARRAY(
              SELECT t FROM unnest(ARRAY['grpA','grpB','grpC','grpD']) t
              WHERE (abs(hashtext(t||g::text)) % 100) < 50
            )) AS arr2,
           (SELECT ARRAY(
              SELECT t FROM unnest(ARRAY['X','Y','Z']) t
              WHERE (abs(hashtext(t||g::text)) % 100) < 50
            )) AS arr3
    FROM generate_series(batch_start, batch_end) AS g;

    INSERT INTO inv_rel(
      indexed_text_1, indexed_text_2, indexed_text_3,
      unindexed_text_1, unindexed_text_2, unindexed_text_3,
      indexed_timestamp_1, indexed_timestamp_2, indexed_timestamp_3,
      unindexed_timestamp_1, unindexed_timestamp_2, unindexed_timestamp_3,
      indexed_number_1, indexed_number_2, indexed_number_3,
      unindexed_number_1, unindexed_number_2, unindexed_number_3,
      indexed_text_array_1, indexed_text_array_2, indexed_text_array_3,
      unindexed_text_array_1, unindexed_text_array_2, unindexed_text_array_3,
      indexed_boolean_1, indexed_boolean_2, indexed_boolean_3,
      unindexed_boolean_1, unindexed_boolean_2, unindexed_boolean_3
    )
    SELECT
      t1, t2, t3,
      t1, t2, t3,
      ts1, ts2, ts3,
      ts1, ts2, ts3,
      num1, num2, num3,
      num1, num2, num3,
      arr1, arr2, arr3,
      arr1, arr2, arr3,
      b1, b2, b3,
      b1, b2, b3
    FROM _gen_tmp;

    INSERT INTO inv_jsonb(payload)
    SELECT jsonb_build_object(
      'indexed_text_1', t1,
      'indexed_text_2', t2,
      'indexed_text_3', t3,
      'unindexed_text_1', t1,
      'unindexed_text_2', t2,
      'unindexed_text_3', t3,

      'indexed_timestamp_1', to_char(ts1 AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
      'indexed_timestamp_2', to_char(ts2 AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
      'indexed_timestamp_3', to_char(ts3 AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
      'unindexed_timestamp_1', to_char(ts1 AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
      'unindexed_timestamp_2', to_char(ts2 AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
      'unindexed_timestamp_3', to_char(ts3 AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),

      'indexed_number_1', num1,
      'indexed_number_2', num2,
      'indexed_number_3', num3,
      'unindexed_number_1', num1,
      'unindexed_number_2', num2,
      'unindexed_number_3', num3,

      'indexed_text_array_1', to_jsonb(arr1),
      'indexed_text_array_2', to_jsonb(arr2),
      'indexed_text_array_3', to_jsonb(arr3),
      'unindexed_text_array_1', to_jsonb(arr1),
      'unindexed_text_array_2', to_jsonb(arr2),
      'unindexed_text_array_3', to_jsonb(arr3),

      'indexed_boolean_1', b1,
      'indexed_boolean_2', b2,
      'indexed_boolean_3', b3,
      'unindexed_boolean_1', b1,
      'unindexed_boolean_2', b2,
      'unindexed_boolean_3', b3
    )
    FROM _gen_tmp;

    DROP TABLE IF EXISTS _gen_tmp;
    batch_start := batch_end + 1;
  END LOOP;

  ANALYZE inv_rel;
  ANALYZE inv_jsonb;
END;
$proc$;

-- =========================================================
-- Driver: seed to N and run S1..S10 for all groups
-- =========================================================
-- =========================================================
-- Driver: seed to N and run S1..S10 for all groups
-- =========================================================
CREATE OR REPLACE PROCEDURE bench.run_suite_for_size(
  p_rows   BIGINT,
  p_runs   INT DEFAULT 30,
  p_warmup INT DEFAULT 2,
  p_clear  BOOLEAN DEFAULT false   -- set true to wipe previous results for these labels
)
LANGUAGE plpgsql AS $proc$
DECLARE
  lbl_jsonb_idx   TEXT := format('N=%s jsonb_indexed',   p_rows);
  lbl_jsonb_unidx TEXT := format('N=%s jsonb_unindexed', p_rows);
  lbl_rel_idx     TEXT := format('N=%s rel_indexed',     p_rows);
  lbl_rel_unidx   TEXT := format('N=%s rel_unindexed',   p_rows);
BEGIN
  -- 1) Seed to exact size
  CALL bench.seed_both(p_rows);

  -- 2) Optional: clear previous results for these labels
  IF p_clear THEN
    PERFORM bench.clear(lbl_jsonb_idx);
    PERFORM bench.clear(lbl_jsonb_unidx);
    PERFORM bench.clear(lbl_rel_idx);
    PERFORM bench.clear(lbl_rel_unidx);
  END IF;

  -- =============== S1) Equality text + numeric inequality ===============
  PERFORM bench.run(lbl_jsonb_idx,'S1_expr_eq_num',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->>'indexed_text_1') = 'A'
        AND ((payload->>'indexed_number_1')::numeric) > 100$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_jsonb_unidx,'S1_expr_eq_num',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->>'unindexed_text_1') = 'A'
        AND ((payload->>'unindexed_number_1')::numeric) > 100$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_idx,'S1_expr_eq_num',
    $$SELECT id FROM inv_rel
      WHERE indexed_text_1 = 'A' AND indexed_number_1 > 100$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_unidx,'S1_expr_eq_num',
    $$SELECT id FROM inv_rel
      WHERE unindexed_text_1 = 'A' AND unindexed_number_1 > 100$$,
    p_runs, p_warmup);

  -- =============== S2) LIKE prefix (left-anchored) ===============
  PERFORM bench.run(lbl_jsonb_idx,'S2_like_prefix',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->>'indexed_text_2') LIKE 'INV00012%'$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_jsonb_unidx,'S2_like_prefix',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->>'unindexed_text_2') LIKE 'INV00012%'$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_idx,'S2_like_prefix',
    $$SELECT id FROM inv_rel
      WHERE indexed_text_2 LIKE 'INV00012%'$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_unidx,'S2_like_prefix',
    $$SELECT id FROM inv_rel
      WHERE unindexed_text_2 LIKE 'INV00012%'$$,
    p_runs, p_warmup);

  -- =============== S3) Substring contains (ILIKE '%…%') / trigram ===============
  PERFORM bench.run(lbl_jsonb_idx,'S3_trgm_contains',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->>'indexed_text_3') ILIKE '%priority%'$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_jsonb_unidx,'S3_trgm_contains',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->>'unindexed_text_3') ILIKE '%priority%'$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_idx,'S3_trgm_contains',
    $$SELECT id FROM inv_rel
      WHERE indexed_text_3 ILIKE '%priority%'$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_unidx,'S3_trgm_contains',
    $$SELECT id FROM inv_rel
      WHERE unindexed_text_3 ILIKE '%priority%'$$,
    p_runs, p_warmup);

  -- =============== S4) Timestamp range ===============
  PERFORM bench.run(lbl_jsonb_idx,'S4_ts_range',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->>'indexed_timestamp_1') >= '2025-01-01T00:00:00.000Z'
        AND (payload->>'indexed_timestamp_1') <  '2025-02-01T00:00:00.000Z'$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_jsonb_unidx,'S4_ts_range',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->>'unindexed_timestamp_1') >= '2025-01-01T00:00:00.000Z'
        AND (payload->>'unindexed_timestamp_1') <  '2025-02-01T00:00:00.000Z'$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_idx,'S4_ts_range',
    $$SELECT id FROM inv_rel
      WHERE indexed_timestamp_1 >= '2025-01-01 00:00:00+00'
        AND indexed_timestamp_1 <  '2025-02-01 00:00:00+00'$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_unidx,'S4_ts_range',
    $$SELECT id FROM inv_rel
      WHERE unindexed_timestamp_1 >= '2025-01-01 00:00:00+00'
        AND unindexed_timestamp_1 <  '2025-02-01 00:00:00+00'$$,
    p_runs, p_warmup);

  -- =============== S5) Array AND (contain BOTH) ===============
  PERFORM bench.run(lbl_jsonb_idx,'S5_array_and',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->'indexed_text_array_1') @> '["aml","priority"]'::jsonb$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_jsonb_unidx,'S5_array_and',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->'unindexed_text_array_1') @> '["aml","priority"]'::jsonb$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_idx,'S5_array_and',
    $$SELECT id FROM inv_rel
      WHERE indexed_text_array_1 @> ARRAY['aml','priority']::text[]$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_unidx,'S5_array_and',
    $$SELECT id FROM inv_rel
      WHERE unindexed_text_array_1 @> ARRAY['aml','priority']::text[]$$,
    p_runs, p_warmup);

  -- =============== S6) Array OR (any overlap) ===============
  PERFORM bench.run(lbl_jsonb_idx,'S6_array_or',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->'indexed_text_array_1') @> '["aml"]'::jsonb
         OR (payload->'indexed_text_array_1') @> '["priority"]'::jsonb$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_jsonb_unidx,'S6_array_or',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->'unindexed_text_array_1') @> '["aml"]'::jsonb
         OR (payload->'unindexed_text_array_1') @> '["priority"]'::jsonb$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_idx,'S6_array_or',
    $$SELECT id FROM inv_rel
      WHERE indexed_text_array_1 && ARRAY['aml','priority']::text[]$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_unidx,'S6_array_or',
    $$SELECT id FROM inv_rel
      WHERE unindexed_text_array_1 && ARRAY['aml','priority']::text[]$$,
    p_runs, p_warmup);

  -- =============== S7) Multi-key AND (2 keys) ===============
  -- JSONB containment form commented out when GIN(jsonb_path_ops) isn’t available.
  PERFORM bench.run(lbl_jsonb_idx,'S7_and2',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->>'indexed_text_1') = 'A'
        AND ((payload->>'indexed_boolean_1')::boolean) IS TRUE$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_jsonb_unidx,'S7_and2',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->>'unindexed_text_1') = 'A'
        AND ((payload->>'unindexed_boolean_1')::boolean) IS TRUE$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_idx,'S7_and2',
    $$SELECT id FROM inv_rel
      WHERE indexed_text_1 = 'A' AND indexed_boolean_1 = true$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_unidx,'S7_and2',
    $$SELECT id FROM inv_rel
      WHERE unindexed_text_1 = 'A' AND unindexed_boolean_1 = true$$,
    p_runs, p_warmup);

  -- =============== S8) Multi-key AND (3 keys) ===============
  PERFORM bench.run(lbl_jsonb_idx,'S8_and3',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->>'indexed_text_1') = 'A'
        AND ((payload->>'indexed_boolean_1')::boolean) IS TRUE
        AND ((payload->>'indexed_number_1')::numeric) = 100::numeric$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_jsonb_unidx,'S8_and3',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->>'unindexed_text_1') = 'A'
        AND ((payload->>'unindexed_boolean_1')::boolean) IS TRUE
        AND ((payload->>'unindexed_number_1')::numeric) = 100::numeric$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_idx,'S8_and3',
    $$SELECT id FROM inv_rel
      WHERE indexed_text_1 = 'A' AND indexed_boolean_1 = true AND indexed_number_1 = 100$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_unidx,'S8_and3',
    $$SELECT id FROM inv_rel
      WHERE unindexed_text_1 = 'A' AND unindexed_boolean_1 = true AND unindexed_number_1 = 100$$,
    p_runs, p_warmup);

  -- =============== S9) OR across keys ===============
  PERFORM bench.run(lbl_jsonb_idx,'S9_or_keys',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->>'indexed_text_1') = 'A'
         OR ((payload->>'indexed_boolean_1')::boolean) IS TRUE$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_jsonb_unidx,'S9_or_keys',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->>'unindexed_text_1') = 'A'
         OR ((payload->>'unindexed_boolean_1')::boolean) IS TRUE$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_idx,'S9_or_keys',
    $$SELECT id FROM inv_rel
      WHERE indexed_text_1 = 'A' OR indexed_boolean_1 = true$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_unidx,'S9_or_keys',
    $$SELECT id FROM inv_rel
      WHERE unindexed_text_1 = 'A' OR unindexed_boolean_1 = true$$,
    p_runs, p_warmup);

  -- =============== S10) Top-N ordering within a group ===============
  PERFORM bench.run(lbl_jsonb_idx,'S10_topn_order',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->>'indexed_text_1') = 'A'
      ORDER BY (payload->>'indexed_timestamp_1')$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_jsonb_unidx,'S10_topn_order',
    $$SELECT id FROM inv_jsonb
      WHERE (payload->>'unindexed_text_1') = 'A'
      ORDER BY (payload->>'unindexed_timestamp_1')$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_idx,'S10_topn_order',
    $$SELECT id FROM inv_rel
      WHERE indexed_text_1 = 'A'
      ORDER BY indexed_timestamp_1$$,
    p_runs, p_warmup);

  PERFORM bench.run(lbl_rel_unidx,'S10_topn_order',
    $$SELECT id FROM inv_rel
      WHERE unindexed_text_1 = 'A'
      ORDER BY unindexed_timestamp_1$$,
    p_runs, p_warmup);

END;
$proc$;



DO $$ BEGIN RAISE NOTICE 'bench procedures created/updated: seed_both, run_suite_for_size'; END $$;
