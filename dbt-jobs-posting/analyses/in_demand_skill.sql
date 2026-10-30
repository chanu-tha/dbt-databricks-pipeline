WITH job_postings AS (
    SELECT 
        job_id,
        search_term
    FROM {{ ref('fct_job_postings') }}
    {% if var('job_title', none) -%}
        WHERE search_term = '{{ var("job_title") }}'
    {%- endif %}    
),
bridge_items AS (
    SELECT
        job_id,
        skill_id
    FROM {{ ref('bridge_job_skills') }}
),
skill AS (
    SELECT * FROM {{ ref('dim_skill') }}
)

SELECT
    display_name,
    category,
    COUNT(distinct job_id) as demand_posting,
    ROUND(COUNT(distinct job_id) / (SELECT COUNT(DISTINCT job_id) FROM job_postings) * 100.0, 1) AS count_pct
FROM bridge_items
INNER JOIN skill USING (skill_id)
INNER JOIN job_postings USING (job_id)
GROUP BY display_name, category
ORDER BY demand_posting DESC