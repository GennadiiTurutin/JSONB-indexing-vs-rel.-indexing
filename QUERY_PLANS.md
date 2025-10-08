-- S1
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
  AND ((payload->>'indexed_number_1')::numeric) > 100;

"Bitmap Heap Scan on inv_jsonb  (cost=241.57..38135.19 rows=39135 width=8) (actual time=14.957..130.425 rows=38456 loops=1)"
"  Recheck Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"  Filter: (((payload ->> 'indexed_number_1'::text))::numeric > '100'::numeric)"
"  Rows Removed by Filter: 5"
"  Heap Blocks: exact=38452"
"  ->  Bitmap Index Scan on inv_jsonb_idx_text_1_trgm  (cost=0.00..231.79 rows=39139 width=0) (actual time=8.040..8.040 rows=38461 loops=1)"
"        Index Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"Planning Time: 0.194 ms"
"Execution Time: 132.009 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_number_1 > 100;
"QUERY PLAN"
"Bitmap Heap Scan on inv_rel  (cost=238.04..29451.37 rows=38229 width=8) (actual time=16.194..63.135 rows=38456 loops=1)"
"  Recheck Cond: (indexed_text_1 = 'A'::text)"
"  Filter: (indexed_number_1 > '100'::numeric)"
"  Rows Removed by Filter: 5"
"  Heap Blocks: exact=38254"
"  ->  Bitmap Index Scan on inv_rel_idx_text_1_trgm  (cost=0.00..228.48 rows=38234 width=0) (actual time=8.310..8.311 rows=38461 loops=1)"
"        Index Cond: (indexed_text_1 = 'A'::text)"
"Planning Time: 0.170 ms"
"Execution Time: 64.597 ms"


-- S2
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_2') LIKE 'INV00012%';
"QUERY PLAN"
"Index Scan using inv_jsonb_idx_text_2_like on inv_jsonb  (cost=0.42..2.65 rows=100 width=8) (actual time=0.027..0.099 rows=100 loops=1)"
"  Index Cond: (((payload ->> 'indexed_text_2'::text) ~>=~ 'INV00012'::text) AND ((payload ->> 'indexed_text_2'::text) ~<~ 'INV00013'::text))"
"  Filter: ((payload ->> 'indexed_text_2'::text) ~~ 'INV00012%'::text)"
"Planning Time: 0.179 ms"
"Execution Time: 0.116 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_2 LIKE 'INV00012%';

"QUERY PLAN"
"Index Scan using inv_rel_idx_text_2_like on inv_rel  (cost=0.42..2.65 rows=100 width=8) (actual time=0.024..0.058 rows=100 loops=1)"
"  Index Cond: ((indexed_text_2 ~>=~ 'INV00012'::text) AND (indexed_text_2 ~<~ 'INV00013'::text))"
"  Filter: (indexed_text_2 ~~ 'INV00012%'::text)"
"Planning Time: 0.142 ms"
"Execution Time: 0.074 ms"

-- S3
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_3') ILIKE '%priority%';
"QUERY PLAN"
"Bitmap Heap Scan on inv_jsonb  (cost=1268.12..116474.70 rows=165858 width=8) (actual time=103.575..477.453 rows=166666 loops=1)"
"  Recheck Cond: ((payload ->> 'indexed_text_3'::text) ~~* '%priority%'::text)"
"  Heap Blocks: exact=166338"
"  ->  Bitmap Index Scan on inv_jsonb_idx_text_3_trgm  (cost=0.00..1226.66 rows=165858 width=0) (actual time=58.442..58.442 rows=166666 loops=1)"
"        Index Cond: ((payload ->> 'indexed_text_3'::text) ~~* '%priority%'::text)"
"Planning Time: 0.142 ms"
"Execution Time: 484.509 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_3 ILIKE '%priority%';
"QUERY PLAN"
"Bitmap Heap Scan on inv_rel  (cost=1169.82..54864.25 rows=166034 width=8) (actual time=52.378..279.401 rows=166666 loops=1)"
"  Recheck Cond: (indexed_text_3 ~~* '%priority%'::text)"
"  Heap Blocks: exact=51618"
"  ->  Bitmap Index Scan on inv_rel_idx_text_3_trgm  (cost=0.00..1128.32 rows=166034 width=0) (actual time=43.732..43.733 rows=166666 loops=1)"
"        Index Cond: (indexed_text_3 ~~* '%priority%'::text)"
"Planning Time: 0.124 ms"
"Execution Time: 285.566 ms"

-- S4
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_timestamp_1') >= '2025-01-01T00:00:00.000Z'
  AND (payload->>'indexed_timestamp_1') <  '2025-02-01T00:00:00.000Z';
"QUERY PLAN"
"Bitmap Heap Scan on inv_jsonb  (cost=1717.26..76823.56 rows=90013 width=8) (actual time=28.790..107.887 rows=84702 loops=1)"
"  Recheck Cond: (((payload ->> 'indexed_timestamp_1'::text) >= '2025-01-01T00:00:00.000Z'::text) AND ((payload ->> 'indexed_timestamp_1'::text) < '2025-02-01T00:00:00.000Z'::text))"
"  Heap Blocks: exact=68430"
"  ->  Bitmap Index Scan on inv_jsonb_idx_ts_1_str  (cost=0.00..1694.75 rows=90013 width=0) (actual time=13.805..13.806 rows=84702 loops=1)"
"        Index Cond: (((payload ->> 'indexed_timestamp_1'::text) >= '2025-01-01T00:00:00.000Z'::text) AND ((payload ->> 'indexed_timestamp_1'::text) < '2025-02-01T00:00:00.000Z'::text))"
"Planning Time: 0.174 ms"
"Execution Time: 111.062 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_timestamp_1 >= '2025-01-01 00:00:00+00'
  AND indexed_timestamp_1 <  '2025-02-01 00:00:00+00';

"QUERY PLAN"
"Bitmap Heap Scan on inv_rel  (cost=1212.56..49006.75 rows=83916 width=8) (actual time=17.045..70.162 rows=84702 loops=1)"
"  Recheck Cond: ((indexed_timestamp_1 >= '2025-01-01 00:00:00+00'::timestamp with time zone) AND (indexed_timestamp_1 < '2025-02-01 00:00:00+00'::timestamp with time zone))"
"  Heap Blocks: exact=42284"
"  ->  Bitmap Index Scan on inv_rel_idx_ts_1  (cost=0.00..1191.58 rows=83916 width=0) (actual time=8.806..8.807 rows=84702 loops=1)"
"        Index Cond: ((indexed_timestamp_1 >= '2025-01-01 00:00:00+00'::timestamp with time zone) AND (indexed_timestamp_1 < '2025-02-01 00:00:00+00'::timestamp with time zone))"
"Planning Time: 0.156 ms"
"Execution Time: 73.117 ms"

-- S5
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->'indexed_text_array_1') @> '["aml","priority"]'::jsonb;

"QUERY PLAN"
"Bitmap Heap Scan on inv_jsonb  (cost=786.90..93385.31 rows=120384 width=8) (actual time=65.901..261.952 rows=123132 loops=1)"
"  Recheck Cond: ((payload -> 'indexed_text_array_1'::text) @> '[""aml"", ""priority""]'::jsonb)"
"  Heap Blocks: exact=90837"
"  ->  Bitmap Index Scan on inv_jsonb_idx_text_arr_1_gin  (cost=0.00..756.81 rows=120384 width=0) (actual time=48.316..48.316 rows=123132 loops=1)"
"        Index Cond: ((payload -> 'indexed_text_array_1'::text) @> '[""aml"", ""priority""]'::jsonb)"
"Planning Time: 0.154 ms"
"Execution Time: 266.621 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_array_1 @> ARRAY['aml','priority']::text[];

"QUERY PLAN"
"Bitmap Heap Scan on inv_rel  (cost=772.10..53918.98 rows=122231 width=8) (actual time=49.137..122.203 rows=123132 loops=1)"
"  Recheck Cond: (indexed_text_array_1 @> '{aml,priority}'::text[])"
"  Heap Blocks: exact=47573"
"  ->  Bitmap Index Scan on inv_rel_idx_text_arr_1  (cost=0.00..741.54 rows=122231 width=0) (actual time=41.818..41.818 rows=123132 loops=1)"
"        Index Cond: (indexed_text_array_1 @> '{aml,priority}'::text[])"
"Planning Time: 0.130 ms"
"Execution Time: 126.770 ms"

-- S6
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->'indexed_text_array_1') @> '["aml"]'::jsonb
   OR (payload->'indexed_text_array_1') @> '["priority"]'::jsonb;

"QUERY PLAN"
"Bitmap Heap Scan on inv_jsonb  (cost=4084.24..184343.96 rows=574955 width=8) (actual time=134.295..889.635 rows=577383 loops=1)"
"  Recheck Cond: (((payload -> 'indexed_text_array_1'::text) @> '[""aml""]'::jsonb) OR ((payload -> 'indexed_text_array_1'::text) @> '[""priority""]'::jsonb))"
"  Heap Blocks: exact=165413"
"  ->  BitmapOr  (cost=4084.24..4084.24 rows=696036 width=0) (actual time=87.755..87.756 rows=0 loops=1)"
"        ->  Bitmap Index Scan on inv_jsonb_idx_text_arr_1_gin  (cost=0.00..1874.76 rows=343784 width=0) (actual time=44.147..44.147 rows=349856 loops=1)"
"              Index Cond: ((payload -> 'indexed_text_array_1'::text) @> '[""aml""]'::jsonb)"
"        ->  Bitmap Index Scan on inv_jsonb_idx_text_arr_1_gin  (cost=0.00..1922.00 rows=352252 width=0) (actual time=43.606..43.607 rows=350659 loops=1)"
"              Index Cond: ((payload -> 'indexed_text_array_1'::text) @> '[""priority""]'::jsonb)"
"Planning Time: 0.165 ms"
"Execution Time: 912.538 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_array_1 && ARRAY['aml','priority']::text[];

"QUERY PLAN"
"Bitmap Heap Scan on inv_rel  (cost=3291.97..62123.54 rows=577006 width=8) (actual time=69.805..233.817 rows=577383 loops=1)"
"  Recheck Cond: (indexed_text_array_1 && '{aml,priority}'::text[])"
"  Heap Blocks: exact=51619"
"  ->  Bitmap Index Scan on inv_rel_idx_text_arr_1  (cost=0.00..3147.72 rows=577006 width=0) (actual time=58.921..58.922 rows=577383 loops=1)"
"        Index Cond: (indexed_text_array_1 && '{aml,priority}'::text[])"
"Planning Time: 0.306 ms"
"Execution Time: 255.768 ms"


-- S7
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
  AND ((payload->>'indexed_boolean_1')::boolean) IS TRUE;

"QUERY PLAN"
"Bitmap Heap Scan on inv_jsonb  (cost=305.97..20503.42 rows=19614 width=8) (actual time=12.296..66.656 rows=38461 loops=1)"
"  Recheck Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"  Filter: (((payload ->> 'indexed_boolean_1'::text))::boolean IS TRUE)"
"  Heap Blocks: exact=38452"
"  ->  Bitmap Index Scan on inv_jsonb_idx_text1_bl1_num1_str  (cost=0.00..301.07 rows=19614 width=0) (actual time=5.070..5.071 rows=38461 loops=1)"
"        Index Cond: (((payload ->> 'indexed_text_1'::text) = 'A'::text) AND (((payload ->> 'indexed_boolean_1'::text))::boolean = true))"
"Planning Time: 0.159 ms"
"Execution Time: 68.104 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_boolean_1 = TRUE;

"QUERY PLAN"
"Bitmap Heap Scan on inv_rel  (cost=296.95..17332.78 rows=19056 width=8) (actual time=10.918..45.561 rows=38461 loops=1)"
"  Recheck Cond: ((indexed_text_1 = 'A'::text) AND indexed_boolean_1)"
"  Heap Blocks: exact=38254"
"  ->  Bitmap Index Scan on inv_rel_idx_text1_bl1_num1  (cost=0.00..292.19 rows=19056 width=0) (actual time=4.848..4.848 rows=38461 loops=1)"
"        Index Cond: ((indexed_text_1 = 'A'::text) AND (indexed_boolean_1 = true))"
"Planning Time: 0.133 ms"
"Execution Time: 46.902 ms"

-- S8
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
  AND ((payload->>'indexed_boolean_1')::boolean) IS TRUE
  AND ((payload->>'indexed_number_1')::numeric) > 100::numeric;

"QUERY PLAN"
"Index Scan using inv_jsonb_idx_text1_bl1_num1_str on inv_jsonb  (cost=0.42..20909.14 rows=19612 width=8) (actual time=0.041..41.126 rows=38456 loops=1)"
"  Index Cond: (((payload ->> 'indexed_text_1'::text) = 'A'::text) AND (((payload ->> 'indexed_boolean_1'::text))::boolean = true) AND (((payload ->> 'indexed_number_1'::text))::numeric > '100'::numeric))"
"Planning Time: 0.291 ms"
"Execution Time: 42.556 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_boolean_1 = TRUE AND indexed_number_1 > 100;

"QUERY PLAN"
"Bitmap Heap Scan on inv_rel  (cost=344.55..17425.95 rows=19053 width=8) (actual time=11.927..47.196 rows=38456 loops=1)"
"  Recheck Cond: ((indexed_text_1 = 'A'::text) AND indexed_boolean_1 AND (indexed_number_1 > '100'::numeric))"
"  Heap Blocks: exact=38249"
"  ->  Bitmap Index Scan on inv_rel_idx_text1_bl1_num1  (cost=0.00..339.79 rows=19053 width=0) (actual time=4.988..4.988 rows=38456 loops=1)"
"        Index Cond: ((indexed_text_1 = 'A'::text) AND (indexed_boolean_1 = true) AND (indexed_number_1 > '100'::numeric))"
"Planning Time: 0.186 ms"
"Execution Time: 48.553 ms"

-- S9
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
   OR ((payload->>'indexed_boolean_1')::boolean) IS TRUE;
"QUERY PLAN"
"Bitmap Heap Scan on inv_jsonb  (cost=4687.23..183184.01 rows=520732 width=8) (actual time=76.354..712.482 rows=500000 loops=1)"
"  Recheck Cond: (((payload ->> 'indexed_text_1'::text) = 'A'::text) OR (((payload ->> 'indexed_boolean_1'::text))::boolean IS TRUE))"
"  Filter: (((payload ->> 'indexed_text_1'::text) = 'A'::text) OR (((payload ->> 'indexed_boolean_1'::text))::boolean IS TRUE))"
"  Heap Blocks: exact=166339"
"  ->  BitmapOr  (cost=4687.23..4687.23 rows=540346 width=0) (actual time=36.452..36.453 rows=0 loops=1)"
"        ->  Bitmap Index Scan on inv_jsonb_idx_text_1_trgm  (cost=0.00..231.79 rows=39139 width=0) (actual time=7.817..7.817 rows=38461 loops=1)"
"              Index Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"        ->  Bitmap Index Scan on inv_jsonb_idx_bool_1  (cost=0.00..4195.08 rows=501207 width=0) (actual time=28.633..28.633 rows=500000 loops=1)"
"              Index Cond: (((payload ->> 'indexed_boolean_1'::text))::boolean = true)"
"Planning Time: 0.164 ms"
"Execution Time: 731.812 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' OR indexed_boolean_1 = TRUE;
"QUERY PLAN"
"Bitmap Heap Scan on inv_rel  (cost=4659.11..62986.06 rows=517580 width=8) (actual time=32.148..272.406 rows=500000 loops=1)"
"  Recheck Cond: ((indexed_text_1 = 'A'::text) OR indexed_boolean_1)"
"  Heap Blocks: exact=51619"
"  ->  BitmapOr  (cost=4659.11..4659.11 rows=536636 width=0) (actual time=23.165..23.166 rows=0 loops=1)"
"        ->  Bitmap Index Scan on inv_rel_idx_text_1_trgm  (cost=0.00..228.48 rows=38234 width=0) (actual time=7.521..7.521 rows=38461 loops=1)"
"              Index Cond: (indexed_text_1 = 'A'::text)"
"        ->  Bitmap Index Scan on inv_rel_idx_bool_1  (cost=0.00..4171.84 rows=498402 width=0) (actual time=15.642..15.642 rows=500000 loops=1)"
"              Index Cond: (indexed_boolean_1 = true)"
"Planning Time: 0.140 ms"
"Execution Time: 290.179 ms"

-- S10
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
ORDER BY (payload->>'indexed_timestamp_1');

"QUERY PLAN"
"Index Scan using inv_jsonb_idx_text1_ts1_str on inv_jsonb  (cost=0.42..39637.11 rows=39139 width=40) (actual time=0.031..49.009 rows=38461 loops=1)"
"  Index Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
"Planning Time: 0.164 ms"
"Execution Time: 50.701 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A'
ORDER BY indexed_timestamp_1;

"QUERY PLAN"
"Index Scan using inv_rel_idx_text1_ts1 on inv_rel  (cost=0.42..31532.46 rows=38234 width=16) (actual time=0.029..41.021 rows=38461 loops=1)"
"  Index Cond: (indexed_text_1 = 'A'::text)"
"Planning Time: 0.146 ms"
"Execution Time: 42.745 ms"
