\set ON_ERROR_STOP on
\echo 'EXPLAIN ANALYZE for all scenarios (indexed & unindexed)'
SET client_min_messages = warning;
SET jit = off;

-- Helper to separate blocks in output
\set sep '\\n--------------------------------------------------------------------------------\\n'

/****************************
 S1 — Equality + Numeric Inequality
*****************************/
\echo :sep
\echo 'S1 — jsonb_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
  AND ((payload->>'indexed_number_1')::numeric) > 100;

\echo :sep
\echo 'S1 — jsonb_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A'
  AND ((payload->>'unindexed_number_1')::numeric) > 100;

\echo :sep
\echo 'S1 — rel_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_number_1 > 100;

\echo :sep
\echo 'S1 — rel_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A' AND unindexed_number_1 > 100;

/****************************
 S2 — LIKE prefix
*****************************/
\echo :sep
\echo 'S2 — jsonb_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_2') LIKE 'INV00012%';

\echo :sep
\echo 'S2 — jsonb_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_2') LIKE 'INV00012%';

\echo :sep
\echo 'S2 — rel_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE indexed_text_2 LIKE 'INV00012%';

\echo :sep
\echo 'S2 — rel_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE unindexed_text_2 LIKE 'INV00012%';

/****************************
 S3 — Substring contains (ILIKE/trigram)
*****************************/
\echo :sep
\echo 'S3 — jsonb_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_3') ILIKE '%priority%';

\echo :sep
\echo 'S3 — jsonb_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_3') ILIKE '%priority%';

\echo :sep
\echo 'S3 — rel_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE indexed_text_3 ILIKE '%priority%';

\echo :sep
\echo 'S3 — rel_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE unindexed_text_3 ILIKE '%priority%';

/****************************
 S4 — Timestamp range
*****************************/
\echo :sep
\echo 'S4 — jsonb_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_timestamp_1') >= '2025-01-01T00:00:00.000Z'
  AND (payload->>'indexed_timestamp_1') <  '2025-02-01T00:00:00.000Z';

\echo :sep
\echo 'S4 — jsonb_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_timestamp_1') >= '2025-01-01T00:00:00.000Z'
  AND (payload->>'unindexed_timestamp_1') <  '2025-02-01T00:00:00.000Z';

\echo :sep
\echo 'S4 — rel_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE indexed_timestamp_1 >= '2025-01-01 00:00:00+00'
  AND indexed_timestamp_1 <  '2025-02-01 00:00:00+00';

\echo :sep
\echo 'S4 — rel_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE unindexed_timestamp_1 >= '2025-01-01 00:00:00+00'
  AND unindexed_timestamp_1 <  '2025-02-01 00:00:00+00';

/****************************
 S5 — Array AND (contain BOTH)
*****************************/
\echo :sep
\echo 'S5 — jsonb_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE (payload->'indexed_text_array_1') @> '["aml","priority"]'::jsonb;

\echo :sep
\echo 'S5 — jsonb_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE (payload->'unindexed_text_array_1') @> '["aml","priority"]'::jsonb;

\echo :sep
\echo 'S5 — rel_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE indexed_text_array_1 @> ARRAY['aml','priority']::text[];

\echo :sep
\echo 'S5 — rel_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE unindexed_text_array_1 @> ARRAY['aml','priority']::text[];

/****************************
 S6 — Array OR (any overlap)
*****************************/
\echo :sep
\echo 'S6 — jsonb_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE (payload->'indexed_text_array_1') @> '["aml"]'::jsonb
   OR (payload->'indexed_text_array_1') @> '["priority"]'::jsonb;

\echo :sep
\echo 'S6 — jsonb_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE (payload->'unindexed_text_array_1') @> '["aml"]'::jsonb
   OR (payload->'unindexed_text_array_1') @> '["priority"]'::jsonb;

\echo :sep
\echo 'S6 — rel_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE indexed_text_array_1 && ARRAY['aml','priority']::text[];

\echo :sep
\echo 'S6 — rel_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE unindexed_text_array_1 && ARRAY['aml','priority']::text[];

/****************************
 S7 — Multi-key AND (2 keys)
*****************************/
\echo :sep
\echo 'S7 — jsonb_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE payload @> '{"indexed_text_1":"A","indexed_boolean_1":true}';

\echo :sep
\echo 'S7 — jsonb_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE payload @> '{"unindexed_text_1":"A","unindexed_boolean_1":true}';

\echo :sep
\echo 'S7 — rel_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_boolean_1 = true;

\echo :sep
\echo 'S7 — rel_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A' AND unindexed_boolean_1 = true;

/****************************
 S8 — Multi-key AND (3 keys)
*****************************/
\echo :sep
\echo 'S8 — jsonb_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE payload @> '{"indexed_text_1":"A","indexed_boolean_1":true,"indexed_number_1":100}';

\echo :sep
\echo 'S8 — jsonb_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE payload @> '{"unindexed_text_1":"A","unindexed_boolean_1":true,"unindexed_number_1":100}';

\echo :sep
\echo 'S8 — rel_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_boolean_1 = true AND indexed_number_1 = 100;

\echo :sep
\echo 'S8 — rel_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A' AND unindexed_boolean_1 = true AND unindexed_number_1 = 100;

/****************************
 S9 — OR across keys
*****************************/
\echo :sep
\echo 'S9 — jsonb_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE payload @> '{"indexed_text_1":"A"}'
   OR payload @> '{"indexed_boolean_1":true}';

\echo :sep
\echo 'S9 — jsonb_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE payload @> '{"unindexed_text_1":"A"}'
   OR payload @> '{"unindexed_boolean_1":true}';

\echo :sep
\echo 'S9 — rel_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' OR indexed_boolean_1 = true;

\echo :sep
\echo 'S9 — rel_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A' OR unindexed_boolean_1 = true;

/****************************
 S10 — Top-N ordering within group
*****************************/
\echo :sep
\echo 'S10 — jsonb_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
ORDER BY (payload->>'indexed_timestamp_1');

\echo :sep
\echo 'S10 — jsonb_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A'
ORDER BY (payload->>'unindexed_timestamp_1');

\echo :sep
\echo 'S10 — rel_indexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A'
ORDER BY indexed_timestamp_1;

\echo :sep
\echo 'S10 — rel_unindexed'
EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, TIMING off, FORMAT TEXT)
SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A'
ORDER BY unindexed_timestamp_1;
