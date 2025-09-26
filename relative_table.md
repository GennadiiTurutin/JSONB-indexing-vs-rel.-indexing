| variant          | indexed_note       | unindexed_note        | rel_indexed_pct   | rel_unindexed_pct   |
|:-----------------|:-------------------|:----------------------|:------------------|:--------------------|
| S10_topn_order   | REL faster by 47%  | REL faster by 63%     | 53%               | 37%                 |
| S1_expr_eq_num   | REL faster by 26%  | REL faster by 24%     | 74%               | 76%                 |
| S2_like_prefix   | REL faster by 25%  | REL faster by 50%     | 75%               | 50%                 |
| S3_trgm_contains | REL faster by 40%  | JSONB faster by 139%  | 60%               | 239%                |
| S4_ts_range      | REL faster by 34%  | REL faster by 73%     | 66%               | 27%                 |
| S5_array_and     | REL faster by 56%  | JSONB faster by 121%  | 44%               | 221%                |
| S6_array_or      | REL faster by 74%  | JSONB faster by 71%   | 26%               | 171%                |
| S7_and2          | JSONB faster by 7% | REL faster by 1%      | 107%              | 99%                 |
| S8_and3          | REL faster by 98%  | JSONB faster by 3129% | 2%                | 3229%               |
| S9_or_keys       | REL faster by 73%  | REL faster by 54%     | 27%               | 46%                 |