CREATE TABLE IF NOT EXISTS inv_rel (
  id BIGSERIAL PRIMARY KEY,

  indexed_text_1    TEXT,
  indexed_text_2    TEXT,
  indexed_text_3    TEXT,
  unindexed_text_1  TEXT,
  unindexed_text_2  TEXT,
  unindexed_text_3  TEXT,

  indexed_timestamp_1   TIMESTAMPTZ,
  indexed_timestamp_2   TIMESTAMPTZ,
  indexed_timestamp_3   TIMESTAMPTZ,
  unindexed_timestamp_1 TIMESTAMPTZ,
  unindexed_timestamp_2 TIMESTAMPTZ,
  unindexed_timestamp_3 TIMESTAMPTZ,

  indexed_number_1    NUMERIC(18,2),
  indexed_number_2    NUMERIC(18,2),
  indexed_number_3    NUMERIC(18,2),
  unindexed_number_1  NUMERIC(18,2),
  unindexed_number_2  NUMERIC(18,2),
  unindexed_number_3  NUMERIC(18,2),

  indexed_text_array_1   TEXT[] DEFAULT '{}'::text[],
  indexed_text_array_2   TEXT[] DEFAULT '{}'::text[],
  indexed_text_array_3   TEXT[] DEFAULT '{}'::text[],
  unindexed_text_array_1 TEXT[],
  unindexed_text_array_2 TEXT[],
  unindexed_text_array_3 TEXT[],

  indexed_boolean_1    BOOLEAN,
  indexed_boolean_2    BOOLEAN,
  indexed_boolean_3    BOOLEAN,
  unindexed_boolean_1  BOOLEAN,
  unindexed_boolean_2  BOOLEAN,
  unindexed_boolean_3  BOOLEAN
);
