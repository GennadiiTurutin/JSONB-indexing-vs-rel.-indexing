-- Bench helper index
CREATE INDEX IF NOT EXISTS bench_results_label_variant_idx
ON bench.results(label, variant, ts);

-- --------------------- inv_rel (relational) ---------------------
-- Equality / IN / range
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_1 ON inv_rel(indexed_text_1);
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_2 ON inv_rel(indexed_text_2);
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_3 ON inv_rel(indexed_text_3);

-- LIKE 'prefix%'
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_1_like ON inv_rel(indexed_text_1 text_pattern_ops);
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_2_like ON inv_rel(indexed_text_2 text_pattern_ops);
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_3_like ON inv_rel(indexed_text_3 text_pattern_ops);

-- Timestamps as ISO strings
CREATE INDEX IF NOT EXISTS inv_rel_idx_ts_1 ON inv_rel(indexed_timestamp_1);
CREATE INDEX IF NOT EXISTS inv_rel_idx_ts_2 ON inv_rel(indexed_timestamp_2);
CREATE INDEX IF NOT EXISTS inv_rel_idx_ts_3 ON inv_rel(indexed_timestamp_3);

-- Substring contains (trigram)
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_1_trgm ON inv_rel USING GIN (indexed_text_1 gin_trgm_ops);
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_2_trgm ON inv_rel USING GIN (indexed_text_2 gin_trgm_ops);
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_3_trgm ON inv_rel USING GIN (indexed_text_3 gin_trgm_ops);

-- Numbers
CREATE INDEX IF NOT EXISTS inv_rel_idx_num_1 ON inv_rel(indexed_number_1);
CREATE INDEX IF NOT EXISTS inv_rel_idx_num_2 ON inv_rel(indexed_number_2);
CREATE INDEX IF NOT EXISTS inv_rel_idx_num_3 ON inv_rel(indexed_number_3);

-- Booleans
CREATE INDEX IF NOT EXISTS inv_rel_idx_bool_1 ON inv_rel(indexed_boolean_1);
CREATE INDEX IF NOT EXISTS inv_rel_idx_bool_2 ON inv_rel(indexed_boolean_2);
CREATE INDEX IF NOT EXISTS inv_rel_idx_bool_3 ON inv_rel(indexed_boolean_3);

-- Arrays (for && / @>)
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_arr_1 ON inv_rel USING GIN (indexed_text_array_1);
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_arr_2 ON inv_rel USING GIN (indexed_text_array_2);
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_arr_3 ON inv_rel USING GIN (indexed_text_array_3);

-- Composite examples
CREATE INDEX IF NOT EXISTS inv_rel_idx_text1_bl1_num1
ON inv_rel (indexed_text_1, indexed_boolean_1, indexed_number_1);

CREATE INDEX IF NOT EXISTS inv_rel_idx_text1_ts1
ON inv_rel (indexed_text_1, indexed_timestamp_1);

-- --------------------- inv_jsonb (payload) ---------------------
-- Equality / IN / range
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_1 ON inv_jsonb ((payload->>'indexed_text_1'));
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_2 ON inv_jsonb ((payload->>'indexed_text_2'));
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_3 ON inv_jsonb ((payload->>'indexed_text_3'));

-- LIKE 'prefix%'
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_1_like ON inv_jsonb (((payload->>'indexed_text_1')) text_pattern_ops);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_2_like ON inv_jsonb (((payload->>'indexed_text_2')) text_pattern_ops);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_3_like ON inv_jsonb (((payload->>'indexed_text_3')) text_pattern_ops);

-- Timestamps as ISO strings 
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_ts_1_str ON inv_jsonb ((payload->>'indexed_timestamp_1'));
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_ts_2_str ON inv_jsonb ((payload->>'indexed_timestamp_2'));
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_ts_3_str ON inv_jsonb ((payload->>'indexed_timestamp_3'));

-- Substring contains (trigram)
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_1_trgm ON inv_jsonb USING GIN ((payload->>'indexed_text_1') gin_trgm_ops);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_2_trgm ON inv_jsonb USING GIN ((payload->>'indexed_text_2') gin_trgm_ops);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_3_trgm ON inv_jsonb USING GIN ((payload->>'indexed_text_3') gin_trgm_ops);

-- Numbers
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_num_1 ON inv_jsonb (((payload->>'indexed_number_1')::numeric));
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_num_2 ON inv_jsonb (((payload->>'indexed_number_2')::numeric));
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_num_3 ON inv_jsonb (((payload->>'indexed_number_3')::numeric));

-- Booleans
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_bool_1 ON inv_jsonb (((payload->>'indexed_boolean_1')::boolean));
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_bool_2 ON inv_jsonb (((payload->>'indexed_boolean_2')::boolean));
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_bool_3 ON inv_jsonb (((payload->>'indexed_boolean_3')::boolean));


-- Array subpaths (JSONB arrays of TEXT)
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_arr_1_gin
ON inv_jsonb USING GIN ((payload->'indexed_text_array_1') jsonb_path_ops);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_arr_2_gin
ON inv_jsonb USING GIN ((payload->'indexed_text_array_2') jsonb_path_ops);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_arr_3_gin
ON inv_jsonb USING GIN ((payload->'indexed_text_array_3') jsonb_path_ops);

-- Composite examples
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text1_bl1_num1_str
ON inv_jsonb ((payload->>'indexed_text_1'), ((payload->>'indexed_boolean_1')::boolean), ((payload->>'indexed_number_1')::numeric));

CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text1_ts1_str
ON inv_jsonb ((payload->>'indexed_text_1'), (payload->>'indexed_timestamp_1'));
