# Next Session Context & Handoff Guide

## 1. Current State & Where We Left Off

### Fixed:
- **dbt debug target failure in Databricks Workflows:**
  - In Databricks Asset Bundles (DAB), a managed `dbt_task` using a SQL warehouse auto-generates a profile with target name `databricks_cluster`.
  - [`resources/job_postings_pipeline.yml`](file:///D:/Beam/DataEngineerCareer/dbt_luke/dbt-databricks-pipeline/resources/job_postings_pipeline.yml) was updated to remove `--target ${bundle.target}` (defaulting to `databricks_cluster`) and added `schema: default`.

### Pending Fixes:
1. **Decouple Personal Profile in `databricks.yml`:**
   - Remove `profile: ChanuThaDatabricksConn` from both `dev` and `prod` targets in [`databricks.yml`](file:///D:/Beam/DataEngineerCareer/dbt_luke/dbt-databricks-pipeline/databricks.yml).
   - *Why:* Keeps CI/CD completely isolated (using `DATABRICKS_HOST` & `DATABRICKS_TOKEN` from GitHub Secrets without looking for `/home/runner/.databrickscfg`). Local development continues using OAuth via VS Code extension or `-p ChanuThaDatabricksConn`.
2. **Fix Typos in CI Workflow:**
   - In [`.github/workflows/ci.yml`](file:///D:/Beam/DataEngineerCareer/dbt_luke/dbt-databricks-pipeline/.github/workflows/ci.yml):
     - Line 23 & 30: `DATABRCIKS_TOKEN` ➔ `DATABRICKS_TOKEN`
     - Line 32: `--taget prod` ➔ `--target prod`

---

## 2. Established Rules & Quirks for this Project

- **DAB `dbt_task` Target Name:** Always let Databricks use its default target (`databricks_cluster`) unless using a custom `profiles_directory`. Environment separation is done via bundle variables (`catalog`, `warehouse_id`), not dbt target flags.
- **CI/CD vs Local Isolation:** Do not hardcode developer profile names in `databricks.yml`. CI runs headless via env vars; local runs interactive via OAuth.
- **Git Tracking Rules:**
  - Commit: `AGENTS.md`, `NEXT_SESSION.md`, `.github/workflows/*`.
  - Ignore: `.gemini/skills/`, and any `profiles.yml` containing plaintext personal tokens.

---

## 3. Step-by-Step Actions to Resume Next Session

### Step 1: Update `databricks.yml`
Remove `profile: ChanuThaDatabricksConn` under `dev.workspace` and `prod.workspace`.

### Step 2: Update `.github/workflows/ci.yml`
Fix the spelling of `DATABRICKS_TOKEN` and `--target prod`.

### Step 3: Validate & Push
```powershell
# 1. Test bundle locally with OAuth
databricks bundle validate -p ChanuThaDatabricksConn

# 2. Stage and commit
git add databricks.yml .github/workflows/ci.yml resources/job_postings_pipeline.yml NEXT_SESSION.md
git commit -m "fix(ci): isolate CI auth and fix dbt task target"
git push origin <your-branch>
```

### Step 4: Verify GitHub Actions
Check the Actions tab in GitHub to confirm the `CI - Validate Bundle` workflow passes.
