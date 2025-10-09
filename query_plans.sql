-- =============== S1) Equality text + numeric inequality ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
  AND ((payload->>'indexed_number_1')::numeric) > 100;
-- "Bitmap Heap Scan on inv_jsonb  (cost=233.83..36867.96 rows=37661 width=8) (actual time=13.573..86.132 rows=38458 loops=1)"
-- "  Recheck Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
-- "  Filter: (((payload ->> 'indexed_number_1'::text))::numeric > '100'::numeric)"
-- "  Rows Removed by Filter: 3"
-- "  Heap Blocks: exact=38452"
-- "  ->  Bitmap Index Scan on inv_jsonb_idx_text_1_trgm  (cost=0.00..224.41 rows=37665 width=0) (actual time=7.404..7.405 rows=38461 loops=1)"
-- "        Index Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
-- "Planning Time: 0.181 ms"
-- "Execution Time: 87.522 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_number_1 > 100;

-- "Bitmap Heap Scan on inv_rel  (cost=243.09..29973.24 rows=39191 width=8) (actual time=14.320..59.920 rows=38458 loops=1)"
-- "  Recheck Cond: (indexed_text_1 = 'A'::text)"
-- "  Filter: (indexed_number_1 > '100'::numeric)"
-- "  Rows Removed by Filter: 3"
-- "  Heap Blocks: exact=38251"
-- "  ->  Bitmap Index Scan on inv_rel_idx_text_1_trgm  (cost=0.00..233.29 rows=39195 width=0) (actual time=7.496..7.496 rows=38461 loops=1)"
-- "        Index Cond: (indexed_text_1 = 'A'::text)"
-- "Planning Time: 0.183 ms"
-- "Execution Time: 61.301 ms"

-- =============== S2) LIKE prefix (left-anchored) ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_2') LIKE 'INV00012%';

-- "Index Scan using inv_jsonb_idx_text_2_like on inv_jsonb  (cost=0.42..2.65 rows=100 width=8) (actual time=0.026..0.092 rows=100 loops=1)"
-- "  Index Cond: (((payload ->> 'indexed_text_2'::text) ~>=~ 'INV00012'::text) AND ((payload ->> 'indexed_text_2'::text) ~<~ 'INV00013'::text))"
-- "  Filter: ((payload ->> 'indexed_text_2'::text) ~~ 'INV00012%'::text)"
-- "Planning Time: 0.162 ms"
-- "Execution Time: 0.109 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_2 LIKE 'INV00012%';

-- "Index Scan using inv_rel_idx_text_2_like on inv_rel  (cost=0.42..2.65 rows=100 width=8) (actual time=0.025..0.059 rows=100 loops=1)"
-- "  Index Cond: ((indexed_text_2 ~>=~ 'INV00012'::text) AND (indexed_text_2 ~<~ 'INV00013'::text))"
-- "  Filter: (indexed_text_2 ~~ 'INV00012%'::text)"
-- "Planning Time: 0.240 ms"
-- "Execution Time: 0.077 ms"

-- =============== S3) Substring contains (ILIKE '%…%') / trigram ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_3') ILIKE '%priority%';

-- "Bitmap Heap Scan on inv_jsonb  (cost=1279.15..117427.17 rows=167958 width=8) (actual time=113.241..514.993 rows=166666 loops=1)"
-- "  Recheck Cond: ((payload ->> 'indexed_text_3'::text) ~~* '%priority%'::text)"
-- "  Heap Blocks: exact=166338"
-- "  ->  Bitmap Index Scan on inv_jsonb_idx_text_3_trgm  (cost=0.00..1237.16 rows=167958 width=0) (actual time=65.048..65.049 rows=166666 loops=1)"
-- "        Index Cond: ((payload ->> 'indexed_text_3'::text) ~~* '%priority%'::text)"
-- "Planning Time: 0.142 ms"
-- "Execution Time: 522.144 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_3 ILIKE '%priority%';

-- "Bitmap Heap Scan on inv_rel  (cost=1170.41..54860.24 rows=166146 width=8) (actual time=53.336..272.607 rows=166666 loops=1)"
-- "  Recheck Cond: (indexed_text_3 ~~* '%priority%'::text)"
-- "  Heap Blocks: exact=51613"
-- "  ->  Bitmap Index Scan on inv_rel_idx_text_3_trgm  (cost=0.00..1128.88 rows=166146 width=0) (actual time=45.411..45.411 rows=166666 loops=1)"
-- "        Index Cond: (indexed_text_3 ~~* '%priority%'::text)"
-- "Planning Time: 0.125 ms"
-- "Execution Time: 278.783 ms"


-- =============== S4) Timestamp range ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_timestamp_1') >= '2025-01-01T00:00:00.000Z'
  AND (payload->>'indexed_timestamp_1') <  '2025-02-01T00:00:00.000Z';

-- "Bitmap Heap Scan on inv_jsonb  (cost=1518.88..70041.28 rows=79996 width=8) (actual time=26.742..103.996 rows=84477 loops=1)"
-- "  Recheck Cond: (((payload ->> 'indexed_timestamp_1'::text) >= '2025-01-01T00:00:00.000Z'::text) AND ((payload ->> 'indexed_timestamp_1'::text) < '2025-02-01T00:00:00.000Z'::text))"
-- "  Heap Blocks: exact=68707"
-- "  ->  Bitmap Index Scan on inv_jsonb_idx_ts_1_str  (cost=0.00..1498.88 rows=79996 width=0) (actual time=13.041..13.042 rows=84477 loops=1)"
-- "        Index Cond: (((payload ->> 'indexed_timestamp_1'::text) >= '2025-01-01T00:00:00.000Z'::text) AND ((payload ->> 'indexed_timestamp_1'::text) < '2025-02-01T00:00:00.000Z'::text))"
-- "Planning Time: 0.177 ms"
-- "Execution Time: 107.160 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_timestamp_1 >= '2025-01-01 00:00:00+00'
  AND indexed_timestamp_1 <  '2025-02-01 00:00:00+00';

-- "Bitmap Heap Scan on inv_rel  (cost=1222.63..49248.35 rows=84683 width=8) (actual time=16.345..66.204 rows=84477 loops=1)"
-- "  Recheck Cond: ((indexed_timestamp_1 >= '2025-01-01 00:00:00+00'::timestamp with time zone) AND (indexed_timestamp_1 < '2025-02-01 00:00:00+00'::timestamp with time zone))"
-- "  Heap Blocks: exact=42318"
-- "  ->  Bitmap Index Scan on inv_rel_idx_ts_1  (cost=0.00..1201.46 rows=84683 width=0) (actual time=8.671..8.672 rows=84477 loops=1)"
-- "        Index Cond: ((indexed_timestamp_1 >= '2025-01-01 00:00:00+00'::timestamp with time zone) AND (indexed_timestamp_1 < '2025-02-01 00:00:00+00'::timestamp with time zone))"
-- "Planning Time: 0.198 ms"
-- "Execution Time: 69.205 ms"

-- =============== S5) Array AND (contain BOTH) ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->'indexed_text_array_1') @> '["aml","priority"]'::jsonb;

-- "Bitmap Heap Scan on inv_jsonb  (cost=811.98..96004.20 rows=125160 width=8) (actual time=63.264..253.354 rows=123132 loops=1)"
-- "  Recheck Cond: ((payload -> 'indexed_text_array_1'::text) @> '[""aml"", ""priority""]'::jsonb)"
-- "  Heap Blocks: exact=90828"
-- "  ->  Bitmap Index Scan on inv_jsonb_idx_text_arr_1_gin  (cost=0.00..780.69 rows=125160 width=0) (actual time=46.773..46.774 rows=123132 loops=1)"
-- "        Index Cond: ((payload -> 'indexed_text_array_1'::text) @> '[""aml"", ""priority""]'::jsonb)"
-- "Planning Time: 0.142 ms"
-- "Execution Time: 257.888 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_array_1 @> ARRAY['aml','priority']::text[];

-- "Bitmap Heap Scan on inv_rel  (cost=768.59..53901.14 rows=121564 width=8) (actual time=48.542..115.105 rows=123132 loops=1)"
-- "  Recheck Cond: (indexed_text_array_1 @> '{aml,priority}'::text[])"
-- "  Heap Blocks: exact=47655"
-- "  ->  Bitmap Index Scan on inv_rel_idx_text_arr_1  (cost=0.00..738.20 rows=121564 width=0) (actual time=41.086..41.086 rows=123132 loops=1)"
-- "        Index Cond: (indexed_text_array_1 @> '{aml,priority}'::text[])"
-- "Planning Time: 0.117 ms"
-- "Execution Time: 119.520 ms"

-- =============== S6) Array OR (any overlap) ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->'indexed_text_array_1') @> '["aml"]'::jsonb
   OR (payload->'indexed_text_array_1') @> '["priority"]'::jsonb;
-- "Bitmap Heap Scan on inv_jsonb  (cost=4106.54..184445.46 rows=577492 width=8) (actual time=159.497..981.158 rows=577383 loops=1)"
-- "  Recheck Cond: (((payload -> 'indexed_text_array_1'::text) @> '[""aml""]'::jsonb) OR ((payload -> 'indexed_text_array_1'::text) @> '[""priority""]'::jsonb))"
-- "  Heap Blocks: exact=165409"
-- "  ->  BitmapOr  (cost=4106.54..4106.54 rows=699996 width=0) (actual time=97.210..97.212 rows=0 loops=1)"
-- "        ->  Bitmap Index Scan on inv_jsonb_idx_text_arr_1_gin  (cost=0.00..1914.92 rows=351081 width=0) (actual time=49.109..49.109 rows=349856 loops=1)"
-- "              Index Cond: ((payload -> 'indexed_text_array_1'::text) @> '[""aml""]'::jsonb)"
-- "        ->  Bitmap Index Scan on inv_jsonb_idx_text_arr_1_gin  (cost=0.00..1902.87 rows=348915 width=0) (actual time=48.100..48.100 rows=350659 loops=1)"
-- "              Index Cond: ((payload -> 'indexed_text_array_1'::text) @> '[""priority""]'::jsonb)"
-- "Planning Time: 1.128 ms"
-- "Execution Time: 1006.104 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE 'aml' = ANY(indexed_text_array_1)
   OR 'priority' = ANY(indexed_text_array_1);
-- "Seq Scan on inv_rel  (cost=0.00..66611.17 rows=575718 width=8) (actual time=0.014..490.873 rows=577383 loops=1)"
-- "  Filter: (('aml'::text = ANY (indexed_text_array_1)) OR ('priority'::text = ANY (indexed_text_array_1)))"
-- "  Rows Removed by Filter: 422617"
-- "Planning Time: 0.926 ms"
-- "Execution Time: 510.620 ms"

-- =============== S7) Multi-key AND (2 keys) ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
  AND ((payload->>'indexed_boolean_1')::boolean) IS TRUE;

-- "Bitmap Heap Scan on inv_jsonb  (cost=294.20..19801.12 rows=18895 width=8) (actual time=12.122..64.740 rows=38461 loops=1)"
-- "  Recheck Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
-- "  Filter: (((payload ->> 'indexed_boolean_1'::text))::boolean IS TRUE)"
-- "  Heap Blocks: exact=38452"
-- "  ->  Bitmap Index Scan on inv_jsonb_idx_text1_bl1_num1_str  (cost=0.00..289.48 rows=18895 width=0) (actual time=4.857..4.858 rows=38461 loops=1)"
-- "        Index Cond: (((payload ->> 'indexed_text_1'::text) = 'A'::text) AND (((payload ->> 'indexed_boolean_1'::text))::boolean = true))"
-- "Planning Time: 0.177 ms"
-- "Execution Time: 66.242 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_boolean_1 = TRUE;
-- "Bitmap Heap Scan on inv_rel  (cost=304.51..17723.68 rows=19579 width=8) (actual time=11.167..46.982 rows=38461 loops=1)"
-- "  Recheck Cond: ((indexed_text_1 = 'A'::text) AND indexed_boolean_1)"
-- "  Heap Blocks: exact=38251"
-- "  ->  Bitmap Index Scan on inv_rel_idx_text1_bl1_num1  (cost=0.00..299.62 rows=19579 width=0) (actual time=4.550..4.551 rows=38461 loops=1)"
-- "        Index Cond: ((indexed_text_1 = 'A'::text) AND (indexed_boolean_1 = true))"
-- "Planning Time: 0.136 ms"
-- "Execution Time: 48.376 ms"

-- =============== S8) Multi-key AND (3 keys) ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
  AND ((payload->>'indexed_boolean_1')::boolean) IS TRUE
  AND ((payload->>'indexed_number_1')::numeric) > 100::numeric;
-- "Index Scan using inv_jsonb_idx_text1_bl1_num1_str on inv_jsonb  (cost=0.42..20177.62 rows=18893 width=8) (actual time=0.047..40.526 rows=38458 loops=1)"
-- "  Index Cond: (((payload ->> 'indexed_text_1'::text) = 'A'::text) AND (((payload ->> 'indexed_boolean_1'::text))::boolean = true) AND (((payload ->> 'indexed_number_1'::text))::numeric > '100'::numeric))"
-- "Planning Time: 0.218 ms"
-- "Execution Time: 41.943 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' AND indexed_boolean_1 = TRUE AND indexed_number_1 > 100;
-- "Bitmap Heap Scan on inv_rel  (cost=353.43..17820.51 rows=19577 width=8) (actual time=11.671..47.936 rows=38458 loops=1)"
-- "  Recheck Cond: ((indexed_text_1 = 'A'::text) AND indexed_boolean_1 AND (indexed_number_1 > '100'::numeric))"
-- "  Heap Blocks: exact=38248"
-- "  ->  Bitmap Index Scan on inv_rel_idx_text1_bl1_num1  (cost=0.00..348.54 rows=19577 width=0) (actual time=4.846..4.846 rows=38458 loops=1)"
-- "        Index Cond: ((indexed_text_1 = 'A'::text) AND (indexed_boolean_1 = true) AND (indexed_number_1 > '100'::numeric))"
-- "Planning Time: 0.374 ms"
-- "Execution Time: 49.475 ms"

-- =============== S9) OR across keys ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
   OR ((payload->>'indexed_boolean_1')::boolean) IS TRUE;
-- "Bitmap Heap Scan on inv_jsonb  (cost=4684.04..183157.41 rows=520410 width=8) (actual time=81.490..712.348 rows=500000 loops=1)"
-- "  Recheck Cond: (((payload ->> 'indexed_text_1'::text) = 'A'::text) OR (((payload ->> 'indexed_boolean_1'::text))::boolean IS TRUE))"
-- "  Filter: (((payload ->> 'indexed_text_1'::text) = 'A'::text) OR (((payload ->> 'indexed_boolean_1'::text))::boolean IS TRUE))"
-- "  Heap Blocks: exact=166339"
-- "  ->  BitmapOr  (cost=4684.04..4684.04 rows=539305 width=0) (actual time=43.121..43.122 rows=0 loops=1)"
-- "        ->  Bitmap Index Scan on inv_jsonb_idx_text_1_trgm  (cost=0.00..224.41 rows=37665 width=0) (actual time=9.139..9.139 rows=38461 loops=1)"
-- "              Index Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
-- "        ->  Bitmap Index Scan on inv_jsonb_idx_bool_1  (cost=0.00..4199.43 rows=501640 width=0) (actual time=33.981..33.981 rows=500000 loops=1)"
-- "              Index Cond: (((payload ->> 'indexed_boolean_1'::text))::boolean = true)"
-- "Planning Time: 0.211 ms"
-- "Execution Time: 731.238 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A' OR indexed_boolean_1 = TRUE;

-- "Bitmap Heap Scan on inv_rel  (cost=4673.80..63020.15 rows=519088 width=8) (actual time=33.600..300.207 rows=500000 loops=1)"
-- "  Recheck Cond: ((indexed_text_1 = 'A'::text) OR indexed_boolean_1)"
-- "  Heap Blocks: exact=51613"
-- "  ->  BitmapOr  (cost=4673.80..4673.80 rows=538668 width=0) (actual time=25.220..25.221 rows=0 loops=1)"
-- "        ->  Bitmap Index Scan on inv_rel_idx_text_1_trgm  (cost=0.00..233.29 rows=39195 width=0) (actual time=10.220..10.220 rows=38461 loops=1)"
-- "              Index Cond: (indexed_text_1 = 'A'::text)"
-- "        ->  Bitmap Index Scan on inv_rel_idx_bool_1  (cost=0.00..4180.97 rows=499472 width=0) (actual time=14.999..14.999 rows=500000 loops=1)"
-- "              Index Cond: (indexed_boolean_1 = true)"
-- "Planning Time: 0.135 ms"
-- "Execution Time: 317.374 ms"

-- =============== S10) Top-N ordering within a group ===============
EXPLAIN ANALYZE
SELECT id FROM inv_jsonb
WHERE (payload->>'indexed_text_1') = 'A'
ORDER BY (payload->>'indexed_timestamp_1');
-- "Index Scan using inv_jsonb_idx_text1_ts1_str on inv_jsonb  (cost=0.42..38284.09 rows=37665 width=40) (actual time=0.031..47.790 rows=38461 loops=1)"
-- "  Index Cond: ((payload ->> 'indexed_text_1'::text) = 'A'::text)"
-- "Planning Time: 0.255 ms"
-- "Execution Time: 50.167 ms"

EXPLAIN ANALYZE
SELECT id FROM inv_rel
WHERE indexed_text_1 = 'A'
ORDER BY indexed_timestamp_1;

-- "Index Scan using inv_rel_idx_text1_ts1 on inv_rel  (cost=0.42..32114.43 rows=39195 width=16) (actual time=0.108..40.106 rows=38461 loops=1)"
-- "  Index Cond: (indexed_text_1 = 'A'::text)"
-- "Planning Time: 0.144 ms"
-- "Execution Time: 41.841 ms"

