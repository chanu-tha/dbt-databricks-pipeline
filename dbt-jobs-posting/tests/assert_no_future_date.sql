SELECT
    job_id,
    search_date
FROM {{ ref('stg_job_postings') }}
WHERE search_date > current_date()