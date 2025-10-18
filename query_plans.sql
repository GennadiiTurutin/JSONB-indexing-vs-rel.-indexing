-- =============== S1) Equality text + numeric inequality ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
  AND ((payload->>'indexed_number_1')::numeric) > 100;
"Bitmap Heap Scan on inv_jsonb  (cost=243.99..38528.54 rows=39596 width=8) (actual time=14.798..111.945 rows=38458 loops=1)"
"  Recheck Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"  Filter: (((payload ->> 'indexed_number_1'::text))::numeric > '100'::numeric)"
"  Rows Removed by Filter: 3"
"  Heap Blocks: exact=38452"
"  Buffers: shared hit=38492"
"  ->  Bitmap Index Scan on inv_jsonb_idx_text_1_trgm  (cost=0.00..234.09 rows=39600 width=0) (actual time=7.710..7.711 rows=38461 loops=1)"
"        Index Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"        Buffers: shared hit=40"
"Planning:"
"  Buffers: shared hit=5"
"Planning Time: 0.194 ms"
"Execution Time: 114.185 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A'
  AND ((payload->>'unindexed_number_1')::numeric) > 100;
"Seq Scan on inv_jsonb  (cost=0.00..191339.00 rows=1667 width=8) (actual time=0.033..599.515 rows=38458 loops=1)"
"  Filter: (((payload ->> 'unindexed_text_1'::text) = 'A'::text) AND (((payload ->> 'unindexed_number_1'::text))::numeric > '100'::numeric))"
"  Rows Removed by Filter: 961542"
"  Buffers: shared hit=166339"
"Planning Time: 0.128 ms"
"Execution Time: 602.005 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_number_1 > 100;
"Index Only Scan using inv_rel_idx_text1_bl1_num1 on inv_rel  (cost=0.42..1049.18 rows=38796 width=8) (actual time=0.038..13.321 rows=38458 loops=1)"
"  Index Cond: ((indexed_text_1 = 'A'::text) AND (indexed_number_1 > '100'::numeric))"
"  Heap Fetches: 0"
"  Buffers: shared hit=18025"
"Planning:"
"  Buffers: shared hit=5"
"Planning Time: 0.199 ms"
"Execution Time: 14.996 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A' AND unindexed_number_1 > 100;
"Seq Scan on inv_rel  (cost=0.00..66613.00 rows=38796 width=8) (actual time=0.025..322.727 rows=38458 loops=1)"
"  Filter: ((unindexed_number_1 > '100'::numeric) AND (unindexed_text_1 = 'A'::text))"
"  Rows Removed by Filter: 961542"
"  Buffers: shared hit=51613"
"Planning Time: 0.129 ms"
"Execution Time: 325.204 ms"

-- =============== S2) LIKE prefix (left-anchored) ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_2') LIKE 'INV00012%';
"Index Scan using inv_jsonb_idx_text_2_like on inv_jsonb  (cost=0.42..2.65 rows=100 width=8) (actual time=0.021..0.092 rows=100 loops=1)"
"  Index Cond: (((payload ->> 'indexed_text_2'::text) ~>=~ 'INV00012'::text) AND ((payload ->> 'indexed_text_2'::text) ~<~ 'INV00013'::text))"
"  Filter: ((payload ->> 'indexed_text_2'::text) ~~ 'INV00012%'::text)"
"  Buffers: shared hit=22"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.164 ms"
"Execution Time: 0.109 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_2') LIKE 'INV00012%';
"Seq Scan on inv_jsonb  (cost=0.00..181339.00 rows=5000 width=8) (actual time=0.593..521.805 rows=100 loops=1)"
"  Filter: ((payload ->> 'unindexed_text_2'::text) ~~ 'INV00012%'::text)"
"  Rows Removed by Filter: 999900"
"  Buffers: shared hit=166339"
"Planning Time: 0.267 ms"
"Execution Time: 521.825 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_2 LIKE 'INV00012%';
"Index Only Scan using inv_rel_idx_text_2_like on inv_rel  (cost=0.42..1.55 rows=100 width=8) (actual time=0.019..0.042 rows=100 loops=1)"
"  Index Cond: ((indexed_text_2 ~>=~ 'INV00012'::text) AND (indexed_text_2 ~<~ 'INV00013'::text))"
"  Filter: (indexed_text_2 ~~ 'INV00012%'::text)"
"  Heap Fetches: 0"
"  Buffers: shared hit=5"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.148 ms"
"Execution Time: 0.059 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_2 LIKE 'INV00012%';
"Seq Scan on inv_rel  (cost=0.00..64113.00 rows=100 width=8) (actual time=0.530..190.962 rows=100 loops=1)"
"  Filter: (unindexed_text_2 ~~ 'INV00012%'::text)"
"  Rows Removed by Filter: 999900"
"  Buffers: shared hit=51613"
"Planning Time: 0.105 ms"
"Execution Time: 190.981 ms"


-- =============== S3) Substring contains (ILIKE '%…%') / trigram ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_3') ILIKE '%priority%';
"Bitmap Heap Scan on inv_jsonb  (cost=1265.37..116235.29 rows=165333 width=8) (actual time=116.129..506.199 rows=166666 loops=1)"
"  Recheck Cond: ((payload ->> 'indexed_text_3'::text) ~~* '%priority%'::text)"
"  Heap Blocks: exact=166338"
"  Buffers: shared hit=166874"
"  ->  Bitmap Index Scan on inv_jsonb_idx_text_3_trgm  (cost=0.00..1224.04 rows=165333 width=0) (actual time=68.938..68.939 rows=166666 loops=1)"
"        Index Cond: ((payload ->> 'indexed_text_3'::text) ~~* '%priority%'::text)"
"        Buffers: shared hit=536"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.140 ms"
"Execution Time: 518.572 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_3') ILIKE '%priority%';
"Seq Scan on inv_jsonb  (cost=0.00..181339.00 rows=100 width=8) (actual time=0.024..1266.800 rows=166666 loops=1)"
"  Filter: ((payload ->> 'unindexed_text_3'::text) ~~* '%priority%'::text)"
"  Rows Removed by Filter: 833334"
"  Buffers: shared hit=166339"
"Planning Time: 0.100 ms"
"Execution Time: 1277.634 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_3 ILIKE '%priority%';
"Index Only Scan using inv_rel_idx_text_3_like on inv_rel  (cost=0.42..21668.33 rows=172300 width=8) (actual time=510.956..777.272 rows=166666 loops=1)"
"  Filter: (indexed_text_3 ~~* '%priority%'::text)"
"  Rows Removed by Filter: 833334"
"  Heap Fetches: 0"
"  Buffers: shared hit=3776"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.133 ms"
"Execution Time: 784.407 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_3 ILIKE '%priority%';
"Seq Scan on inv_rel  (cost=0.00..64113.00 rows=172300 width=8) (actual time=0.019..907.587 rows=166666 loops=1)"
"  Filter: (unindexed_text_3 ~~* '%priority%'::text)"
"  Rows Removed by Filter: 833334"
"  Buffers: shared hit=51613"
"Planning Time: 0.112 ms"
"Execution Time: 917.423 ms"


-- =============== S4) Timestamp range ===============
-- (JSONB compares ISO strings with COLLATE "C", as in your original)
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_timestamp_1') COLLATE "C" >= '2025-01-01T00:00:00.000Z'
  AND (payload->>'indexed_timestamp_1') COLLATE "C" <  '2025-02-01T00:00:00.000Z';
"Bitmap Heap Scan on inv_jsonb  (cost=1851.31..76948.32 rows=89999 width=8) (actual time=25.705..109.209 rows=85057 loops=1)"
"  Recheck Cond: ((((payload ->> 'indexed_timestamp_1'::text))::text >= '2025-01-01T00:00:00.000Z'::text) AND (((payload ->> 'indexed_timestamp_1'::text))::text < '2025-02-01T00:00:00.000Z'::text))"
"  Heap Blocks: exact=68674"
"  Buffers: shared hit=69440"
"  ->  Bitmap Index Scan on inv_jsonb_idx_ts_1_txt  (cost=0.00..1828.82 rows=89999 width=0) (actual time=11.909..11.909 rows=85057 loops=1)"
"        Index Cond: ((((payload ->> 'indexed_timestamp_1'::text))::text >= '2025-01-01T00:00:00.000Z'::text) AND (((payload ->> 'indexed_timestamp_1'::text))::text < '2025-02-01T00:00:00.000Z'::text))"
"        Buffers: shared hit=766"
"Planning:"
"  Buffers: shared hit=4"
"Planning Time: 0.186 ms"
"Execution Time: 112.958 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_timestamp_1') COLLATE "C" >= '2025-01-01T00:00:00.000Z'
  AND (payload->>'unindexed_timestamp_1') COLLATE "C" <  '2025-02-01T00:00:00.000Z';
"Seq Scan on inv_jsonb  (cost=0.00..186339.00 rows=5000 width=8) (actual time=0.022..894.044 rows=85057 loops=1)"
"  Filter: ((((payload ->> 'unindexed_timestamp_1'::text))::text >= '2025-01-01T00:00:00.000Z'::text) AND (((payload ->> 'unindexed_timestamp_1'::text))::text < '2025-02-01T00:00:00.000Z'::text))"
"  Rows Removed by Filter: 914943"
"  Buffers: shared hit=166339"
"Planning Time: 0.108 ms"
"Execution Time: 898.856 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_timestamp_1 >= timestamptz '2025-01-01 00:00:00+00'
  AND indexed_timestamp_1 <  timestamptz '2025-02-01 00:00:00+00';
"Index Only Scan using inv_rel_idx_ts_1 on inv_rel  (cost=0.42..2176.93 rows=85615 width=8) (actual time=0.094..18.548 rows=85057 loops=1)"
"  Index Cond: ((indexed_timestamp_1 >= '2025-01-01 00:00:00+00'::timestamp with time zone) AND (indexed_timestamp_1 < '2025-02-01 00:00:00+00'::timestamp with time zone))"
"  Heap Fetches: 0"
"  Buffers: shared hit=39821"
"Planning:"
"  Buffers: shared hit=4"
"Planning Time: 0.221 ms"
"Execution Time: 22.394 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_timestamp_1 >= timestamptz '2025-01-01 00:00:00+00'
  AND unindexed_timestamp_1 <  timestamptz '2025-02-01 00:00:00+00';
"Seq Scan on inv_rel  (cost=0.00..66613.00 rows=85515 width=8) (actual time=0.014..208.231 rows=85057 loops=1)"
"  Filter: ((unindexed_timestamp_1 >= '2025-01-01 00:00:00+00'::timestamp with time zone) AND (unindexed_timestamp_1 < '2025-02-01 00:00:00+00'::timestamp with time zone))"
"  Rows Removed by Filter: 914943"
"  Buffers: shared hit=51613"
"Planning Time: 0.109 ms"
"Execution Time: 212.086 ms"

-- =============== S5) Array AND (contain BOTH) ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->'indexed_text_array_1') @> '["aml","priority"]'::jsonb;
"Bitmap Heap Scan on inv_jsonb  (cost=806.06..95391.78 rows=124033 width=8) (actual time=82.317..279.147 rows=123132 loops=1)"
"  Recheck Cond: ((payload -> 'indexed_text_array_1'::text) @> '[""aml"", ""priority""]'::jsonb)"
"  Heap Blocks: exact=90837"
"  Buffers: shared hit=91019"
"  ->  Bitmap Index Scan on inv_jsonb_idx_text_arr_1_gin  (cost=0.00..775.05 rows=124033 width=0) (actual time=58.572..58.573 rows=123132 loops=1)"
"        Index Cond: ((payload -> 'indexed_text_array_1'::text) @> '[""aml"", ""priority""]'::jsonb)"
"        Buffers: shared hit=182"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.161 ms"
"Execution Time: 284.748 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->'unindexed_text_array_1') @> '["aml","priority"]'::jsonb;
"Seq Scan on inv_jsonb  (cost=0.00..181339.00 rows=10000 width=8) (actual time=0.015..720.082 rows=123132 loops=1)"
"  Filter: ((payload -> 'unindexed_text_array_1'::text) @> '[""aml"", ""priority""]'::jsonb)"
"  Rows Removed by Filter: 876868"
"  Buffers: shared hit=166339"
"Planning Time: 0.097 ms"
"Execution Time: 726.332 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_array_1 @> ARRAY['aml','priority']::text[];
"Bitmap Heap Scan on inv_rel  (cost=794.10..53987.37 rows=126422 width=8) (actual time=49.360..115.848 rows=123132 loops=1)"
"  Recheck Cond: (indexed_text_array_1 @> '{aml,priority}'::text[])"
"  Heap Blocks: exact=47613"
"  Buffers: shared hit=47767"
"  ->  Bitmap Index Scan on inv_rel_idx_text_arr_1  (cost=0.00..762.49 rows=126422 width=0) (actual time=41.213..41.213 rows=123132 loops=1)"
"        Index Cond: (indexed_text_array_1 @> '{aml,priority}'::text[])"
"        Buffers: shared hit=154"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.125 ms"
"Execution Time: 121.091 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_array_1 @> ARRAY['aml','priority']::text[];
"Seq Scan on inv_rel  (cost=0.00..64113.00 rows=126422 width=8) (actual time=0.016..442.225 rows=123132 loops=1)"
"  Filter: (unindexed_text_array_1 @> '{aml,priority}'::text[])"
"  Rows Removed by Filter: 876868"
"  Buffers: shared hit=51613"
"Planning Time: 0.108 ms"
"Execution Time: 447.782 ms"

-- =============== S6) Array OR (any overlap) ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->'indexed_text_array_1') @> '["aml"]'::jsonb
   OR (payload->'indexed_text_array_2') @> '["grpA"]'::jsonb;
"Seq Scan on inv_jsonb  (cost=0.00..186339.00 rows=673886 width=8) (actual time=0.013..1109.655 rows=674753 loops=1)"
"  Filter: (((payload -> 'indexed_text_array_1'::text) @> '[""aml""]'::jsonb) OR ((payload -> 'indexed_text_array_2'::text) @> '[""grpA""]'::jsonb))"
"  Rows Removed by Filter: 325247"
"  Buffers: shared hit=166339"
"Planning:"
"  Buffers: shared hit=2"
"Planning Time: 0.166 ms"
"Execution Time: 1141.924 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->'unindexed_text_array_1') @> '["aml"]'::jsonb
   OR (payload->'unindexed_text_array_2') @> '["grpA"]'::jsonb;
"Seq Scan on inv_jsonb  (cost=0.00..186339.00 rows=19900 width=8) (actual time=0.015..972.341 rows=674753 loops=1)"
"  Filter: (((payload -> 'unindexed_text_array_1'::text) @> '[""aml""]'::jsonb) OR ((payload -> 'unindexed_text_array_2'::text) @> '[""grpA""]'::jsonb))"
"  Rows Removed by Filter: 325247"
"  Buffers: shared hit=166339"
"Planning Time: 0.112 ms"
"Execution Time: 1000.952 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_array_1 @> ARRAY['aml']::text[]
   OR indexed_text_array_2 @> ARRAY['grpA']::text[];
"Seq Scan on inv_rel  (cost=0.00..66613.00 rows=676873 width=8) (actual time=0.013..560.755 rows=674753 loops=1)"
"  Filter: ((indexed_text_array_1 @> '{aml}'::text[]) OR (indexed_text_array_2 @> '{grpA}'::text[]))"
"  Rows Removed by Filter: 325247"
"  Buffers: shared hit=51613"
"Planning:"
"  Buffers: shared hit=2"
"Planning Time: 0.250 ms"
"Execution Time: 588.970 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_array_1 @> ARRAY['aml']::text[]
   OR unindexed_text_array_2 @> ARRAY['grpA']::text[];
"Seq Scan on inv_rel  (cost=0.00..66613.00 rows=676873 width=8) (actual time=0.014..554.313 rows=674753 loops=1)"
"  Filter: ((unindexed_text_array_1 @> '{aml}'::text[]) OR (unindexed_text_array_2 @> '{grpA}'::text[]))"
"  Rows Removed by Filter: 325247"
"  Buffers: shared hit=51613"
"Planning Time: 0.115 ms"
"Execution Time: 582.980 ms"

-- =============== S7) Multi-key AND (2 keys) ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
  AND ((payload->>'indexed_boolean_1')::boolean) IS TRUE;
"Bitmap Heap Scan on inv_jsonb  (cost=341.12..20637.48 rows=19717 width=8) (actual time=12.675..66.962 rows=38461 loops=1)"
"  Recheck Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"  Filter: (((payload ->> 'indexed_boolean_1'::text))::boolean IS TRUE)"
"  Heap Blocks: exact=38452"
"  Buffers: shared hit=38692"
"  ->  Bitmap Index Scan on inv_jsonb_idx_text1_bl1_num1_str  (cost=0.00..336.20 rows=19717 width=0) (actual time=4.820..4.820 rows=38461 loops=1)"
"        Index Cond: (((payload ->> 'indexed_text_1'::text) = 'A'::text) AND (((payload ->> 'indexed_boolean_1'::text))::boolean = true))"
"        Buffers: shared hit=240"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.251 ms"
"Execution Time: 68.812 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A'
  AND ((payload->>'unindexed_boolean_1')::boolean) IS TRUE;
"Seq Scan on inv_jsonb  (cost=0.00..188839.00 rows=2500 width=8) (actual time=0.036..545.482 rows=38461 loops=1)"
"  Filter: (((payload ->> 'unindexed_text_1'::text) = 'A'::text) AND (((payload ->> 'unindexed_boolean_1'::text))::boolean IS TRUE))"
"  Rows Removed by Filter: 961539"
"  Buffers: shared hit=166339"
"Planning Time: 0.121 ms"
"Execution Time: 547.757 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_boolean_1 IS TRUE;
"Index Only Scan using inv_rel_idx_text1_bl1_num1 on inv_rel  (cost=0.42..528.06 rows=19507 width=8) (actual time=0.173..9.025 rows=38461 loops=1)"
"  Index Cond: ((indexed_text_1 = 'A'::text) AND (indexed_boolean_1 = true))"
"  Heap Fetches: 0"
"  Buffers: shared hit=18027"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.163 ms"
"Execution Time: 10.674 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A' AND unindexed_boolean_1 IS TRUE;
"Seq Scan on inv_rel  (cost=0.00..64113.00 rows=19507 width=8) (actual time=0.023..309.317 rows=38461 loops=1)"
"  Filter: ((unindexed_boolean_1 IS TRUE) AND (unindexed_text_1 = 'A'::text))"
"  Rows Removed by Filter: 961539"
"  Buffers: shared hit=51613"
"Planning Time: 0.127 ms"
"Execution Time: 311.320 ms"

-- =============== S8) Multi-key AND (3 keys) ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
  AND ((payload->>'indexed_boolean_1')::boolean) IS TRUE
  AND ((payload->>'indexed_number_1')::numeric) > 100::numeric;
"Index Scan using inv_jsonb_idx_text1_bl1_num1_str on inv_jsonb  (cost=0.42..21041.89 rows=19715 width=8) (actual time=0.066..44.279 rows=38458 loops=1)"
"  Index Cond: (((payload ->> 'indexed_text_1'::text) = 'A'::text) AND (((payload ->> 'indexed_boolean_1'::text))::boolean = true) AND (((payload ->> 'indexed_number_1'::text))::numeric > '100'::numeric))"
"  Buffers: shared hit=38698"
"Planning:"
"  Buffers: shared hit=5"
"Planning Time: 0.398 ms"
"Execution Time: 46.064 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A'
  AND ((payload->>'unindexed_boolean_1')::boolean) IS TRUE
  AND ((payload->>'unindexed_number_1')::numeric) > 100::numeric;
"Seq Scan on inv_jsonb  (cost=0.00..198839.00 rows=833 width=8) (actual time=0.033..618.979 rows=38458 loops=1)"
"  Filter: (((payload ->> 'unindexed_text_1'::text) = 'A'::text) AND (((payload ->> 'unindexed_boolean_1'::text))::boolean IS TRUE) AND (((payload ->> 'unindexed_number_1'::text))::numeric > '100'::numeric))"
"  Rows Removed by Filter: 961542"
"  Buffers: shared hit=166339"
"Planning Time: 0.131 ms"
"Execution Time: 621.299 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A'
  AND indexed_boolean_1 IS TRUE
  AND indexed_number_1 > 100;
"Index Only Scan using inv_rel_idx_text1_bl1_num1 on inv_rel  (cost=0.42..576.79 rows=19505 width=8) (actual time=0.037..8.969 rows=38458 loops=1)"
"  Index Cond: ((indexed_text_1 = 'A'::text) AND (indexed_boolean_1 = true) AND (indexed_number_1 > '100'::numeric))"
"  Heap Fetches: 0"
"  Buffers: shared hit=18025"
"Planning:"
"  Buffers: shared hit=5"
"Planning Time: 0.186 ms"
"Execution Time: 10.747 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A'
  AND unindexed_boolean_1 IS TRUE
  AND unindexed_number_1 > 100;
"Seq Scan on inv_rel  (cost=0.00..66613.00 rows=19505 width=8) (actual time=0.022..345.269 rows=38458 loops=1)"
"  Filter: ((unindexed_boolean_1 IS TRUE) AND (unindexed_number_1 > '100'::numeric) AND (unindexed_text_1 = 'A'::text))"
"  Rows Removed by Filter: 961542"
"  Buffers: shared hit=51613"
"Planning Time: 0.119 ms"
"Execution Time: 347.273 ms"

-- =============== S9) OR across keys ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
   OR ((payload->>'indexed_boolean_1')::boolean) IS TRUE;
"Bitmap Heap Scan on inv_jsonb  (cost=6209.86..184642.61 rows=517783 width=8) (actual time=88.959..686.945 rows=500000 loops=1)"
"  Recheck Cond: (((payload ->> 'indexed_text_1'::text) = 'A'::text) OR (((payload ->> 'indexed_boolean_1'::text))::boolean IS TRUE))"
"  Filter: (((payload ->> 'indexed_text_1'::text) = 'A'::text) OR (((payload ->> 'indexed_boolean_1'::text))::boolean IS TRUE))"
"  Heap Blocks: exact=166339"
"  Buffers: shared hit=168179"
"  ->  BitmapOr  (cost=6209.86..6209.86 rows=537500 width=0) (actual time=47.837..47.839 rows=0 loops=1)"
"        Buffers: shared hit=1840"
"        ->  Bitmap Index Scan on inv_jsonb_idx_text_1_trgm  (cost=0.00..234.09 rows=39600 width=0) (actual time=7.384..7.385 rows=38461 loops=1)"
"              Index Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"              Buffers: shared hit=40"
"        ->  Bitmap Index Scan on inv_jsonb_idx_bool_1  (cost=0.00..5716.88 rows=497900 width=0) (actual time=40.451..40.452 rows=500000 loops=1)"
"              Index Cond: (((payload ->> 'indexed_boolean_1'::text))::boolean = true)"
"              Buffers: shared hit=1800"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.249 ms"
"Execution Time: 710.183 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A'
   OR ((payload->>'unindexed_boolean_1')::boolean) IS TRUE;
"Seq Scan on inv_jsonb  (cost=0.00..188839.00 rows=502500 width=8) (actual time=0.018..900.125 rows=500000 loops=1)"
"  Filter: (((payload ->> 'unindexed_text_1'::text) = 'A'::text) OR (((payload ->> 'unindexed_boolean_1'::text))::boolean IS TRUE))"
"  Rows Removed by Filter: 500000"
"  Buffers: shared hit=166339"
"Planning Time: 0.118 ms"
"Execution Time: 924.893 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' OR indexed_boolean_1 IS TRUE;
"Index Only Scan using inv_rel_idx_text1_bl1_num1 on inv_rel  (cost=0.42..24504.12 rows=522059 width=8) (actual time=0.021..291.335 rows=500000 loops=1)"
"  Filter: ((indexed_text_1 = 'A'::text) OR (indexed_boolean_1 IS TRUE))"
"  Rows Removed by Filter: 500000"
"  Heap Fetches: 0"
"  Buffers: shared hit=470816"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.158 ms"
"Execution Time: 315.087 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A' OR unindexed_boolean_1 IS TRUE;
"Seq Scan on inv_rel  (cost=0.00..64113.00 rows=522059 width=8) (actual time=0.014..367.333 rows=500000 loops=1)"
"  Filter: ((unindexed_text_1 = 'A'::text) OR (unindexed_boolean_1 IS TRUE))"
"  Rows Removed by Filter: 500000"
"  Buffers: shared hit=51613"
"Planning Time: 0.107 ms"
"Execution Time: 388.847 ms"

-- =============== S10) Top-N ordering within a group ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
ORDER BY (payload->>'indexed_timestamp_1') COLLATE "C";
"Index Scan using inv_jsonb_idx_text1_ts1_txt on inv_jsonb  (cost=0.42..40099.06 rows=39600 width=40) (actual time=0.037..59.439 rows=38461 loops=1)"
"  Index Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"  Buffers: shared hit=38827"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.466 ms"
"Execution Time: 61.792 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A'
ORDER BY (payload->>'unindexed_timestamp_1') COLLATE "C";
"Sort  (cost=181658.69..181671.19 rows=5000 width=40) (actual time=569.078..572.079 rows=38461 loops=1)"
"  Sort Key: (((payload ->> 'unindexed_timestamp_1'::text))::text) COLLATE ""C"""
"  Sort Method: quicksort  Memory: 3640kB"
"  Buffers: shared hit=166339"
"  ->  Seq Scan on inv_jsonb  (cost=0.00..181351.50 rows=5000 width=40) (actual time=0.033..539.549 rows=38461 loops=1)"
"        Filter: ((payload ->> 'unindexed_text_1'::text) = 'A'::text)"
"        Rows Removed by Filter: 961539"
"        Buffers: shared hit=166339"
"Planning Time: 0.134 ms"
"Execution Time: 574.597 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A'
ORDER BY indexed_timestamp_1;
"Index Only Scan using inv_rel_idx_text1_ts1 on inv_rel  (cost=0.42..953.33 rows=38800 width=16) (actual time=0.034..9.619 rows=38461 loops=1)"
"  Index Cond: (indexed_text_1 = 'A'::text)"
"  Heap Fetches: 0"
"  Buffers: shared hit=18030"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.152 ms"
"Execution Time: 11.740 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A'
ORDER BY unindexed_timestamp_1;
"Sort  (cost=67070.29..67167.29 rows=38800 width=16) (actual time=211.294..215.907 rows=38461 loops=1)"
"  Sort Key: unindexed_timestamp_1"
"  Sort Method: quicksort  Memory: 2738kB"
"  Buffers: shared hit=51613"
"  ->  Seq Scan on inv_rel  (cost=0.00..64113.00 rows=38800 width=16) (actual time=0.021..200.426 rows=38461 loops=1)"
"        Filter: (unindexed_text_1 = 'A'::text)"
"        Rows Removed by Filter: 961539"
"        Buffers: shared hit=51613"
"Planning Time: 0.123 ms"
"Execution Time: 218.593 ms"