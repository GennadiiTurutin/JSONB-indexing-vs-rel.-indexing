\set ON_ERROR_STOP on

/* =============================================================================
   Benchmark query registration
   - Each scenario runs four variants under these labels:
       'jsonb_indexed', 'jsonb_unindexed', 'rel_indexed', 'rel_unindexed'
   - Use bench.summary to compare p50/p95/avg afterwards.
   - Notes:
     * JSONB timestamps are ISO8601 strings; comparisons are lexicographic.
     * JSONB containment uses the GIN(jsonb_path_ops) index.
     * Trigram cases assume pg_trgm + GIN(trgm_ops).
     * Array semantics:
         AND  = must contain ALL values  → @> (rel arrays and JSONB arrays)
         OR   = any overlap              → && (rel arrays) / OR of @> (JSONB)
   ========================================================================== */

-- start with a clean slate for these labels (safe to keep/comment)
SELECT bench.clear('jsonb_indexed');
SELECT bench.clear('jsonb_unindexed');
SELECT bench.clear('rel_indexed');
SELECT bench.clear('rel_unindexed');


/* ============================================================================
   S1) Equality on text + numeric inequality
   Purpose: classic selective predicate on two fields.

   Example (manual):
     -- JSONB:
     SELECT id FROM inv_jsonb
     WHERE (payload->>'indexed_text_1') = 'A'
       AND ((payload->>'indexed_number_1')::numeric) > 100;

     -- Relational:
     SELECT id FROM inv_rel
     WHERE indexed_text_1 = 'A' AND indexed_number_1 > 100;
   ========================================================================== */
SELECT bench.run('jsonb_indexed','S1_expr_eq_num',
$$SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
AND ((payload->>'indexed_number_1')::numeric) > 100$$);

SELECT bench.run('jsonb_unindexed','S1_expr_eq_num',
$$SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A'
AND ((payload->>'unindexed_number_1')::numeric) > 100$$);

SELECT bench.run('rel_indexed','S1_expr_eq_num',
$$SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_number_1 > 100$$);

SELECT bench.run('rel_unindexed','S1_expr_eq_num',
$$SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A' AND unindexed_number_1 > 100$$);



/* ============================================================================
   S2) LIKE prefix (left-anchored)
   Purpose: measure pattern_ops / btree LIKE behavior vs JSONB expression.

   Example (manual):
     -- JSONB:
     SELECT id FROM inv_jsonb
     WHERE (payload->>'indexed_text_2') LIKE 'INV00012%';

     -- Relational:
     SELECT id FROM inv_rel
     WHERE indexed_text_2 LIKE 'INV00012%';
   ========================================================================== */
SELECT bench.run('jsonb_indexed','S2_like_prefix',
$$SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_2') LIKE 'INV00012%'$$);

SELECT bench.run('jsonb_unindexed','S2_like_prefix',
$$SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_2') LIKE 'INV00012%'$$);

SELECT bench.run('rel_indexed','S2_like_prefix',
$$SELECT id FROM inv_rel
WHERE indexed_text_2 LIKE 'INV00012%'$$);

SELECT bench.run('rel_unindexed','S2_like_prefix',
$$SELECT id FROM inv_rel
WHERE unindexed_text_2 LIKE 'INV00012%'$$);



/* ============================================================================
   S3) Substring contains (ILIKE '%...%') via trigram
   Purpose: full substring search.

   Example (manual):
     -- JSONB:
     SELECT id FROM inv_jsonb
     WHERE (payload->>'indexed_text_3') ILIKE '%priority%';

     -- Relational:
     SELECT id FROM inv_rel
     WHERE indexed_text_3 ILIKE '%priority%';
   ========================================================================== */
SELECT bench.run('jsonb_indexed','S3_trgm_contains',
$$SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_3') ILIKE '%priority%'$$);

SELECT bench.run('jsonb_unindexed','S3_trgm_contains',
$$SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_3') ILIKE '%priority%'$$);

SELECT bench.run('rel_indexed','S3_trgm_contains',
$$SELECT id FROM inv_rel
WHERE indexed_text_3 ILIKE '%priority%'$$);

SELECT bench.run('rel_unindexed','S3_trgm_contains',
$$SELECT id FROM inv_rel
WHERE unindexed_text_3 ILIKE '%priority%'$$);



/* ============================================================================
   S4) Timestamp range
   Purpose: range scan on time. JSONB uses ISO8601 string (lexicographic).

   Example (manual):
     -- JSONB:
     SELECT id FROM inv_jsonb
     WHERE (payload->>'indexed_timestamp_1') >= '2025-01-01T00:00:00.000Z'
       AND (payload->>'indexed_timestamp_1') <  '2025-02-01T00:00:00.000Z';

     -- Relational:
     SELECT id FROM inv_rel
     WHERE indexed_timestamp_1 >= '2025-01-01 00:00:00+00'
       AND indexed_timestamp_1 <  '2025-02-01 00:00:00+00';
   ========================================================================== */
SELECT bench.run('jsonb_indexed','S4_ts_range',
$$SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_timestamp_1') >= '2025-01-01T00:00:00.000Z'
AND (payload->>'indexed_timestamp_1') <  '2025-02-01T00:00:00.000Z'$$);

SELECT bench.run('jsonb_unindexed','S4_ts_range',
$$SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_timestamp_1') >= '2025-01-01T00:00:00.000Z'
AND (payload->>'unindexed_timestamp_1') <  '2025-02-01T00:00:00.000Z'$$);

SELECT bench.run('rel_indexed','S4_ts_range',
$$SELECT id FROM inv_rel
WHERE indexed_timestamp_1 >= '2025-01-01 00:00:00+00'
AND indexed_timestamp_1 <  '2025-02-01 00:00:00+00'$$);

SELECT bench.run('rel_unindexed','S4_ts_range',
$$SELECT id FROM inv_rel
WHERE unindexed_timestamp_1 >= '2025-01-01 00:00:00+00'
AND unindexed_timestamp_1 <  '2025-02-01 00:00:00+00'$$);



/* ============================================================================
   S5) Array AND (must contain BOTH 'aml' and 'priority')
   Purpose: containment semantics.

   Example (manual):
     -- JSONB:
     SELECT id FROM inv_jsonb
     WHERE (payload->'indexed_text_array_1') @> '["aml","priority"]'::jsonb;

     -- Relational:
     SELECT id FROM inv_rel
     WHERE indexed_text_array_1 @> ARRAY['aml','priority']::text[];
   ========================================================================== */
SELECT bench.run('jsonb_indexed','S5_array_and',
$$SELECT id FROM inv_jsonb
WHERE (payload->'indexed_text_array_1') @> '["aml","priority"]'::jsonb$$);

SELECT bench.run('jsonb_unindexed','S5_array_and',
$$SELECT id FROM inv_jsonb
WHERE (payload->'unindexed_text_array_1') @> '["aml","priority"]'::jsonb$$);

SELECT bench.run('rel_indexed','S5_array_and',
$$SELECT id FROM inv_rel
WHERE indexed_text_array_1 @> ARRAY['aml','priority']::text[]$$);

SELECT bench.run('rel_unindexed','S5_array_and',
$$SELECT id FROM inv_rel
WHERE unindexed_text_array_1 @> ARRAY['aml','priority']::text[]$$);


/* ============================================================================
   S6) Array OR (any overlap with {'aml','priority'})
   Purpose: overlap semantics (broader predicate than S5).

   Example (manual):
     -- JSONB (OR of containments):
     SELECT id FROM inv_jsonb
     WHERE (payload->'indexed_text_array_1') @> '["aml"]'::jsonb
        OR (payload->'indexed_text_array_1') @> '["priority"]'::jsonb;

     -- Relational (overlap operator):
     SELECT id FROM inv_rel
     WHERE indexed_text_array_1 && ARRAY['aml','priority']::text[];
   ========================================================================== */
SELECT bench.run('jsonb_indexed','S6_array_or',
$$SELECT id FROM inv_jsonb
WHERE (payload->'indexed_text_array_1') @> '["aml"]'::jsonb
OR (payload->'indexed_text_array_1') @> '["priority"]'::jsonb$$);

SELECT bench.run('jsonb_unindexed','S6_array_or',
$$SELECT id FROM inv_jsonb
WHERE (payload->'unindexed_text_array_1') @> '["aml"]'::jsonb
OR (payload->'unindexed_text_array_1') @> '["priority"]'::jsonb$$);

SELECT bench.run('rel_indexed','S6_array_or',
$$SELECT id FROM inv_rel
WHERE indexed_text_array_1 && ARRAY['aml','priority']::text[]$$);

SELECT bench.run('rel_unindexed','S6_array_or',
$$SELECT id FROM inv_rel
WHERE unindexed_text_array_1 && ARRAY['aml','priority']::text[]$$);



/* ============================================================================
   S7) Multi-key AND (two keys)
   Purpose: compare JSONB containment with two pairs vs column equality AND.

   Example (manual):
     -- JSONB (single @> with two pairs → one GIN probe):
     SELECT id FROM inv_jsonb
     WHERE payload @> '{"indexed_text_1":"A","indexed_boolean_1":true}';

     -- Relational:
     SELECT id FROM inv_rel
     WHERE indexed_text_1 = 'A' AND indexed_boolean_1 = true;
   ========================================================================== */
-- cannot be used without indexes, as it cannot use GIN(jsonb_path_ops)
-- SELECT bench.run('jsonb_indexed','S7_and2',
-- $$SELECT id FROM inv_jsonb
-- WHERE payload @> '{"indexed_text_1":"A","indexed_boolean_1":true}'$$);

SELECT bench.run('jsonb_indexed','S7_and2',
$$SELECT id FROM inv_jsonb 
WHERE (payload->>'indexed_text_1') = 'A' AND ((payload->>'indexed_boolean_1')::boolean) IS TRUE;
$$);

-- cannot be used without indexes, as it cannot use GIN(jsonb_path_ops)
-- SELECT bench.run('jsonb_unindexed','S7_and2',
-- $$SELECT id FROM inv_jsonb
-- WHERE payload @> '{"unindexed_text_1":"A","unindexed_boolean_1":true}'$$);

-- S7_and2 : unindexed fields (functionally the same, will scan without indexes)
SELECT bench.run('jsonb_unindexed','S7_and2',
$$ SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A' AND ((payload->>'unindexed_boolean_1')::boolean) IS TRUE;
$$);

SELECT bench.run('rel_indexed','S7_and2',
$$SELECT id FROM inv_rel WHERE indexed_text_1 = 'A' AND indexed_boolean_1 = true$$);

SELECT bench.run('rel_unindexed','S7_and2',
$$SELECT id FROM inv_rel WHERE unindexed_text_1 = 'A' AND unindexed_boolean_1 = true$$);



/* ============================================================================
   S8) Multi-key AND (three keys: text + boolean + number)
   Purpose: higher selectivity with three fields.

   Example (manual):
     -- JSONB:
     SELECT id FROM inv_jsonb
     WHERE payload @> '{"indexed_text_1":"A","indexed_boolean_1":true,"indexed_number_1":100}';

     -- Relational:
     SELECT id FROM inv_rel
     WHERE indexed_text_1 = 'A' AND indexed_boolean_1 = true AND indexed_number_1 = 100;
   ========================================================================== */

-- cannot be used without indexes, as it cannot use GIN(jsonb_path_ops)
-- SELECT bench.run('jsonb_indexed','S8_and3',
-- $$SELECT id FROM inv_jsonb
-- WHERE payload @> '{"indexed_text_1":"A","indexed_boolean_1":true,"indexed_number_1":100}'$$);

SELECT bench.run('jsonb_indexed','S8_and3',
$$SELECT id
FROM inv_jsonb WHERE (payload->>'indexed_text_1') = 'A' AND ((payload->>'indexed_boolean_1')::boolean) IS TRUE AND ((payload->>'indexed_number_1')::numeric) = 100::numeric;
$$); 

-- cannot be used without indexes, as it cannot use GIN(jsonb_path_ops)
-- SELECT bench.run('jsonb_unindexed','S8_and3',
-- $$SELECT id FROM inv_jsonb
-- WHERE payload @> '{"unindexed_text_1":"A","unindexed_boolean_1":true,"unindexed_number_1":100}'$$);

SELECT bench.run('jsonb_unindexed','S8_and3',
$$SELECT id
FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A' AND ((payload->>'unindexed_boolean_1')::boolean) IS TRUE AND ((payload->>'unindexed_number_1')::numeric) = 100::numeric;
$$);


SELECT bench.run('rel_indexed','S8_and3',
$$SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_boolean_1 = true AND indexed_number_1 = 100$$);

SELECT bench.run('rel_unindexed','S8_and3',
$$SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A' AND unindexed_boolean_1 = true AND unindexed_number_1 = 100$$);


/* ============================================================================
   S9) OR across keys
   Purpose: broader retrieval via OR of selective predicates.

   Example (manual):
     -- JSONB (BitmapOr of two @> probes):
     SELECT id FROM inv_jsonb
     WHERE payload @> '{"indexed_text_1":"A"}'
        OR payload @> '{"indexed_boolean_1":true}';

     -- Relational (OR of two indexed columns):
     SELECT id FROM inv_rel
     WHERE indexed_text_1 = 'A' OR indexed_boolean_1 = true;
   ========================================================================== */

-- cannot be used without indexes, as it cannot use GIN(jsonb_path_ops)
-- SELECT bench.run('jsonb_indexed','S9_or_keys',
-- $$SELECT id FROM inv_jsonb
--   WHERE payload @> '{"indexed_text_1":"A"}'
--      OR payload @> '{"indexed_boolean_1":true}'$$);

SELECT bench.run('jsonb_indexed','S9_or_keys',
$$ SELECT id
FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A' OR ((payload->>'indexed_boolean_1')::boolean) IS TRUE;
$$);

-- cannot be used without indexes, as it cannot use GIN(jsonb_path_ops)
-- SELECT bench.run('jsonb_unindexed','S9_or_keys',
-- $$SELECT id FROM inv_jsonb
-- WHERE payload @> '{"unindexed_text_1":"A"}' OR payload @> '{"unindexed_boolean_1":true}'$$);

-- S9_or_keys : unindexed fields (functionally same; will still scan without indexes)
SELECT bench.run('jsonb_unindexed','S9_or_keys',
$$ SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A' OR ((payload->>'unindexed_boolean_1')::boolean) IS TRUE;
$$);

SELECT bench.run('rel_indexed','S9_or_keys',
$$SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' OR indexed_boolean_1 = true$$);

SELECT bench.run('rel_unindexed','S9_or_keys',
$$SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A' OR unindexed_boolean_1 = true$$);



/* ============================================================================
   S10) Top-N ordering within a group
   Purpose: ORDER BY compatibility and index support.

   Example (manual):
     -- JSONB:
     SELECT id FROM inv_jsonb
     WHERE (payload->>'indexed_text_1') = 'A'
     ORDER BY (payload->>'indexed_timestamp_1');

     -- Relational:
     SELECT id FROM inv_rel
     WHERE indexed_text_1 = 'A'
     ORDER BY indexed_timestamp_1;
   ========================================================================== */
SELECT bench.run('jsonb_indexed','S10_topn_order',
$$SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
ORDER BY (payload->>'indexed_timestamp_1')$$);

SELECT bench.run('jsonb_unindexed','S10_topn_order',
$$SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A'
ORDER BY (payload->>'unindexed_timestamp_1')$$);

SELECT bench.run('rel_indexed','S10_topn_order',
$$SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A'
ORDER BY indexed_timestamp_1$$);

SELECT bench.run('rel_unindexed','S10_topn_order',
$$SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A'
ORDER BY unindexed_timestamp_1$$);


/* =============================================================================
   After running this file:
     SELECT * FROM bench.summary
     WHERE label IN ('jsonb_indexed','jsonb_unindexed','rel_indexed','rel_unindexed')
     ORDER BY label, variant;

   To inspect plans for one scenario:
     SELECT run_no, execution_ms, jsonb_pretty(plan_json)
     FROM bench.results
     WHERE label='jsonb_indexed' AND variant='S7_and2'
     ORDER BY run_no;

   To re-run cleanly later:
     SELECT bench.clear('jsonb_indexed');
     SELECT bench.clear('jsonb_unindexed');
     SELECT bench.clear('rel_indexed');
     SELECT bench.clear('rel_unindexed');
============================================================================= */
