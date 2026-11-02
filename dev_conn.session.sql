SELECT
	operation,
	opearationMetrics['numOutputRows'] as rows_written,
	opearationMetrics['numSourceRows'] as rows_merge_in,
	opearationMetrics['numTargetRowsUpdated'] as rows_updated,
	opearationMetrics['numTargetRowsInserted'] as rows_inserted
	
FROM (DESCRIBE HISTORY dbt_job_posting_dev.marts.fct_job_postings)
WHERE operation IN ('CREATE OR REPLACE TABLE AS SELECT', 'MERGE')
ORDER BY version DESC