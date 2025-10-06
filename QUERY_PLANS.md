-- =============== S1) Equality text + numeric inequality ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
AND ((payload->>'indexed_number_1')::numeric) > 100;
Bitmap Heap Scan on inv_jsonb  
(cost=230.67..36346.88 rows=37060 width=8) 
(actual time=16.743..92.819 rows=38459 loops=1)
Recheck Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)
  Filter: (((payload ->> 'indexed_number_1'::text))::numeric > '100'::numeric)
  Rows Removed by Filter: 2
  Heap Blocks: exact=38452
  ->  Bitmap Index Scan on inv_jsonb_idx_text_1_trgm  
      (cost=0.00..221.41 rows=37063 width=0) 
	  (actual time=9.910..9.911 rows=38461 loops=1)
        Index Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)
Planning Time: 0.198 ms
Execution Time: 94.391 ms

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_number_1 > 100;
Bitmap Heap Scan on inv_rel  
(cost=246.62..30334.77 rows=39864 width=8)
(actual time=16.516..64.073 rows=38459 loops=1)
  Recheck Cond: (indexed_text_1 = 'A'::text)
  Filter: (indexed_number_1 > '100'::numeric)
  Rows Removed by Filter: 2
  Heap Blocks: exact=38261
  ->  Bitmap Index Scan on inv_rel_idx_text_1_trgm  
      (cost=0.00..236.66 rows=39868 width=0) 
	  (actual time=9.796..9.797 rows=38461 loops=1)
        Index Cond: (indexed_text_1 = 'A'::text)
Planning Time: 0.169 ms
Execution Time: 65.661 ms

-- =============== S2) LIKE prefix (left-anchored) ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_2') LIKE 'INV00012%';
Index Scan using inv_jsonb_idx_text_2_like on inv_jsonb  
(cost=0.42..2.65 rows=100 width=8) 
(actual time=0.101..0.166 rows=100 loops=1)
  Index Cond: (((payload ->> 'indexed_text_2'::text) ~>=~ 'INV00012'::text) AND ((payload ->> 'indexed_text_2'::text) ~<~ 'INV00013'::text))
  Filter: ((payload ->> 'indexed_text_2'::text) ~~ 'INV00012%'::text)
Planning Time: 0.180 ms
Execution Time: 0.182 ms

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_2 LIKE 'INV00012%';
Index Scan using inv_rel_idx_text_2_like on inv_rel  
(cost=0.42..2.65 rows=100 width=8) 
(actual time=0.025..0.060 rows=100 loops=1)
  Index Cond: ((indexed_text_2 ~>=~ 'INV00012'::text) AND (indexed_text_2 ~<~ 'INV00013'::text))
  Filter: (indexed_text_2 ~~ 'INV00012%'::text)
Planning Time: 0.152 ms
Execution Time: 0.076 ms

-- =============== S3) Substring contains (ILIKE '%…%') / trigram ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_3') ILIKE '%priority%';
"Bitmap Heap Scan on inv_jsonb  (cost=1261.80..115924.25 rows=164653 width=8) (actual time=112.904..500.912 rows=166666 loops=1)"
"  Recheck Cond: ((payload ->> 'indexed_text_3'::text) ~~* '%priority%'::text)"
"  Heap Blocks: exact=166338"
"  ->  Bitmap Index Scan on inv_jsonb_idx_text_3_trgm  (cost=0.00..1220.63 rows=164653 width=0) (actual time=64.997..64.998 rows=166666 loops=1)"
"        Index Cond: ((payload ->> 'indexed_text_3'::text) ~~* '%priority%'::text)"
"Planning Time: 0.146 ms"
"Execution Time: 507.928 ms"


EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_3 ILIKE '%priority%';
"Bitmap Heap Scan on inv_rel  (cost=1169.86..54861.27 rows=166273 width=8) (actual time=52.437..269.325 rows=166666 loops=1)"
"  Recheck Cond: (indexed_text_3 ~~* '%priority%'::text)"
"  Heap Blocks: exact=51612"
"  ->  Bitmap Index Scan on inv_rel_idx_text_3_trgm  (cost=0.00..1128.29 rows=166273 width=0) (actual time=44.335..44.335 rows=166666 loops=1)"
"        Index Cond: (indexed_text_3 ~~* '%priority%'::text)"
"Planning Time: 0.143 ms"
"Execution Time: 275.056 ms"


-- =============== S4) Timestamp range ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_timestamp_1') >= '2025-01-01T00:00:00.000Z'
AND (payload->>'indexed_timestamp_1') <  '2025-02-01T00:00:00.000Z';
"Bitmap Heap Scan on inv_jsonb  (cost=1528.75..70049.08 rows=79993 width=8) (actual time=26.142..152.391 rows=84824 loops=1)"
"  Recheck Cond: (((payload ->> 'indexed_timestamp_1'::text) >= '2025-01-01T00:00:00.000Z'::text) AND ((payload ->> 'indexed_timestamp_1'::text) < '2025-02-01T00:00:00.000Z'::text))"
"  Heap Blocks: exact=68682"
"  ->  Bitmap Index Scan on inv_jsonb_idx_ts_1_str  (cost=0.00..1508.76 rows=79993 width=0) (actual time=12.425..12.426 rows=84824 loops=1)"
"        Index Cond: (((payload ->> 'indexed_timestamp_1'::text) >= '2025-01-01T00:00:00.000Z'::text) AND ((payload ->> 'indexed_timestamp_1'::text) < '2025-02-01T00:00:00.000Z'::text))"
"Planning Time: 0.269 ms"
"Execution Time: 155.706 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_timestamp_1 >= '2025-01-01 00:00:00+00'
AND indexed_timestamp_1 <  '2025-02-01 00:00:00+00';
"Bitmap Heap Scan on inv_rel  (cost=1224.43..49173.58 rows=84430 width=8) (actual time=19.201..76.490 rows=84824 loops=1)"
"  Recheck Cond: ((indexed_timestamp_1 >= '2025-01-01 00:00:00+00'::timestamp with time zone) AND (indexed_timestamp_1 < '2025-02-01 00:00:00+00'::timestamp with time zone))"
"  Heap Blocks: exact=42287"
"  ->  Bitmap Index Scan on inv_rel_idx_ts_1  (cost=0.00..1203.33 rows=84430 width=0) (actual time=10.336..10.337 rows=84824 loops=1)"
"        Index Cond: ((indexed_timestamp_1 >= '2025-01-01 00:00:00+00'::timestamp with time zone) AND (indexed_timestamp_1 < '2025-02-01 00:00:00+00'::timestamp with time zone))"
"Planning Time: 0.154 ms"
"Execution Time: 79.511 ms"

-- =============== S5) Array AND (contain BOTH) ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->'indexed_text_array_1') @> '["aml","priority"]'::jsonb;
"Bitmap Heap Scan on inv_jsonb  (cost=795.50..94291.02 rows=122023 width=8) (actual time=95.031..298.585 rows=123132 loops=1)"
"  Recheck Cond: ((payload -> 'indexed_text_array_1'::text) @> '[""aml"", ""priority""]'::jsonb)"
"  Heap Blocks: exact=90835"
"  ->  Bitmap Index Scan on inv_jsonb_idx_text_arr_1_gin  (cost=0.00..765.00 rows=122023 width=0) (actual time=47.501..47.501 rows=123132 loops=1)"
"        Index Cond: ((payload -> 'indexed_text_array_1'::text) @> '[""aml"", ""priority""]'::jsonb)"
"Planning Time: 0.147 ms"
"Execution Time: 303.320 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_array_1 @> ARRAY['aml','priority']::text[];
"Bitmap Heap Scan on inv_rel  (cost=761.65..53877.65 rows=120240 width=8) (actual time=49.487..120.692 rows=123132 loops=1)"
"  Recheck Cond: (indexed_text_array_1 @> '{aml,priority}'::text[])"
"  Heap Blocks: exact=47582"
"  ->  Bitmap Index Scan on inv_rel_idx_text_arr_1  (cost=0.00..731.59 rows=120240 width=0) (actual time=41.717..41.717 rows=123132 loops=1)"
"        Index Cond: (indexed_text_array_1 @> '{aml,priority}'::text[])"
"Planning Time: 0.125 ms"
"Execution Time: 124.936 ms"

-- =============== S6) Array OR (any overlap) ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->'indexed_text_array_1') @> '["aml"]'::jsonb
OR (payload->'indexed_text_array_1') @> '["priority"]'::jsonb;
"Bitmap Heap Scan on inv_jsonb  (cost=4113.32..184473.12 rows=578165 width=8) (actual time=178.629..908.317 rows=577383 loops=1)"
"  Recheck Cond: (((payload -> 'indexed_text_array_1'::text) @> '[""aml""]'::jsonb) OR ((payload -> 'indexed_text_array_1'::text) @> '[""priority""]'::jsonb))"
"  Heap Blocks: exact=165413"
"  ->  BitmapOr  (cost=4113.32..4113.32 rows=701040 width=0) (actual time=133.106..133.108 rows=0 loops=1)"
"        ->  Bitmap Index Scan on inv_jsonb_idx_text_arr_1_gin  (cost=0.00..1912.53 rows=350603 width=0) (actual time=51.433..51.433 rows=349856 loops=1)"
"              Index Cond: ((payload -> 'indexed_text_array_1'::text) @> '[""aml""]'::jsonb)"
"        ->  Bitmap Index Scan on inv_jsonb_idx_text_arr_1_gin  (cost=0.00..1911.70 rows=350437 width=0) (actual time=81.672..81.672 rows=350659 loops=1)"
"              Index Cond: ((payload -> 'indexed_text_array_1'::text) @> '[""priority""]'::jsonb)"
"Planning Time: 0.258 ms"
"Execution Time: 930.495 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_array_1 && ARRAY['aml','priority']::text[];
"Bitmap Heap Scan on inv_rel  (cost=3270.00..62049.10 rows=573288 width=8) (actual time=108.920..277.858 rows=577383 loops=1)"
"  Recheck Cond: (indexed_text_array_1 && '{aml,priority}'::text[])"
"  Heap Blocks: exact=51613"
"  ->  Bitmap Index Scan on inv_rel_idx_text_arr_1  (cost=0.00..3126.68 rows=573288 width=0) (actual time=62.049..62.050 rows=577383 loops=1)"
"        Index Cond: (indexed_text_array_1 && '{aml,priority}'::text[])"
"Planning Time: 0.123 ms"
"Execution Time: 299.872 ms"

-- =============== S7) Multi-key AND (2 keys) ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
AND ((payload->>'indexed_boolean_1')::boolean) IS TRUE;
"Bitmap Heap Scan on inv_jsonb  (cost=285.04..19239.84 rows=18323 width=8) (actual time=12.007..68.894 rows=38461 loops=1)"
"  Recheck Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"  Filter: (((payload ->> 'indexed_boolean_1'::text))::boolean IS TRUE)"
"  Heap Blocks: exact=38452"
"  ->  Bitmap Index Scan on inv_jsonb_idx_text1_bl1_num1_str  (cost=0.00..280.45 rows=18323 width=0) (actual time=4.890..4.890 rows=38461 loops=1)"
"        Index Cond: (((payload ->> 'indexed_text_1'::text) = 'A'::text) AND (((payload ->> 'indexed_boolean_1'::text))::boolean = true))"
"Planning Time: 0.178 ms"
"Execution Time: 70.356 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_boolean_1 = true;
"Bitmap Heap Scan on inv_rel  (cost=310.77..18018.06 rows=19975 width=8) (actual time=11.613..48.776 rows=38461 loops=1)"
"  Recheck Cond: ((indexed_text_1 = 'A'::text) AND indexed_boolean_1)"
"  Heap Blocks: exact=38261"
"  ->  Bitmap Index Scan on inv_rel_idx_text1_bl1_num1  (cost=0.00..305.78 rows=19975 width=0) (actual time=4.733..4.733 rows=38461 loops=1)"
"        Index Cond: ((indexed_text_1 = 'A'::text) AND (indexed_boolean_1 = true))"
"Planning Time: 0.142 ms"
"Execution Time: 50.083 ms"

-- =============== S8) Multi-key AND (3 keys) ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
AND ((payload->>'indexed_boolean_1')::boolean) IS TRUE
AND ((payload->>'indexed_number_1')::numeric) = 100::numeric;
"Index Scan using inv_jsonb_idx_text1_bl1_num1_str on inv_jsonb  (cost=0.42..2.65 rows=1 width=8) (actual time=0.022..0.022 rows=0 loops=1)"
"  Index Cond: (((payload ->> 'indexed_text_1'::text) = 'A'::text) AND (((payload ->> 'indexed_boolean_1'::text))::boolean = true) AND (((payload ->> 'indexed_number_1'::text))::numeric = '100'::numeric))"
"Planning Time: 0.178 ms"
"Execution Time: 0.036 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_boolean_1 = true AND indexed_number_1 = 100;
"Index Scan using inv_rel_idx_num_1 on inv_rel  (cost=0.42..2.65 rows=1 width=8) (actual time=0.015..0.015 rows=0 loops=1)"
"  Index Cond: (indexed_number_1 = '100'::numeric)"
"  Filter: (indexed_boolean_1 AND (indexed_text_1 = 'A'::text))"
"Planning Time: 0.233 ms"
"Execution Time: 0.027 ms"

-- scenario 9
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
OR ((payload->>'indexed_boolean_1')::boolean) IS TRUE;
"Bitmap Heap Scan on inv_jsonb  (cost=4615.89..182911.12 rows=513065 width=8) (actual time=88.757..736.285 rows=500000 loops=1)"
"  Recheck Cond: (((payload ->> 'indexed_text_1'::text) = 'A'::text) OR (((payload ->> 'indexed_boolean_1'::text))::boolean IS TRUE))"
"  Filter: (((payload ->> 'indexed_text_1'::text) = 'A'::text) OR (((payload ->> 'indexed_boolean_1'::text))::boolean IS TRUE))"
"  Heap Blocks: exact=166339"
"  ->  BitmapOr  (cost=4615.89..4615.89 rows=531388 width=0) (actual time=43.054..43.055 rows=0 loops=1)"
"        ->  Bitmap Index Scan on inv_jsonb_idx_text_1_trgm  (cost=0.00..221.41 rows=37063 width=0) (actual time=9.704..9.705 rows=38461 loops=1)"
"              Index Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"        ->  Bitmap Index Scan on inv_jsonb_idx_bool_1  (cost=0.00..4137.95 rows=494324 width=0) (actual time=33.348..33.348 rows=500000 loops=1)"
"              Index Cond: (((payload ->> 'indexed_boolean_1'::text))::boolean = true)"
"Planning Time: 0.204 ms"
"Execution Time: 755.156 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' OR indexed_boolean_1 = true;
"Bitmap Heap Scan on inv_rel  (cost=4691.06..63065.59 rows=520947 width=8) (actual time=31.808..281.673 rows=500000 loops=1)"
"  Recheck Cond: ((indexed_text_1 = 'A'::text) OR indexed_boolean_1)"
"  Heap Blocks: exact=51613"
"  ->  BitmapOr  (cost=4691.06..4691.06 rows=540922 width=0) (actual time=23.399..23.401 rows=0 loops=1)"
"        ->  Bitmap Index Scan on inv_rel_idx_text_1_trgm  (cost=0.00..236.66 rows=39868 width=0) (actual time=8.056..8.057 rows=38461 loops=1)"
"              Index Cond: (indexed_text_1 = 'A'::text)"
"        ->  Bitmap Index Scan on inv_rel_idx_bool_1  (cost=0.00..4193.93 rows=501054 width=0) (actual time=15.342..15.342 rows=500000 loops=1)"
"              Index Cond: (indexed_boolean_1 = true)"
"Planning Time: 0.139 ms"
"Execution Time: 299.933 ms"

 -- =============== S10) Top-N ordering within a group ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
ORDER BY (payload->>'indexed_timestamp_1');
"Index Scan using inv_jsonb_idx_text1_ts1_str on inv_jsonb  (cost=0.42..37727.42 rows=37063 width=40) (actual time=0.033..50.894 rows=38461 loops=1)"
"  Index Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"Planning Time: 0.164 ms"
"Execution Time: 52.669 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A'
ORDER BY indexed_timestamp_1;
"Index Scan using inv_rel_idx_text1_ts1 on inv_rel  (cost=0.42..32510.82 rows=39868 width=16) (actual time=0.032..40.754 rows=38461 loops=1)"
"  Index Cond: (indexed_text_1 = 'A'::text)"
"Planning Time: 0.141 ms"
"Execution Time: 42.408 ms"

