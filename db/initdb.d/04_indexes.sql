-- --------------------- inv_rel (relational) ---------------------
-- Equality / IN / range
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_1 ON inv_rel(indexed_text_1) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_2 ON inv_rel(indexed_text_2) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_3 ON inv_rel(indexed_text_3) INCLUDE (id);

-- LIKE 'prefix%'
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_1_like ON inv_rel(indexed_text_1 text_pattern_ops) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_2_like ON inv_rel(indexed_text_2 text_pattern_ops) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_3_like ON inv_rel(indexed_text_3 text_pattern_ops) INCLUDE (id);

-- Timestamps
CREATE INDEX IF NOT EXISTS inv_rel_idx_ts_1 ON inv_rel(indexed_timestamp_1) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_rel_idx_ts_2 ON inv_rel(indexed_timestamp_2) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_rel_idx_ts_3 ON inv_rel(indexed_timestamp_3) INCLUDE (id);

-- Substring contains (trigram)
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_1_trgm ON inv_rel USING GIN (indexed_text_1 gin_trgm_ops);
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_2_trgm ON inv_rel USING GIN (indexed_text_2 gin_trgm_ops);
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_3_trgm ON inv_rel USING GIN (indexed_text_3 gin_trgm_ops);

-- Numbers
CREATE INDEX IF NOT EXISTS inv_rel_idx_num_1 ON inv_rel(indexed_number_1) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_rel_idx_num_2 ON inv_rel(indexed_number_2) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_rel_idx_num_3 ON inv_rel(indexed_number_3) INCLUDE (id);

-- Booleans
CREATE INDEX IF NOT EXISTS inv_rel_idx_bool_1 ON inv_rel(indexed_boolean_1) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_rel_idx_bool_2 ON inv_rel(indexed_boolean_2) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_rel_idx_bool_3 ON inv_rel(indexed_boolean_3) INCLUDE (id);

-- Arrays (for && / @>)
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_arr_1 ON inv_rel USING GIN (indexed_text_array_1);
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_arr_2 ON inv_rel USING GIN (indexed_text_array_2);
CREATE INDEX IF NOT EXISTS inv_rel_idx_text_arr_3 ON inv_rel USING GIN (indexed_text_array_3);

-- Composite examples
CREATE INDEX IF NOT EXISTS inv_rel_idx_text1_bl1_num1
ON inv_rel (indexed_text_1, indexed_boolean_1, indexed_number_1) INCLUDE (id);

CREATE INDEX IF NOT EXISTS inv_rel_idx_text1_ts1
ON inv_rel (indexed_text_1, indexed_timestamp_1) INCLUDE (id);

-- --------------------- inv_jsonb (payload) ---------------------
-- Equality / IN / range
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_1 ON inv_jsonb ((payload->>'indexed_text_1')) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_2 ON inv_jsonb ((payload->>'indexed_text_2')) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_3 ON inv_jsonb ((payload->>'indexed_text_3')) INCLUDE (id);

-- LIKE 'prefix%'
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_1_like ON inv_jsonb (((payload->>'indexed_text_1')) text_pattern_ops) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_2_like ON inv_jsonb (((payload->>'indexed_text_2')) text_pattern_ops) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_3_like ON inv_jsonb (((payload->>'indexed_text_3')) text_pattern_ops) INCLUDE (id);

-- Timestamps as ISO strings 
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_ts_1_txt
  ON inv_jsonb (((payload->>'indexed_timestamp_1') COLLATE "C")) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_ts_2_txt
  ON inv_jsonb (((payload->>'indexed_timestamp_2') COLLATE "C")) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_ts_3_txt
  ON inv_jsonb (((payload->>'indexed_timestamp_3') COLLATE "C")) INCLUDE (id);


-- Substring contains (trigram)
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_1_trgm ON inv_jsonb USING GIN ((payload->>'indexed_text_1') gin_trgm_ops);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_2_trgm ON inv_jsonb USING GIN ((payload->>'indexed_text_2') gin_trgm_ops);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_3_trgm ON inv_jsonb USING GIN ((payload->>'indexed_text_3') gin_trgm_ops);

-- Numbers
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_num_1 ON inv_jsonb (((payload->>'indexed_number_1')::numeric)) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_num_2 ON inv_jsonb (((payload->>'indexed_number_2')::numeric)) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_num_3 ON inv_jsonb (((payload->>'indexed_number_3')::numeric)) INCLUDE (id);

-- Booleans
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_bool_1 ON inv_jsonb (((payload->>'indexed_boolean_1')::boolean)) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_bool_2 ON inv_jsonb (((payload->>'indexed_boolean_2')::boolean)) INCLUDE (id);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_bool_3 ON inv_jsonb (((payload->>'indexed_boolean_3')::boolean)) INCLUDE (id);


-- Array subpaths (JSONB arrays of TEXT)
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_arr_1_gin
ON inv_jsonb USING GIN ((payload->'indexed_text_array_1') jsonb_path_ops);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_arr_2_gin
ON inv_jsonb USING GIN ((payload->'indexed_text_array_2') jsonb_path_ops);
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text_arr_3_gin
ON inv_jsonb USING GIN ((payload->'indexed_text_array_3') jsonb_path_ops);

-- Composite examples
CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text1_bl1_num1_str
ON inv_jsonb ((payload->>'indexed_text_1'), ((payload->>'indexed_boolean_1')::boolean), ((payload->>'indexed_number_1')::numeric)) INCLUDE (id);

CREATE INDEX IF NOT EXISTS inv_jsonb_idx_text1_ts1_txt
ON inv_jsonb ((payload->>'indexed_text_1'), ((payload->>'indexed_timestamp_1')) COLLATE "C")
INCLUDE (id);
