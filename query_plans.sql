-- =============== S1) Equality text + numeric inequality ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
  AND ((payload->>'indexed_number_1')::numeric) > 100;
"Bitmap Heap Scan on inv_jsonb  (cost=239.11..37733.21 rows=38667 width=8) (actual time=15.931..96.547 rows=38460 loops=1)"
"  Recheck Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"  Filter: (((payload ->> 'indexed_number_1'::text))::numeric > '100'::numeric)"
"  Rows Removed by Filter: 1"
"  Heap Blocks: exact=38452"
"  Buffers: shared hit=38492"
"  ->  Bitmap Index Scan on inv_jsonb_idx_text_1_trgm  (cost=0.00..229.44 rows=38670 width=0) (actual time=8.521..8.522 rows=38461 loops=1)"
"        Index Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"        Buffers: shared hit=40"
"Planning:"
"  Buffers: shared hit=5"
"Planning Time: 0.194 ms"
"Execution Time: 98.336 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A'
  AND ((payload->>'unindexed_number_1')::numeric) > 100;
"Seq Scan on inv_jsonb  (cost=0.00..191341.42 rows=1667 width=8) (actual time=0.034..573.252 rows=38460 loops=1)"
"  Filter: (((payload ->> 'unindexed_text_1'::text) = 'A'::text) AND (((payload ->> 'unindexed_number_1'::text))::numeric > '100'::numeric))"
"  Rows Removed by Filter: 961540"
"  Buffers: shared hit=166339"
"Planning Time: 0.138 ms"
"Execution Time: 575.818 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_number_1 > 100;
"Index Only Scan using inv_rel_idx_text1_bl1_num1 on inv_rel  (cost=0.42..1042.61 rows=38522 width=8) (actual time=0.046..11.931 rows=38460 loops=1)"
"  Index Cond: ((indexed_text_1 = 'A'::text) AND (indexed_number_1 > '100'::numeric))"
"  Heap Fetches: 0"
"  Buffers: shared hit=18036"
"Planning:"
"  Buffers: shared hit=5"
"Planning Time: 0.269 ms"
"Execution Time: 13.537 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A' AND unindexed_number_1 > 100;
"Seq Scan on inv_rel  (cost=0.00..66616.04 rows=38522 width=8) (actual time=0.022..312.535 rows=38460 loops=1)"
"  Filter: ((unindexed_number_1 > '100'::numeric) AND (unindexed_text_1 = 'A'::text))"
"  Rows Removed by Filter: 961540"
"  Buffers: shared hit=51619"
"Planning Time: 0.121 ms"
"Execution Time: 314.396 ms"

-- =============== S2) LIKE prefix (left-anchored) ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_2') LIKE 'INV00012%';
"Index Scan using inv_jsonb_idx_text_2_like on inv_jsonb  (cost=0.42..2.65 rows=100 width=8) (actual time=0.021..0.094 rows=100 loops=1)"
"  Index Cond: (((payload ->> 'indexed_text_2'::text) ~>=~ 'INV00012'::text) AND ((payload ->> 'indexed_text_2'::text) ~<~ 'INV00013'::text))"
"  Filter: ((payload ->> 'indexed_text_2'::text) ~~ 'INV00012%'::text)"
"  Buffers: shared hit=22"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.165 ms"
"Execution Time: 0.112 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_2') LIKE 'INV00012%';
"Seq Scan on inv_jsonb  (cost=0.00..181340.45 rows=5000 width=8) (actual time=0.659..488.470 rows=100 loops=1)"
"  Filter: ((payload ->> 'unindexed_text_2'::text) ~~ 'INV00012%'::text)"
"  Rows Removed by Filter: 999900"
"  Buffers: shared hit=166339"
"Planning Time: 0.108 ms"
"Execution Time: 488.489 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_2 LIKE 'INV00012%';
"Index Only Scan using inv_rel_idx_text_2_like on inv_rel  (cost=0.42..1.55 rows=100 width=8) (actual time=0.020..0.044 rows=100 loops=1)"
"  Index Cond: ((indexed_text_2 ~>=~ 'INV00012'::text) AND (indexed_text_2 ~<~ 'INV00013'::text))"
"  Filter: (indexed_text_2 ~~ 'INV00012%'::text)"
"  Heap Fetches: 0"
"  Buffers: shared hit=5"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.151 ms"
"Execution Time: 0.063 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_2 LIKE 'INV00012%';
"Seq Scan on inv_rel  (cost=0.00..64116.54 rows=100 width=8) (actual time=0.297..182.792 rows=100 loops=1)"
"  Filter: (unindexed_text_2 ~~ 'INV00012%'::text)"
"  Rows Removed by Filter: 999900"
"  Buffers: shared hit=51619"
"Planning Time: 0.107 ms"
"Execution Time: 182.810 ms"


-- =============== S3) Substring contains (ILIKE '%…%') / trigram ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_3') ILIKE '%priority%';
"Bitmap Heap Scan on inv_jsonb  (cost=1278.58..117379.06 rows=167850 width=8) (actual time=111.129..483.156 rows=166666 loops=1)"
"  Recheck Cond: ((payload ->> 'indexed_text_3'::text) ~~* '%priority%'::text)"
"  Heap Blocks: exact=166338"
"  Buffers: shared hit=166874"
"  ->  Bitmap Index Scan on inv_jsonb_idx_text_3_trgm  (cost=0.00..1236.62 rows=167850 width=0) (actual time=64.156..64.156 rows=166666 loops=1)"
"        Index Cond: ((payload ->> 'indexed_text_3'::text) ~~* '%priority%'::text)"
"        Buffers: shared hit=536"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.144 ms"
"Execution Time: 491.815 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_3') ILIKE '%priority%';
"Seq Scan on inv_jsonb  (cost=0.00..181340.45 rows=100 width=8) (actual time=0.028..1292.807 rows=166666 loops=1)"
"  Filter: ((payload ->> 'unindexed_text_3'::text) ~~* '%priority%'::text)"
"  Rows Removed by Filter: 833334"
"  Buffers: shared hit=166339"
"Planning Time: 0.139 ms"
"Execution Time: 1301.560 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_3 ILIKE '%priority%';
"Index Only Scan using inv_rel_idx_text_3_like on inv_rel  (cost=0.42..21665.98 rows=163734 width=8) (actual time=515.247..780.672 rows=166666 loops=1)"
"  Filter: (indexed_text_3 ~~* '%priority%'::text)"
"  Rows Removed by Filter: 833334"
"  Heap Fetches: 0"
"  Buffers: shared hit=3777"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.135 ms"
"Execution Time: 787.231 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_3 ILIKE '%priority%';
"Seq Scan on inv_rel  (cost=0.00..64116.54 rows=163734 width=8) (actual time=0.019..875.350 rows=166666 loops=1)"
"  Filter: (unindexed_text_3 ~~* '%priority%'::text)"
"  Rows Removed by Filter: 833334"
"  Buffers: shared hit=51619"
"Planning Time: 0.112 ms"
"Execution Time: 883.617 ms"


-- =============== S4) Timestamp range ===============
-- (JSONB compares ISO strings with COLLATE "C", as in your original)
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_timestamp_1') COLLATE "C" >= '2025-01-01T00:00:00.000Z'
  AND (payload->>'indexed_timestamp_1') COLLATE "C" <  '2025-02-01T00:00:00.000Z';
"Bitmap Heap Scan on inv_jsonb  (cost=1856.91..76960.10 rows=90008 width=8) (actual time=22.912..134.501 rows=85043 loops=1)"
"  Recheck Cond: ((((payload ->> 'indexed_timestamp_1'::text))::text >= '2025-01-01T00:00:00.000Z'::text) AND (((payload ->> 'indexed_timestamp_1'::text))::text < '2025-02-01T00:00:00.000Z'::text))"
"  Heap Blocks: exact=68708"
"  Buffers: shared hit=69493"
"  ->  Bitmap Index Scan on inv_jsonb_idx_ts_1_txt  (cost=0.00..1834.40 rows=90008 width=0) (actual time=10.672..10.673 rows=85043 loops=1)"
"        Index Cond: ((((payload ->> 'indexed_timestamp_1'::text))::text >= '2025-01-01T00:00:00.000Z'::text) AND (((payload ->> 'indexed_timestamp_1'::text))::text < '2025-02-01T00:00:00.000Z'::text))"
"        Buffers: shared hit=785"
"Planning:"
"  Buffers: shared hit=4"
"Planning Time: 0.164 ms"
"Execution Time: 138.507 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_timestamp_1') COLLATE "C" >= '2025-01-01T00:00:00.000Z'
  AND (payload->>'unindexed_timestamp_1') COLLATE "C" <  '2025-02-01T00:00:00.000Z';
"Seq Scan on inv_jsonb  (cost=0.00..186340.94 rows=5000 width=8) (actual time=0.025..866.698 rows=85043 loops=1)"
"  Filter: ((((payload ->> 'unindexed_timestamp_1'::text))::text >= '2025-01-01T00:00:00.000Z'::text) AND (((payload ->> 'unindexed_timestamp_1'::text))::text < '2025-02-01T00:00:00.000Z'::text))"
"  Rows Removed by Filter: 914957"
"  Buffers: shared hit=166339"
"Planning Time: 0.118 ms"
"Execution Time: 871.054 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_timestamp_1 >= timestamptz '2025-01-01 00:00:00+00'
  AND indexed_timestamp_1 <  timestamptz '2025-02-01 00:00:00+00';
"Index Only Scan using inv_rel_idx_ts_1 on inv_rel  (cost=0.42..2188.43 rows=86245 width=8) (actual time=0.013..15.410 rows=85043 loops=1)"
"  Index Cond: ((indexed_timestamp_1 >= '2025-01-01 00:00:00+00'::timestamp with time zone) AND (indexed_timestamp_1 < '2025-02-01 00:00:00+00'::timestamp with time zone))"
"  Heap Fetches: 0"
"  Buffers: shared hit=40160"
"Planning:"
"  Buffers: shared hit=4"
"Planning Time: 0.178 ms"
"Execution Time: 18.970 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_timestamp_1 >= timestamptz '2025-01-01 00:00:00+00'
  AND unindexed_timestamp_1 <  timestamptz '2025-02-01 00:00:00+00';
"Seq Scan on inv_rel  (cost=0.00..66616.04 rows=86145 width=8) (actual time=0.014..229.032 rows=85043 loops=1)"
"  Filter: ((unindexed_timestamp_1 >= '2025-01-01 00:00:00+00'::timestamp with time zone) AND (unindexed_timestamp_1 < '2025-02-01 00:00:00+00'::timestamp with time zone))"
"  Rows Removed by Filter: 914957"
"  Buffers: shared hit=51619"
"Planning Time: 0.106 ms"
"Execution Time: 232.958 ms"

-- =============== S5) Array AND (contain BOTH) ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->'indexed_text_array_1') @> '["aml","priority"]'::jsonb;
"Bitmap Heap Scan on inv_jsonb  (cost=819.77..96807.57 rows=126646 width=8) (actual time=65.119..267.110 rows=123132 loops=1)"
"  Recheck Cond: ((payload -> 'indexed_text_array_1'::text) @> '[""aml"", ""priority""]'::jsonb)"
"  Heap Blocks: exact=90837"
"  Buffers: shared hit=91019"
"  ->  Bitmap Index Scan on inv_jsonb_idx_text_arr_1_gin  (cost=0.00..788.11 rows=126646 width=0) (actual time=47.142..47.142 rows=123132 loops=1)"
"        Index Cond: ((payload -> 'indexed_text_array_1'::text) @> '[""aml"", ""priority""]'::jsonb)"
"        Buffers: shared hit=182"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.157 ms"
"Execution Time: 272.716 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->'unindexed_text_array_1') @> '["aml","priority"]'::jsonb;
"Seq Scan on inv_jsonb  (cost=0.00..181340.45 rows=10001 width=8) (actual time=0.084..737.160 rows=123132 loops=1)"
"  Filter: ((payload -> 'unindexed_text_array_1'::text) @> '[""aml"", ""priority""]'::jsonb)"
"  Rows Removed by Filter: 876868"
"  Buffers: shared hit=166339"
"Planning Time: 0.095 ms"
"Execution Time: 743.874 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_array_1 @> ARRAY['aml','priority']::text[];
"Bitmap Heap Scan on inv_rel  (cost=775.97..53934.98 rows=123201 width=8) (actual time=49.391..159.749 rows=123132 loops=1)"
"  Recheck Cond: (indexed_text_array_1 @> '{aml,priority}'::text[])"
"  Heap Blocks: exact=47599"
"  Buffers: shared hit=47747"
"  ->  Bitmap Index Scan on inv_rel_idx_text_arr_1  (cost=0.00..745.17 rows=123201 width=0) (actual time=41.908..41.909 rows=123132 loops=1)"
"        Index Cond: (indexed_text_array_1 @> '{aml,priority}'::text[])"
"        Buffers: shared hit=148"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.122 ms"
"Execution Time: 165.255 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_array_1 @> ARRAY['aml','priority']::text[];
"Seq Scan on inv_rel  (cost=0.00..64116.54 rows=123201 width=8) (actual time=0.016..470.582 rows=123132 loops=1)"
"  Filter: (unindexed_text_array_1 @> '{aml,priority}'::text[])"
"  Rows Removed by Filter: 876868"
"  Buffers: shared hit=51619"
"Planning Time: 0.112 ms"
"Execution Time: 476.278 ms"

-- =============== S6) Array OR (any overlap) ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->'indexed_text_array_1') @> '["aml"]'::jsonb
   OR (payload->'indexed_text_array_2') @> '["grpA"]'::jsonb;
"Seq Scan on inv_jsonb  (cost=0.00..186340.94 rows=674055 width=8) (actual time=0.013..1089.473 rows=674753 loops=1)"
"  Filter: (((payload -> 'indexed_text_array_1'::text) @> '[""aml""]'::jsonb) OR ((payload -> 'indexed_text_array_2'::text) @> '[""grpA""]'::jsonb))"
"  Rows Removed by Filter: 325247"
"  Buffers: shared hit=166339"
"Planning:"
"  Buffers: shared hit=2"
"Planning Time: 0.156 ms"
"Execution Time: 1121.269 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->'unindexed_text_array_1') @> '["aml"]'::jsonb
   OR (payload->'unindexed_text_array_2') @> '["grpA"]'::jsonb;
"Seq Scan on inv_jsonb  (cost=0.00..186340.94 rows=19902 width=8) (actual time=0.016..967.585 rows=674753 loops=1)"
"  Filter: (((payload -> 'unindexed_text_array_1'::text) @> '[""aml""]'::jsonb) OR ((payload -> 'unindexed_text_array_2'::text) @> '[""grpA""]'::jsonb))"
"  Rows Removed by Filter: 325247"
"  Buffers: shared hit=166339"
"Planning Time: 0.114 ms"
"Execution Time: 995.920 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_array_1 @> ARRAY['aml']::text[]
   OR indexed_text_array_2 @> ARRAY['grpA']::text[];
"Seq Scan on inv_rel  (cost=0.00..66616.04 rows=674566 width=8) (actual time=0.012..526.807 rows=674753 loops=1)"
"  Filter: ((indexed_text_array_1 @> '{aml}'::text[]) OR (indexed_text_array_2 @> '{grpA}'::text[]))"
"  Rows Removed by Filter: 325247"
"  Buffers: shared hit=51619"
"Planning:"
"  Buffers: shared hit=2"
"Planning Time: 0.131 ms"
"Execution Time: 554.003 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_array_1 @> ARRAY['aml']::text[]
   OR unindexed_text_array_2 @> ARRAY['grpA']::text[];
"Seq Scan on inv_rel  (cost=0.00..66616.04 rows=674566 width=8) (actual time=0.014..573.377 rows=674753 loops=1)"
"  Filter: ((unindexed_text_array_1 @> '{aml}'::text[]) OR (unindexed_text_array_2 @> '{grpA}'::text[]))"
"  Rows Removed by Filter: 325247"
"  Buffers: shared hit=51619"
"Planning Time: 0.115 ms"
"Execution Time: 601.703 ms"

-- =============== S7) Multi-key AND (2 keys) ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
  AND ((payload->>'indexed_boolean_1')::boolean) IS TRUE;
"Bitmap Heap Scan on inv_jsonb  (cost=336.92..20342.96 rows=19414 width=8) (actual time=12.080..66.596 rows=38461 loops=1)"
"  Recheck Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"  Filter: (((payload ->> 'indexed_boolean_1'::text))::boolean IS TRUE)"
"  Heap Blocks: exact=38452"
"  Buffers: shared hit=38676"
"  ->  Bitmap Index Scan on inv_jsonb_idx_text1_bl1_num1_str  (cost=0.00..332.06 rows=19414 width=0) (actual time=5.149..5.149 rows=38461 loops=1)"
"        Index Cond: (((payload ->> 'indexed_text_1'::text) = 'A'::text) AND (((payload ->> 'indexed_boolean_1'::text))::boolean = true))"
"        Buffers: shared hit=224"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.162 ms"
"Execution Time: 68.505 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A'
  AND ((payload->>'unindexed_boolean_1')::boolean) IS TRUE;
"Seq Scan on inv_jsonb  (cost=0.00..188841.18 rows=2500 width=8) (actual time=0.033..529.154 rows=38461 loops=1)"
"  Filter: (((payload ->> 'unindexed_text_1'::text) = 'A'::text) AND (((payload ->> 'unindexed_boolean_1'::text))::boolean IS TRUE))"
"  Rows Removed by Filter: 961539"
"  Buffers: shared hit=166339"
"Planning Time: 0.121 ms"
"Execution Time: 531.514 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_boolean_1 IS TRUE;
"Index Only Scan using inv_rel_idx_text1_bl1_num1 on inv_rel  (cost=0.42..521.06 rows=19212 width=8) (actual time=0.045..8.998 rows=38461 loops=1)"
"  Index Cond: ((indexed_text_1 = 'A'::text) AND (indexed_boolean_1 = true))"
"  Heap Fetches: 0"
"  Buffers: shared hit=18036"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.140 ms"
"Execution Time: 10.681 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A' AND unindexed_boolean_1 IS TRUE;
"Seq Scan on inv_rel  (cost=0.00..64116.54 rows=19212 width=8) (actual time=0.021..296.250 rows=38461 loops=1)"
"  Filter: ((unindexed_boolean_1 IS TRUE) AND (unindexed_text_1 = 'A'::text))"
"  Rows Removed by Filter: 961539"
"  Buffers: shared hit=51619"
"Planning Time: 0.105 ms"
"Execution Time: 298.249 ms"

-- =============== S8) Multi-key AND (3 keys) ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
  AND ((payload->>'indexed_boolean_1')::boolean) IS TRUE
  AND ((payload->>'indexed_number_1')::numeric) > 100::numeric;
"Index Scan using inv_jsonb_idx_text1_bl1_num1_str on inv_jsonb  (cost=0.42..20731.55 rows=19412 width=8) (actual time=0.043..41.166 rows=38460 loops=1)"
"  Index Cond: (((payload ->> 'indexed_text_1'::text) = 'A'::text) AND (((payload ->> 'indexed_boolean_1'::text))::boolean = true) AND (((payload ->> 'indexed_number_1'::text))::numeric > '100'::numeric))"
"  Buffers: shared hit=38684"
"Planning:"
"  Buffers: shared hit=5"
"Planning Time: 0.186 ms"
"Execution Time: 42.978 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A'
  AND ((payload->>'unindexed_boolean_1')::boolean) IS TRUE
  AND ((payload->>'unindexed_number_1')::numeric) > 100::numeric;
"Seq Scan on inv_jsonb  (cost=0.00..198842.15 rows=833 width=8) (actual time=0.037..549.372 rows=38460 loops=1)"
"  Filter: (((payload ->> 'unindexed_text_1'::text) = 'A'::text) AND (((payload ->> 'unindexed_boolean_1'::text))::boolean IS TRUE) AND (((payload ->> 'unindexed_number_1'::text))::numeric > '100'::numeric))"
"  Rows Removed by Filter: 961540"
"  Buffers: shared hit=166339"
"Planning Time: 0.268 ms"
"Execution Time: 551.926 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A'
  AND indexed_boolean_1 IS TRUE
  AND indexed_number_1 > 100;
"Index Only Scan using inv_rel_idx_text1_bl1_num1 on inv_rel  (cost=0.42..569.05 rows=19210 width=8) (actual time=0.045..9.143 rows=38460 loops=1)"
"  Index Cond: ((indexed_text_1 = 'A'::text) AND (indexed_boolean_1 = true) AND (indexed_number_1 > '100'::numeric))"
"  Heap Fetches: 0"
"  Buffers: shared hit=18036"
"Planning:"
"  Buffers: shared hit=5"
"Planning Time: 0.184 ms"
"Execution Time: 10.855 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A'
  AND unindexed_boolean_1 IS TRUE
  AND unindexed_number_1 > 100;
"Seq Scan on inv_rel  (cost=0.00..66616.04 rows=19210 width=8) (actual time=0.023..335.887 rows=38460 loops=1)"
"  Filter: ((unindexed_boolean_1 IS TRUE) AND (unindexed_number_1 > '100'::numeric) AND (unindexed_text_1 = 'A'::text))"
"  Rows Removed by Filter: 961540"
"  Buffers: shared hit=51619"
"Planning Time: 0.133 ms"
"Execution Time: 337.834 ms"


-- =============== S9) OR across keys ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
   OR ((payload->>'indexed_boolean_1')::boolean) IS TRUE;
"Bitmap Heap Scan on inv_jsonb  (cost=6254.85..184760.77 rows=521339 width=8) (actual time=86.382..674.175 rows=500000 loops=1)"
"  Recheck Cond: (((payload ->> 'indexed_text_1'::text) = 'A'::text) OR (((payload ->> 'indexed_boolean_1'::text))::boolean IS TRUE))"
"  Filter: (((payload ->> 'indexed_text_1'::text) = 'A'::text) OR (((payload ->> 'indexed_boolean_1'::text))::boolean IS TRUE))"
"  Heap Blocks: exact=166339"
"  Buffers: shared hit=168179"
"  ->  BitmapOr  (cost=6254.85..6254.85 rows=540752 width=0) (actual time=44.792..44.793 rows=0 loops=1)"
"        Buffers: shared hit=1840"
"        ->  Bitmap Index Scan on inv_jsonb_idx_text_1_trgm  (cost=0.00..229.44 rows=38670 width=0) (actual time=6.889..6.889 rows=38461 loops=1)"
"              Index Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"              Buffers: shared hit=40"
"        ->  Bitmap Index Scan on inv_jsonb_idx_bool_1  (cost=0.00..5764.74 rows=502082 width=0) (actual time=37.902..37.902 rows=500000 loops=1)"
"              Index Cond: (((payload ->> 'indexed_boolean_1'::text))::boolean = true)"
"              Buffers: shared hit=1800"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.166 ms"
"Execution Time: 697.933 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A'
   OR ((payload->>'unindexed_boolean_1')::boolean) IS TRUE;
"Seq Scan on inv_jsonb  (cost=0.00..188841.18 rows=502549 width=8) (actual time=0.019..863.156 rows=500000 loops=1)"
"  Filter: (((payload ->> 'unindexed_text_1'::text) = 'A'::text) OR (((payload ->> 'unindexed_boolean_1'::text))::boolean IS TRUE))"
"  Rows Removed by Filter: 500000"
"  Buffers: shared hit=166339"
"Planning Time: 0.157 ms"
"Execution Time: 885.416 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' OR indexed_boolean_1 IS TRUE;
"Index Only Scan using inv_rel_idx_text1_bl1_num1 on inv_rel  (cost=0.42..24540.28 rows=517883 width=8) (actual time=0.021..289.874 rows=500000 loops=1)"
"  Filter: ((indexed_text_1 = 'A'::text) OR (indexed_boolean_1 IS TRUE))"
"  Rows Removed by Filter: 500000"
"  Heap Fetches: 0"
"  Buffers: shared hit=470602"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.140 ms"
"Execution Time: 309.625 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A' OR unindexed_boolean_1 IS TRUE;
"Seq Scan on inv_rel  (cost=0.00..64116.54 rows=517883 width=8) (actual time=0.014..357.099 rows=500000 loops=1)"
"  Filter: ((unindexed_text_1 = 'A'::text) OR (unindexed_boolean_1 IS TRUE))"
"  Rows Removed by Filter: 500000"
"  Buffers: shared hit=51619"
"Planning Time: 0.106 ms"
"Execution Time: 378.143 ms"

-- =============== S10) Top-N ordering within a group ===============
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
ORDER BY (payload->>'indexed_timestamp_1') COLLATE "C";
"Index Scan using inv_jsonb_idx_text1_ts1_txt on inv_jsonb  (cost=0.42..39246.48 rows=38670 width=40) (actual time=0.030..49.883 rows=38461 loops=1)"
"  Index Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"  Buffers: shared hit=38832"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.189 ms"
"Execution Time: 52.070 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_jsonb
WHERE (payload->>'unindexed_text_1') = 'A'
ORDER BY (payload->>'unindexed_timestamp_1') COLLATE "C";
"Sort  (cost=181660.15..181672.65 rows=5000 width=40) (actual time=564.511..568.032 rows=38461 loops=1)"
"  Sort Key: (((payload ->> 'unindexed_timestamp_1'::text))::text) COLLATE ""C"""
"  Sort Method: quicksort  Memory: 3640kB"
"  Buffers: shared hit=166339"
"  ->  Seq Scan on inv_jsonb  (cost=0.00..181352.95 rows=5000 width=40) (actual time=0.032..533.750 rows=38461 loops=1)"
"        Filter: ((payload ->> 'unindexed_text_1'::text) = 'A'::text)"
"        Rows Removed by Filter: 961539"
"        Buffers: shared hit=166339"
"Planning Time: 0.130 ms"
"Execution Time: 570.792 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A'
ORDER BY indexed_timestamp_1;
"Index Only Scan using inv_rel_idx_text1_ts1 on inv_rel  (cost=0.42..946.33 rows=38526 width=16) (actual time=0.033..9.066 rows=38461 loops=1)"
"  Index Cond: (indexed_text_1 = 'A'::text)"
"  Heap Fetches: 0"
"  Buffers: shared hit=17989"
"Planning:"
"  Buffers: shared hit=1"
"Planning Time: 0.144 ms"
"Execution Time: 11.096 ms"

EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id FROM inv_rel
WHERE unindexed_text_1 = 'A'
ORDER BY unindexed_timestamp_1;
"Sort  (cost=67050.98..67147.29 rows=38526 width=16) (actual time=210.327..213.432 rows=38461 loops=1)"
"  Sort Key: unindexed_timestamp_1"
"  Sort Method: quicksort  Memory: 2738kB"
"  Buffers: shared hit=51619"
"  ->  Seq Scan on inv_rel  (cost=0.00..64116.54 rows=38526 width=16) (actual time=0.017..200.347 rows=38461 loops=1)"
"        Filter: (unindexed_text_1 = 'A'::text)"
"        Rows Removed by Filter: 961539"
"        Buffers: shared hit=51619"
"Planning Time: 0.113 ms"
"Execution Time: 215.985 ms"