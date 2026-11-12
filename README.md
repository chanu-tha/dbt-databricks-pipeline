# Production Job Postings Pipeline — dbt + Databricks Asset Bundles (DAB)

[![CI - Validate Bundle](https://github.com/chanutha/dbt-databricks-pipeline/actions/workflows/ci.yml/badge.svg)](.github/workflows/ci.yml)
[![CD - Deploy Pipeline](https://github.com/chanutha/dbt-databricks-pipeline/actions/workflows/cd-bundle-prod.yml/badge.svg)](.github/workflows/cd-bundle-prod.yml)
![Databricks](https://img.shields.io/badge/Platform-Databricks-FF3621?logo=databricks&logoColor=white)
![dbt](https://img.shields.io/badge/Transform-dbt--databricks-FF694B?logo=dbt&logoColor=white)
![IaC](https://img.shields.io/badge/IaC-Databricks_Asset_Bundles-00A4E4)
![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=githubactions&logoColor=white)

![Pipeline Architecture](img/pipeline_architecture.png)
*(Architecture diagram placeholder)*

---

## 📌 Executive Summary

An enterprise-ready, end-to-end analytics engineering pipeline built on **Databricks** and **dbt**, orchestrated using **Databricks Asset Bundles (DAB)** with automated **GitHub Actions CI/CD** and an automated **cold-start snapshot backfill engine**.

This project transforms 840,000+ raw job posting records through the Medallion Architecture into an analytics-ready Star Schema and SCD Type 2 historical dimension, completely deployed and managed as **Infrastructure-as-Code (IaC)**.

> 💡 **Project Context & Evolution:**  
> This project originated from the core data modeling concepts in Luke Barousse's *dbt for Data Analytics & Engineering Course* (Project #2). While the original course baseline demonstrated manual script executions and local dbt runs, **this project evolves the architecture to enterprise production standards**:
> 1. Replacing manual workflows with **Databricks Asset Bundles (DAB)** for pure declarative IaC.
> 2. Orchestrating native Databricks Workflows with isolated tasks (`load_raw` notebook &rarr; native `dbt_task` runner).
> 3. Eliminating manual SQL editor execution with an **automated cold-start backfill macro** (`backfill_if_needed`).
> 4. Implementing full **GitOps CI/CD** with PR validation and gated production approvals.

---

## 🏗️ Architecture & What Was Built

| Capability | How It Was Implemented | Where to Look |
| --- | --- | --- |
| **Infrastructure as Code (IaC)** | Declarative Databricks Asset Bundle configuring multi-environment targets (`dev` & `prod`), catalog variables, and workspace paths | [`databricks.yml`](databricks.yml) |
| **Native Workflow Orchestration** | Multi-task Databricks Job chaining raw ingestion notebooks to native `dbt_task` running on Databricks Serverless/SQL compute | [`resources/job_postings_pipeline.yml`](resources/job_postings_pipeline.yml) |
| **Automated Cold-Start Backfill** | Programmatic dbt macro operation inspecting Unity Catalog metadata to automatically backfill 1 year of SCD2 history on cold deploys | [`macros/backfill_if_needed.sql`](dbt-jobs-posting/macros/backfill_if_needed.sql) |
| **CI/CD & GitOps** | GitHub Actions validating bundles on pull requests, auto-deploying to `dev`, and gating `prod` with environment protection rules | [`.github/workflows/`](.github/workflows/) |
| **Star Schema Modeling** | Medallion architecture: raw &rarr; staging (`stg_`) &rarr; intermediate (`int_`) &rarr; fact (`fct_job_postings`), dimensions, and bridge | [`models/marts/`](dbt-jobs-posting/models/marts/) |
| **SCD Type 2 Snapshots** | Tracks salary and posting requirement changes across time using the `check` strategy over 13 attribute columns | [`snapshots/snapshot.yml`](dbt-jobs-posting/snapshots/snapshot.yml) |
| **Incremental Fact Processing** | High-water mark incremental merge on `job_id` and `search_date` for efficient daily loads | [`fct_job_postings.sql`](dbt-jobs-posting/models/marts/fct_job_postings.sql) |
| **Data Quality & Testing** | Generic schema tests (`unique`, `not_null`, `relationships`) alongside custom singular assertion tests | [`tests/`](dbt-jobs-posting/tests/) |

---

## ⚙️ The Data Pipeline & Medallion Layers

The data pipeline processes real job market scrapes through three distinct layers:

![Lineage Graph](img/lineage.png)
*(Lineage graph placeholder)*

1. **Bronze (Raw / Staging):**
   - Ingested via scheduled Databricks notebook into Delta Lake tables.
   - Staging models (`stg_job_postings`, `stg_job_skills`, `stg_skills`) standardize column naming, sanitize null timestamps, and parse salary ranges.
2. **Silver (Intermediate & Snapshots):**
   - `int_job_postings`: Standardizes remote work flags, benefits, and salary conversions.
   - `job_postings_snapshot`: Captures SCD Type 2 history across 13 monitored columns (e.g., salary swings, remote status changes, benefits).
3. **Gold (Marts - Star Schema):**
   - **Fact Table:** `fct_job_postings` (materialized incrementally via `merge`).
   - **Dimension Tables:** `dim_companies`, `dim_skills`.
   - **Bridge Table:** `bridge_job_skills` resolving many-to-many relationships between jobs and required technologies.

---

## 🚀 Key Engineering Upgrades

### 1. Databricks Asset Bundles (DAB) & IaC
Instead of configuring jobs through the Databricks UI, the entire compute, scheduling, task dependencies, and environment parameters are defined in code:
- **Environment Isolation:** Parameterized catalogs (`dbt_job_posting_dev` vs `dbt_job_posting_prod`), notebook scripts, and SQL warehouses.
- **Development Safety:** Dev targets use `mode: development`, prefixing resource names and isolating deployments to user-specific workspace paths.

### 2. Automated Cold-Start Backfill Engine (`backfill_if_needed`)
In typical snapshot workflows, backfilling historical data requires manually pasting custom SQL scripts into the warehouse. Here, the process is fully automated via a custom dbt macro:
```sql
-- Executed automatically during pipeline initialization:
dbt run-operation backfill_if_needed
```
- **Idempotent Inspection:** Queries Unity Catalog's information schema using adapter relations.
- **Cold Run:** If the snapshot table is missing, it dynamically generates and materializes the partitioned SCD2 table with generated `dbt_scd_id`, `dbt_valid_from`, and `dbt_valid_to` timestamps.
- **Warm Run:** If the table already exists, it skips execution and seamlessly hands off to incremental `dbt build`.

### 3. Native Databricks Orchestration
Rather than orchestrating dbt via external virtual machines or CLI wrappers, the pipeline uses Databricks native `dbt_task`:
```yaml
tasks:
  - task_key: load_raw_to_delta_table
    notebook_task:
      notebook_path: ${var.notebook_path}
  - task_key: monthly_dbt_run
    depends_on:
      - task_key: load_raw_to_delta_table
    dbt_task:
      project_directory: ../dbt-jobs-posting
      commands:
        - dbt deps
        - dbt debug
        - dbt run --select stg_job_postings
        - dbt run-operation backfill_if_needed
        - dbt build
      warehouse_id: ${var.warehouse_id}
      catalog: ${var.catalog}
```
- **Zero Secrets / Ephemeral Tokens:** The native runner authenticates directly using Databricks managed identity, eliminating the need to store long-lived tokens or credentials in GitHub Secrets or YAML files.

### 4. GitOps CI/CD Pipelines
Two GitHub Actions workflows automate validation and deployment:
1. **Continuous Integration ([`ci.yml`](.github/workflows/ci.yml)):**
   - Runs on every Pull Request to `main`.
   - Lints and validates Databricks Asset Bundles across both `dev` and `prod` targets (`databricks bundle validate`).
2. **Continuous Deployment ([`cd-bundle-prod.yml`](.github/workflows/cd-bundle-prod.yml)):**
   - Runs on merge to `main`.
   - Step 1: Deploys bundle to the `dev` target.
   - Step 2: Gated deployment to `prod` using GitHub Environment protection rules with mandatory reviewer approval.

---

## 🧪 Data Quality & Testing

Data integrity is guarded at every stage using both built-in schema assertions and custom domain tests:

- **Null Handling:** `not_null` assertions caught and isolated 6,000+ malformed scrapes lacking IDs.
- **Referential Integrity:** `relationships` tests guarantee every foreign key in `bridge_job_skills` maps to valid records in `dim_skills` and `fct_job_postings`.
- **Custom Business Rules:**
  - `assert_million_salary_sane`: Singular test preventing realistic wage analysis distortion from mistyped compensation outliers (e.g., hourly rates submitted as annual salaries).
  - `assert_no_future_dates`: Prevents ingestion of scrapes with future timestamp anomalies.

---

## 📁 Repository Structure

```text
├── .github/
│   └── workflows/
│       ├── ci.yml                     # PR validation for dev & prod bundles
│       └── cd-bundle-prod.yml         # Automated dev deploy & gated prod release
├── databricks.yml                     # Databricks Asset Bundle definition (IaC)
├── resources/
│   └── job_postings_pipeline.yml      # Databricks Job & multi-task orchestration
├── src/
│   ├── load_raw_dev.ipynb             # Ingestion notebook (dev)
│   └── load_raw_to_table_prod.ipynb   # Ingestion notebook (prod)
├── dbt-jobs-posting/                  # Core dbt project
│   ├── dbt_project.yml
│   ├── packages.yml                   # Package dependencies (dbt_utils)
│   ├── macros/
│   │   ├── backfill_if_needed.sql     # Automated cold-start snapshot backfill
│   │   ├── parse_salary.sql           # Salary standardization macro
│   │   └── generate_schema_name.sql   # Custom schema routing
│   ├── models/
│   │   ├── staging/                   # Cleaned raw scrapes
│   │   ├── intermediate/              # Business logic & pre-aggregations
│   │   └── marts/                     # Star schema (fact, dims, bridge)
│   ├── snapshots/                     # SCD2 snapshot definitions
│   ├── seeds/                         # Skill taxonomies & reference tables
│   └── tests/                         # Singular business rule test assertions
└── scripts/
    └── backfill_script.sql            # Standalone SQL reference for backfills
```

---

## 💻 Local Development & Quickstart

### Prerequisites
- Python 3.10+ & `uv` (or `pip`)
- [Databricks CLI (v0.200+)](https://docs.databricks.com/en/dev-tools/cli/databricks-cli.html)
- Access to a Databricks workspace (e.g., Free Community Edition or standard workspace)

### Setup & Validation
```bash
# 1. Clone the repository
git clone https://github.com/chanutha/dbt-databricks-pipeline.git
cd dbt-databricks-pipeline

# 2. Authenticate Databricks CLI
databricks auth login --host <your-databricks-host>

# 3. Validate the Databricks Asset Bundle
databricks bundle validate --target dev

# 4. Deploy the pipeline to your development environment
databricks bundle deploy --target dev

# 5. Run the pipeline in Databricks
databricks bundle run job_posting_pipeline --target dev
```

---

## 👤 Author & Acknowledgments

- **Author:** Chanutha (Beam)
- **LinkedIn / Portfolio:** [Connect on LinkedIn](https://www.linkedin.com)
- **Acknowledgments:** Inspired by Luke Barousse's *dbt for Data Analytics & Engineering Course*, upgraded with enterprise Databricks Asset Bundles, automated backfills, and GitHub Actions CI/CD.
