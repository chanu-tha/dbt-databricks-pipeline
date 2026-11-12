{% macro backfill_if_needed() %}
  {% set target_table = adapter.get_relation(
      database=target.catalog,
      schema='snapshots',
      identifier='job_postings_snapshot'
  ) %}

  {% if target_table is none %}
    {{ log("First run detected: Snapshot table missing. Executing backfill...", info=True) }}
    
    {# 1. Ensure snapshots schema exists #}
    {% do run_query("CREATE SCHEMA IF NOT EXISTS " ~ target.catalog ~ ".snapshots") %}

    {# 2. Run the backfill query #}
    {% set backfill_sql %}
      CREATE OR REPLACE TABLE {{ target.catalog }}.snapshots.job_postings_snapshot AS
      WITH deduped AS (
          SELECT *
          FROM {{ target.catalog }}.staging.stg_job_postings
          QUALIFY ROW_NUMBER() OVER (
              PARTITION BY job_id, search_date
              ORDER BY search_at DESC
          ) = 1
      ),
      sigged AS (
          SELECT *,
              MD5(CONCAT_WS('||',
                  COALESCE(job_title, '~'), COALESCE(company_name, '~'),
                  COALESCE(job_location, '~'), COALESCE(job_schedule_type, '~'),
                  COALESCE(CAST(job_work_from_home AS STRING), '~'),
                  COALESCE(CAST(salary_min AS STRING), '~'),
                  COALESCE(CAST(salary_max AS STRING), '~'),
                  COALESCE(salary_period, '~'), COALESCE(salary_currency, '~'),
                  COALESCE(CAST(has_health_insurance AS STRING), '~'),
                  COALESCE(CAST(has_dental_insurance AS STRING), '~'),
                  COALESCE(CAST(has_paid_time_off AS STRING), '~'),
                  COALESCE(CAST(has_no_degree_mentioned AS STRING), '~')
              )) AS _sig
          FROM deduped
      ),
      versions AS (
          SELECT *
          FROM (
              SELECT *,
                  LAG(_sig) OVER (PARTITION BY job_id ORDER BY search_at) AS _prev_sig
              FROM sigged
          )
          WHERE _prev_sig IS NULL OR _sig != _prev_sig
      )
      SELECT
          * EXCEPT (_sig, _prev_sig),
          MD5(CONCAT(job_id, '|', CAST(search_at AS STRING))) AS dbt_scd_id,
          search_at AS dbt_updated_at,
          search_at AS dbt_valid_from,
          LEAD(search_at) OVER (PARTITION BY job_id ORDER BY search_at) AS dbt_valid_to
      FROM versions
    {% endset %}
    
    {% do run_query(backfill_sql) %}
    {{ log("Snapshot backfill complete.", info=True) }}
  {% else %}
    {{ log("Snapshot table already exists. Skipping backfill.", info=True) }}
  {% endif %}
{% endmacro %}
