

WITH job_skills AS (
    SELECT * FROM {{ ref('stg_job_skills') }}
) 

SELECT
    skill_id,
    COUNT(DISTINCT job_id) AS postings_with_skill
FROM job_skills
GROUP BY skill_id