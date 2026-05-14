# Delivery Health

_Generated: 2026-05-14T18:00:00-05:00_
_Repos covered: alerts_ui_

## Summary

`alerts_ui` exhibits strong delivery health for a small internal tool. The team ships ~2 PRs/day to `main`, auto-deploys every push to staging, and has shipped 19 versioned releases in the last 90 days (~1 release per 5 days). The CI pipeline is comprehensive — compile, format, credo, sobelow, tests with coverage, and dialyzer all gate every PR. The main gaps are: production deployment requires a manual release tag (no full CD), 14 stale unmerged branches suggest incomplete or abandoned work, and 8 open Dependabot PRs are waiting to be merged. Change failure rate (4 reverts in 90 days / ~159 commits ≈ 2.5%) is within the Elite band, though MTTR is not measurable from git history alone.

**Overall grade:** A-

## Framework anchors

- DORA / Accelerate — Deployment frequency, lead time for changes, change failure rate, time to restore service
- Trunk-based development — branch hygiene as a delivery indicator

## DORA Proxy Assessment

| DORA Metric | Proxy Basis | Estimated Band | Notes |
|-------------|-------------|----------------|-------|
| Deployment frequency | 19 release tags in 90 days (v0.0.12 → v0.0.30); ~2 PRs/day to `main`; auto-deploy to staging on every push | **High** (daily–weekly) | Release to prod ~every 5 days; staging deployed continuously |
| Lead time for changes | Squash-merge workflow loses branch timestamps; PR numbering suggests ~200 feature PRs/90 days; branch age on unmerged branches ranges 1–30 days | **High** (1 day–1 week) | Squash merges prevent exact measurement — bucket is directional |
| Change failure rate | 4 reverts in last 90 days out of 159 commits ≈ 2.5% | **Elite** (0–15%) | Reverts: #1038, #955, #942, #870 — all quick turnarounds |
| Time to restore | Not measurable from git; no incident data available | Not measured | See Confidence note |

## Findings

### F1 — Production requires a manual release tag; no full CD to production

- **Severity:** Medium
- **Location:** `.github/workflows/deploy-prod.yml`
- **Evidence:**
  ```yaml
  on:
    workflow_dispatch:
    release:
      types:
        - released
  ```
  Production deployment triggers on `workflow_dispatch` (manual button) or a GitHub Release creation. Staging and `dev-orange` auto-deploy on every push to `main` (`deploy-on-push.yml`). Production is a deliberate manual gate.
- **Impact:** Every production release requires a human to create a GitHub Release (tag + release notes). This is a reasonable risk control for a transit-critical operations tool — operators must be deliberate about what reaches production. The gap is that there is no defined staging-to-production promotion SLA; releases can sit in staging for varying durations before promotion. The manual step also means releases can be forgotten if the person who merged to `main` does not follow through. (DORA — deployment frequency)

### F2 — 14 stale unmerged remote branches (>90 days, no merge to `main`)

- **Severity:** Low
- **Location:** Remote branch list
- **Evidence:** `git for-each-ref` identifies 14 branches with last activity before 2026-02-13. The oldest date to 2024-03 (`mss-progress-steps`, `mss-api-auth-poc-client`, `mss-api-auth-poc-server`). Branches include work-in-progress on features (e.g. `hp/duplicate-alert-optional-tests`, `hp/redefine-alert-status`, `hp/alert-details-modal`) and abandoned experiment branches.
- **Impact:** Stale branches are low operational risk but indicate abandoned or parked work that was never finished or formally closed. They accumulate noise in the branch list and can confuse new contributors about what is in-progress. The 2024 branches (`mss-*`) appear to be pre-project POC work. (Trunk-based development — branch hygiene)

### F3 — 8 open Dependabot PRs unmerged

- **Severity:** Low
- **Location:** `origin/dependabot/*` remote branches
- **Evidence:** 8 Dependabot branches pending merge: `credo-1.7.18`, `ecto-3.13.6`, `ex_json_schema-0.11.3`, `finch-0.22.0`, `oban-2.22.1`, `oban_web-2.12.4`, `phoenix_live_view-1.1.20`, `postgrex-0.22.2`. All are patch or minor version bumps.
- **Impact:** Pending dependency updates accumulate security and compatibility debt. Individually, minor/patch bumps are low risk. In aggregate, allowing Dependabot PRs to pile up creates batch-merge risk — merging 8 updates at once increases the chance of an incompatibility. The project currently merges ~8 Dependabot PRs per 90 days (from git log history), so this is not a systematic avoidance, but periodic catch-up. (DORA — lead time for changes)

### F4 — No CODEOWNERS file

- **Severity:** Low
- **Location:** `.github/CODEOWNERS` (absent)
- **Evidence:** No `CODEOWNERS` file found. Review assignments are manual.
- **Impact:** For a small team, the absence of CODEOWNERS is low risk — the team likely knows who reviews what. As the team grows or contributor base expands, component-level review routing ensures the right person reviews the right code. Without it, all PRs default to voluntary review. Not a pressing concern at current scale.

## CI/CD Configuration

| Dimension | Configuration | Assessment |
|-----------|---------------|------------|
| CI provider | GitHub Actions | Reliable; all workflows in `.github/workflows/` |
| Triggers | `push` + `pull_request` (all branches) | Every commit CI-checked — good |
| CI steps | compile → format → credo → sobelow → tests (--cover) → dialyzer | Comprehensive; warnings-as-errors on compile |
| Coverage artifact | Uploaded via `actions/upload-artifact@v4` after each CI run | Coverage available for inspection |
| Deploy automation | Push to `main` → auto-deploy `dev-orange` + `staging` | Continuous staging deployment |
| Production deploy | Manual release tag or `workflow_dispatch` | Deliberate gate; no accidental prod deploys |
| Deploy target | AWS ECS/ECR per environment (`deploy-base.yml`) | Infrastructure-as-code pattern via reusable workflow |
| Slack notification | On every deploy, success or failure | Good operational visibility |
| Asana integration | PR → Asana task attachment created on open/reopen | Ticket linking automated |
| Secret management | GitHub OIDC (`id-token: write`) for AWS; secrets inherited from GitHub environment | Correct use of OIDC; no long-lived AWS keys in secrets |
| Concurrent deploys | `concurrency: ${{ inputs.environment }}` in base workflow | No simultaneous deploys to same environment |

## Branch Hygiene

| Metric | Value |
|--------|-------|
| Unmerged remote branches | 49 total |
| Stale (>90 days unmerged) | 14 |
| Dependabot pending | 8 |
| Active feature branches (active in last 30 days) | ~10 |
| Force pushes to `main` | Not detected |
| Conventional commits adherence | Partial — informal free-form; some Dependabot PRs use `build(deps):` prefix |

## Metrics

| Repo | Metric | Value | Notes |
|------|--------|-------|-------|
| alerts_ui | Deployment frequency (prod) | ~1 release/5 days | 19 tagged releases in 90 days |
| alerts_ui | Deployment frequency (staging) | Continuous | Every push to `main` |
| alerts_ui | Lead time for changes | High (1 day – 1 week) | Squash-merge workflow prevents exact measurement |
| alerts_ui | Change failure rate proxy | ~2.5% | 4 reverts / 159 commits in 90 days — Elite band |
| alerts_ui | Time to restore | Not measured | No incident history available |
| alerts_ui | CI provider | GitHub Actions | Full pipeline on every push/PR |
| alerts_ui | Stale branches | 14 | >90 days, unmerged |
| alerts_ui | Dependabot PRs pending | 8 | Minor/patch updates only |
| alerts_ui | CODEOWNERS | Absent | Manual review assignment |
| alerts_ui | Revert commits (last 90 days) | 4 | All quick reverts (same day or next day) |
| alerts_ui | Total PRs merged (last 90 days) | ~200 | Based on PR number delta #842 → #1041 |

## Recommendations

- **R1** — Establish a documented staging-to-production promotion SLA (e.g. "staging changes are promoted to production within 2 business days unless blocked"). This makes the manual gate explicit and prevents releases sitting in staging indefinitely. [Horizon: next] [Risk reduction: Med]
- **R2** — Merge open Dependabot PRs as a regular maintenance rhythm (weekly or bi-weekly). Consider enabling auto-merge for Dependabot patch-version bumps that pass CI. [Horizon: now] [Risk reduction: Low]
- **R3** — Archive or close the 14 stale unmerged branches. For any branch representing intentionally parked work, convert it to a draft PR with a description of the remaining work. Delete branches with no open PR. [Horizon: now] [Risk reduction: Low]
- **R4** — Add a `CODEOWNERS` file that routes PRs touching `lib/alerts_ui/jobs/`, `lib/alerts_ui/feed_output/`, and the two alert-creation flows to relevant owners. [Horizon: later] [Risk reduction: Lo]

## Confidence

- **Deployment frequency** is directly observed from git tags and `deploy-on-push.yml` — high confidence.
- **Lead time bucket** is directional due to squash merges; exact per-PR lead time cannot be extracted from git history. Bucket is assessed as High (1 day–1 week) based on branch naming conventions and PR cadence.
- **Change failure rate proxy (2.5%)** is computed from revert commit count, not from actual deployment failure incidents. A revert may not be a production failure (it may be a same-day pre-release reversal). This figure is a rough floor estimate; actual production change failure rate could be higher if staging-only issues are not tracked.
- **MTTR** is not measurable from git history. No production incident log or PagerDuty/Sentry incident history was available.
- **Stale branch count** is from `git for-each-ref` on remotes; reflects branches not yet merged to `main`, including long-lived experiment and POC branches.
