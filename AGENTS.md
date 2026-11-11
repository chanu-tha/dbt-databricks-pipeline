# Repository Policy: Databricks Asset Bundles (DAB) - Learning & Development Project

When reviewing, validating, or debugging bundle files (`databricks.yml`, `resources/*.yml`):

## 1. Target Isolation
- `dev`: Specify `mode: development` (enforces user-isolated workspace paths and pauses schedules).
- `prod`: Specify `mode: production` (activates production run behavior). Can deploy under the user's workspace path or `/Workspace/Shared/.bundle/...` for testing.

## 2. Identity & Governance (Beginner / Personal Sandbox)
- **Personal Auth Allowed:** Using personal OAuth authentication (such as Databricks CLI / VS Code connection profile) is permitted for testing both `dev` and `prod`.
- **Service Principal (`run_as`):** Optional for this project. Only recommend it as an advanced enterprise best practice, not as a blocking requirement.
- **Permissions:** Optional for single-user learning environments.

## 3. Variable Hygiene & Secrets
- Environments, schemas, catalogs, and resource paths (e.g. notebook paths) must be parameterized in `variables` and referenced as `${var.<variable_name>}` to prevent cross-environment bugs.
- No plaintext tokens or secrets in YAML files. Use Databricks Secret Scopes (`{{secrets/<scope>/<key>}}`) or extension-managed authentication.

## 4. Review Output Format
When asked to evaluate or audit bundle configurations, provide:
1. **Overall Verdict:** [Ready | Needs Revision | Blocked]
2. **Beginner-Friendly Explanation:** Clearly explain what needs to be changed and why, without unnecessary enterprise jargon.
3. **Exact YAML diff fix:** Provide ready-to-use YAML diffs to help fix any issues quickly.
