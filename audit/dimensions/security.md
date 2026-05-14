# Security

_Generated: 2026-05-14T16:10:00-05:00_
_Repos covered: alerts_ui_

## Summary

The `alerts_ui` security posture is generally sound: authentication is via OIDC/Keycloak with session fixation protection and enforced expiry; all database access uses Ecto's parameterized query DSL; HSTS and CSRF protection are configured in all browser pipelines; and Sobelow runs in CI on every push. No committed secrets were found. The two most significant findings are: the API endpoint decodes all incoming JSON keys to atoms (`Jason.decode!(keys: :atoms)`), which is a known BEAM atom-table exhaustion vector; and the Swagger UI at `/api/swagger` is unauthenticated, exposing the API schema to anyone. The CSP configuration also permits `'unsafe-inline'` scripts and styles, weakening XSS mitigation.

**Overall grade:** B

## Framework anchors

- OWASP Top 10 (2021) — primary risk classification
- OWASP ASVS — Application Security Verification Standard
- CWE — specific weakness enumeration per finding
- ISO/IEC 5055 — security rules

## Findings

### F1 — `Jason.decode!(keys: :atoms)` on externally-supplied API request body

- **Severity:** High
- **Location:** `lib/alerts_ui_web/controllers/api_controller.ex:40`
- **Evidence:** `params |> Jason.encode!() |> Jason.decode!(keys: :atoms)` converts all JSON keys in the incoming request body to atoms. In the BEAM VM, atoms are never garbage-collected and the default table limit is ~1,048,576. A malicious authenticated client sending requests with many unique JSON keys can exhaust the table, crashing the VM.
- **Impact:** Denial-of-service against the BEAM node. The endpoint is protected by JWT (`require_authenticated_api_user`), which limits exposure to authenticated API callers — but any user with an `api-writer` role in Keycloak can trigger this. (CWE-400: Uncontrolled Resource Consumption; OWASP A05 — Security Misconfiguration)

### F2 — Swagger UI unauthenticated at `/api/swagger`

- **Severity:** Medium
- **Location:** `lib/alerts_ui_web/router.ex:204-206`
- **Evidence:** The `/api/swagger` scope uses no `pipe_through` pipeline — no `require_authenticated_user`, no viewer role check. `forward "/", PhoenixSwagger.Plug.SwaggerUI, ...` is accessible to unauthenticated users. All other routes in the app require at least viewer-level OIDC authentication.
- **Impact:** The API schema (endpoint paths, parameter names, expected payloads) is visible to unauthenticated users, aiding reconnaissance. For an internal transit-ops tool, this is a configuration inconsistency rather than an immediate exploitation vector, but it violates the principle of least privilege. (CWE-200: Exposure of Sensitive Information; OWASP A01 — Broken Access Control)

### F3 — CSP allows `'unsafe-inline'` for both `script-src` and `style-src`

- **Severity:** Medium
- **Location:** `lib/alerts_ui_web/router.ex:31`
- **Evidence:** `"content-security-policy" => "... style-src 'self' 'unsafe-inline'; script-src 'self' https://edge.fullstory.com https://rs.fullstory.com 'unsafe-inline'; connect-src 'self' ... 'unsafe-inline';"`. The `'unsafe-inline'` directive in `script-src` permits execution of inline JavaScript, which eliminates the primary XSS defence that CSP provides. `connect-src 'unsafe-inline'` is also non-standard and likely unintentional.
- **Impact:** If an XSS vector is ever introduced, the CSP provides no defence. Phoenix's HEEx templating auto-escapes content, which is the primary mitigation — but defence in depth is weakened. The `connect-src 'unsafe-inline'` entry is non-standard (no major browser interprets it); it should be reviewed for intent. (CWE-693: Protection Mechanism Failure; OWASP A05 — Security Misconfiguration)

### F4 — `String.to_existing_atom` on URL query parameter without error handling

- **Severity:** Low
- **Location:** `lib/alerts_ui_web/live/view_alerts_live.ex:97`
- **Evidence:** `order_by = String.to_existing_atom(params["order_by"])` — the `order_by` URL parameter is converted to an atom without a `rescue` clause. `String.to_existing_atom/1` raises `ArgumentError` if the string has no matching atom in the table.
- **Impact:** An authenticated user (viewer role) sending an arbitrary `?order_by=nonexistent_atom` query string will trigger an unhandled exception. Phoenix will rescue this as a 500 response, but the crash will be logged and may surface in Sentry. The existing atoms in the table are unlikely to be exhausted by this pattern (it uses `to_existing_atom`, not `to_atom`), so this is reliability rather than security. (CWE-703: Improper Check or Handling of Exceptional Conditions)

### F5 — GitHub Actions workflows pin to mutable tags, not SHA hashes

- **Severity:** Low
- **Location:** `.github/workflows/elixir.yml` (all `uses:` lines)
- **Evidence:** `uses: actions/checkout@v5`, `uses: actions/cache@v5`, `uses: actions/upload-artifact@v4`, `uses: mbta/actions/reshim-asdf@v2` — all pinned to mutable version tags, not commit SHAs.
- **Impact:** A compromised GitHub Action (supply chain attack) at a given tag can silently execute malicious code during CI, including exfiltrating secrets injected as env vars. This is a low-probability risk for well-maintained official actions but non-zero. (CWE-829: Inclusion of Functionality from Untrusted Control Sphere; OWASP A08 — Software and Data Integrity Failures)

## OWASP Top 10 Walkthrough

| # | Category | Status | Notes |
|---|---------|--------|-------|
| A01 | Broken Access Control | Partial ⚠️ | RBAC with viewer/author/developer tiers; Oban dashboard requires developer role; LiveView sessions use `ensure_authenticated` on_mount; Swagger UI unauthenticated (F2). No IDOR concern identified — alerts are a shared organizational resource, not user-owned. |
| A02 | Cryptographic Failures | Low risk | `SECRET_KEY_BASE` required from env in prod; DB uses TLS with `verify_peer`; no local password hashing (OIDC delegates to Keycloak). Dev/test keys in `config/dev.exs` and `config/test.exs` are standard Phoenix convention — not production secrets. |
| A03 | Injection | Low risk | All DB access via Ecto parameterized queries; `fragment/2` uses bind params (`^value`). `String.to_existing_atom` on URL param (F4) is a reliability issue, not injection. No shell command execution found. |
| A04 | Insecure Design | Not observed | No obvious design-level security weaknesses; access control is pipeline-based and consistent. |
| A05 | Security Misconfiguration | Present ⚠️ | `unsafe-inline` in CSP (F3); Swagger UI unauthenticated (F2); atom exhaustion in API endpoint (F1). |
| A06 | Vulnerable & Outdated Components | Not confirmed | Phoenix 1.8.6, LiveView 1.0.1, Ecto 3.13.2 appear current. Hackney 1.25.0. No high-CVE-history packages identified by LLM knowledge, but no SCA tool was run — recommend `mix deps.audit` via `mix_audit` or Sobelow's dependency checks. |
| A07 | ID & Auth Failures | Low risk | OIDC via Keycloak with session renewal on login, max_session_time and idle_time enforced, session ID rotated on login/logout via `configure_session(renew: true)` and `clear_session()`. API endpoints validate JWT RS256 signature. |
| A08 | Software & Data Integrity Failures | Low risk | `mix.lock` ensures reproducible builds. GitHub Action tags not SHA-pinned (F5). No unsigned artifact concern in Docker build. |
| A09 | Security Logging & Monitoring | Partial | Sentry 12.0 integrated for error tracking. `Logger` used in Oban job failures, feed export. No explicit security-event logging (failed auth attempts, role escalation). |
| A10 | SSRF | Not observed | External HTTP calls go to configured URLs (`API_URL`, `IBI_ENHANCED_ALERTS_API_URL`) set via env vars, not from user input. No user-controlled URL fetching found. |

## Metrics

| Repo | Metric | Value | Notes |
|------|--------|-------|-------|
| alerts_ui | Committed secrets found | 0 | `.envrc` is gitignored; `SECRET_KEY_BASE` in `dev.exs`/`test.exs` is standard Phoenix convention |
| alerts_ui | OWASP A05 (misconfiguration) findings | 3 | F1 (atom DoS), F2 (Swagger), F3 (CSP unsafe-inline) |
| alerts_ui | Auth scheme | OIDC/Keycloak + session cookies (browser), JWT RS256 (API) | |
| alerts_ui | Sobelow in CI | Yes | Runs on every push; `DOS.StringToAtom` skip in `alert_history.ex` is annotated with justification |
| alerts_ui | Dependency manifests with apparent stale majors | 0 confirmed | LLM-driven; no SCA tool run |
| alerts_ui | GitHub Actions SHA-pinned | No | All `uses:` lines pin to mutable version tags |

## Recommendations

- **R1** — Replace `Jason.decode!(keys: :atoms)` in `api_controller.ex` with `Jason.decode!(keys: :strings)` and update `AlertFromApi.fill_in_alert/1` to accept string-keyed maps (or use `Map.new(map, fn {k, v} -> {String.to_existing_atom(k), v} end)` only for known keys). [Horizon: now] [Risk reduction: Hi]
- **R2** — Add authentication to the Swagger UI: place the `/api/swagger` scope behind `pipe_through [:browser, :require_authenticated_user, :require_viewer]`. [Horizon: now] [Risk reduction: Med]
- **R3** — Remove `'unsafe-inline'` from `script-src` in the CSP and migrate any inline scripts to external JS files. If FullStory requires it, use a nonce-based approach. Also remove `'unsafe-inline'` from `connect-src` (it is unrecognized by browsers and likely unintentional). [Horizon: next] [Risk reduction: Med]
- **R4** — Wrap `String.to_existing_atom(params["order_by"])` in a `rescue ArgumentError` clause in `view_alerts_live.ex:97` and fall back to the default sort field. [Horizon: next] [Risk reduction: Lo]
- **R5** — Pin GitHub Actions `uses:` references to specific commit SHAs in `elixir.yml` (use Dependabot's `update-config` to auto-update pinned SHAs). [Horizon: later] [Risk reduction: Lo]
- **R6** — Run a real SCA tool (e.g. `mix deps.audit` via the `mix_audit` package, or Trivy) on `mix.lock` as part of CI to detect known CVEs in Elixir dependencies. [Horizon: next] [Risk reduction: Med]

## Confidence

- **Secrets scan** was performed with grep patterns against all committed `.ex`, `.exs`, `.yml`, `.json`, and config files. Git history was not scanned. High confidence for committed files; no assertion about history before the scan window.
- **Atom exhaustion finding (F1)** is a well-documented BEAM pattern — CWE-400. Exploitability depends on the API being accessible from untrusted callers (it requires Keycloak JWT, limiting the attack surface). Medium-high confidence.
- **CVE spot-check** is LLM-driven based on training knowledge of package histories. No `mix deps.audit` or Trivy was run — treat as directional only.
- **All security findings are hypothesis-grade** per skill design. No exploitation was attempted or confirmed.
