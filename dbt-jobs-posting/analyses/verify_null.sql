SELECT *
FROM {{ ref('stg_job_postings') }}
WHERE job_id IS NULL