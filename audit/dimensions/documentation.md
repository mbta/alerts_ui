# Documentation & Onboarding

_Generated: 2026-05-14T18:15:00-05:00_
_Repos covered: alerts_ui_

## Summary

`alerts_ui` has a functional README that gets a developer running locally in under 30 minutes, and a `CLAUDE.md` that provides AI-assistant-level architecture context. The critical documentation gap is the `create_alert_mono_live/` flow: all 9 slice implementation files have no `@moduledoc`, the `AlertData` moduledoc contains only "Alert data v2", and the `combination` field semantics (which controls which slices activate) are entirely undocumented. A working document called `agentic-dev-improvements.md` in the repo root confirms that the team already knows these gaps exist — the 20-item improvement list there is insightful and actionable. No ADRs, no operational runbooks, no on-call procedures, and no license file are present.

**Overall grade:** C+

## Framework anchors

- ISO/IEC 25010 §6.4.1 — Appropriateness Recognisability
- ISO/IEC 25010 §6.4.2 — Learnability
- Diátaxis framework — tutorials / how-to / reference / explanation taxonomy

## Findings

### F1 — All 9 slice implementation files have no `@moduledoc`; `AlertData` moduledoc is minimal

- **Severity:** High
- **Location:** `lib/alerts_ui_web/live/create_alert_mono_live/slices/` (9 of 10 files); `alert_data.ex:3` ("Alert data v2")
- **Evidence:** Running a check on the 10 slice files, only `timeline_slice.ex` has a `@moduledoc` — and that doc reads "Describe a step in the multi-step form and where it can go." (one incomplete sentence). The other 9 slice files (`affected_service_slice.ex`, `alert_details_slice.ex`, `delivery_slice.ex`, `reminder_times_slice.ex`, `stop_route_service_slice.ex`, `submit_slice.ex`, `systemwide_service_slice.ex`, `access_affected_service_slice.ex`, `url_slice.ex`) have none. `AlertData`'s moduledoc is "Alert data v2" — no description of the `combination` field semantics, no list of managed fields, no description of the mount/extract/transform/validate/assigns lifecycle.
- **Impact:** A new contributor reading the codebase cannot determine from module headers what business purpose each slice serves, which `AlertData` fields it owns, or what validation rules it enforces. This is the newest, most actively developed flow in the application, and its most opaque. (ISO/IEC 25010 §6.4.2 — Learnability)

### F2 — The `combination` field semantics are entirely undocumented

- **Severity:** High**
- **Location:** `lib/alerts_ui_web/live/create_alert_mono_live/alert_data.ex:37-38`
- **Evidence:**
  ```elixir
  @combination_values [:ACCESS, :R, :RDS, :RDT, :RDTS, :SR]
  @type combination :: :ACCESS | :R | :RDS | :RDT | :RDTS | :SR
  ```
  The six values (`:ACCESS`, `:R`, `:RDS`, `:RDT`, `:RDTS`, `:SR`) control which slices activate for a given alert creation flow. There is no comment, no docstring, no external file explaining what these acronyms mean, which service scenarios they correspond to, or which slices each activates.
- **Impact:** A developer adding a new combination type or debugging a slice rendering issue must reverse-engineer the meaning of `:RDTS` vs `:RDS` from the `ServiceSliceDispatcher` logic and form rendering code. The team's own `agentic-dev-improvements.md` identifies this as a top-3 priority ("Document the `combination` field as a decision matrix"). (Diátaxis — missing reference documentation)

### F3 — README missing license, CI badges, and contribution guidelines

- **Severity:** Medium
- **Location:** `README.md`
- **Evidence:** The README has a clear purpose statement, working quickstart, and environment descriptions — but has no:
  - License file or license mention (no `LICENSE` file in root)
  - CI status badge or coverage badge
  - Contribution guidelines (CONTRIBUTORS.md lists names but not how to contribute)
  - Architecture section (CLAUDE.md has this, but README does not link to it)
  - PR or code review conventions
- **Impact:** For a project with external contributors or MBTA staff onboarding, the absence of a license is a potential compliance issue. Missing CI badges mean the README doesn't serve as a health dashboard. These are conventional README elements that contributors expect. (ISO/IEC 25010 §6.4.1 — Appropriateness Recognisability)

### F4 — `.envrc.example` missing `KEYCLOAK_*` variables and `SENTRY_DSN`; `SECRET_KEY_BASE` is empty with no instructions

- **Severity:** Medium
- **Location:** `.envrc.example`
- **Evidence:** `runtime.exs` conditionally requires `KEYCLOAK_CLIENT_ID` and `KEYCLOAK_CLIENT_SECRET` (when `KEYCLOAK_ISSUER` is set) and unconditionally requires `SENTRY_DSN` in production. The `.envrc.example` includes `SECRET_KEY_BASE=` (empty) with no instructions on how to generate a value. The Keycloak variables are entirely absent — a developer setting up Keycloak for local OIDC testing has no template to follow.
- **Evidence:**
  ```bash
  export SECRET_KEY_BASE=    # present but empty; no hint to run mix phx.gen.secret
  # KEYCLOAK_CLIENT_ID, KEYCLOAK_CLIENT_SECRET, KEYCLOAK_ISSUER — absent
  # SENTRY_DSN — absent
  ```
- **Impact:** New developers cannot configure OIDC auth locally without tribal knowledge. `runtime.exs` has a comment for `SECRET_KEY_BASE` that says "You can generate one by calling: mix phx.gen.secret" — but this comment is in the config file, not in `.envrc.example` where a developer is more likely to look. (ISO/IEC 25010 §6.4.2 — Learnability)

### F5 — No operational runbook; rollback procedure is one sentence; no on-call or incident response docs

- **Severity:** Medium
- **Location:** `README.md:94-95`
- **Evidence:** The only operational documentation is: "If you need to roll back you can create a release for a previous tag." There is no on-call runbook describing which alerts from Sentry or Oban warrant immediate action, no procedure for the GTFS feed being stale or S3 write failures, no incident postmortem templates, and no procedure for the IBI importer getting stuck.
- **Impact:** On-call engineers must rely on institutional memory when incidents occur. The system has known risk points (Oban silent failures, connection pool starvation from IBI bulk imports, S3 write failures) that are not documented in operational context — meaning the response procedure is entirely implicit. (ISO/IEC 25010 §6.4 — Learnability; reliability sibling gap)

### F6 — `agentic-dev-improvements.md` is a planning artifact in the repo root, not a doc artifact

- **Severity:** Low
- **Location:** `agentic-dev-improvements.md`
- **Evidence:** This file contains 20 well-organized recommendations for documentation and testing improvements, synthesized from five AI agent perspectives. It is an insightful planning document, but it lives in the repo root alongside `README.md` — not in a `docs/` folder or issue tracker.
- **Impact:** The file is useful raw material for the documentation roadmap. Its presence confirms the team is aware of the documentation gaps identified in this report. However, leaving a planning document in the project root alongside end-user-facing docs creates confusion about its status and audience. It should be converted to tracked issues (Asana) and then removed from the repo, or moved to `docs/` as an acknowledged debt log. (Diátaxis — explanation doc in wrong location)

## README Completeness Checklist

| Item | Present? | Notes |
|------|----------|-------|
| Purpose statement | ✓ | First line: "A UI for creating and modifying alerts" |
| Quickstart (local setup) | ✓ | Full step-by-step with `asdf`, `mix ecto.setup`, etc. |
| Running tests | ✓ | `mix test` |
| Dev server instructions | ✓ | `mix phx.server` + URL |
| Environment descriptions | ✓ | All 4 environments documented |
| Debug routes | ✓ | Good section listing debug endpoints |
| Architecture overview | ✗ | Not in README (in CLAUDE.md only) |
| Contribution guidelines | ✗ | No PR conventions, code style, or commit guidance |
| License | ✗ | No LICENSE file, no mention in README |
| CI status badge | ✗ | Absent |
| Coverage badge | ✗ | Absent |
| Link to CLAUDE.md | ✗ | CLAUDE.md exists but README doesn't reference it |

## Onboarding Friction Points

Following the README as a new developer:

1. **`asdf` prerequisites unclear** — README tells you to add `asdf` plugins but does not mention that Erlang build requires `wxWidgets` and other OS-level dependencies on macOS/Linux. A fresh machine will fail with a cryptic `kerl` error.
2. **`npm --prefix assets i` numbered step 3, not step 1** — the step numbering resets (`1. asdf install`, `2. mix deps.get`, `1. npm...`) — looks like a copy error.
3. **`SECRET_KEY_BASE` is empty in `.envrc`** — `runtime.exs` requires it in deployed mode, but `mix phx.server` in dev mode uses `config/dev.exs`. A developer who sets `SECRET_KEY_BASE=` and then tries to run in `PHX_SERVER=true` mode will get an opaque crash.
4. **No mention of what to do after `mix ecto.setup`** — no seed data, no test users. The OIDC flow requires Keycloak credentials to log in. A fresh install will show the login page with no obvious way to proceed unless the developer knows to configure `.envrc` with Keycloak creds or knows about the bypass.
5. **`TRAPEZE_SFTP_*` variables present in `.envrc.example` with a warning** — "if these are wrong 3 times, you'll get locked out" is excellent contextual guidance, but gives no indication of whether this integration is needed for local development (it is optional).
6. **`KEYCLOAK_ISSUER` / `KEYCLOAK_CLIENT_*` are required for OIDC but absent from template** — a developer cannot authenticate locally without these unless they know to ask.

## API Documentation

- **Swagger UI**: Present at `/api/swagger` (PhoenixSwagger 0.8). Accessible but unauthenticated (security F2).
- **Generated Elixir docs**: Not confirmed in CI pipeline; no `mix docs` or `ex_doc` artifact upload step.
- **In-code docs**: 156 modules have `@moduledoc` (partial coverage); 15 typespec annotations in `alert_builder.ex` (well-spec'd); slice implementations have 0–1 specs each.

## Metrics

| Repo | Metric | Value | Notes |
|------|--------|-------|-------|
| alerts_ui | README completeness | 7/12 items | See checklist above |
| alerts_ui | API doc presence | Partial | Swagger for API endpoints; no generated hex docs |
| alerts_ui | ADR count | 0 | No ADR directory or files |
| alerts_ui | Runbook coverage | Deploy-only (1 sentence) | No on-call, no incident response |
| alerts_ui | Estimated time-to-first-run | ~45 min | With friction points; 30 min if experienced with asdf |
| alerts_ui | Modules with `@moduledoc` | ~156 / ~235 | ~66%; slices and hot-path web modules notably absent |
| alerts_ui | Docs freshness | README appears current | Last deployment environment section matches actual CI config |
| alerts_ui | Acknowledged doc debt | 20 items | In `agentic-dev-improvements.md` |

## Recommendations

- **R1** — Write a `docs/SLICES.md` explaining the `Slice` protocol callback semantics, the `combination` decision matrix (which combination activates which slices), and a walkthrough of implementing a new slice. This is the single highest-leverage documentation investment for the codebase's primary abstraction. [Horizon: now] [Risk reduction: Hi]
- **R2** — Add a `@moduledoc` to each of the 9 undocumented slice files (2-3 sentences each: business purpose, which `AlertData` fields it manages, which validation rules it enforces). [Horizon: now] [Risk reduction: Hi]
- **R3** — Add `KEYCLOAK_CLIENT_ID`, `KEYCLOAK_CLIENT_SECRET`, `KEYCLOAK_ISSUER`, and `SENTRY_DSN` (with a note that SENTRY_DSN is only needed in deployed environments) to `.envrc.example`. Add a comment to `SECRET_KEY_BASE=` saying "run `mix phx.gen.secret` to generate". [Horizon: now] [Risk reduction: Med]
- **R4** — Convert `agentic-dev-improvements.md` to Asana tickets (or GitHub issues) and remove it from the repo root. The 20 items are a solid improvement roadmap; tracking them in an issue tracker makes them actionable. [Horizon: next] [Risk reduction: Lo]
- **R5** — Add a LICENSE file (MIT or Apache 2.0, matching MBTA's standard practice) and a brief Architecture section to the README linking to CLAUDE.md. [Horizon: next] [Risk reduction: Lo]
- **R6** — Write a one-page operational runbook in `docs/runbook.md` covering: what to do if Sentry fires a `DelayedJob` error, how to restart a stalled Oban queue, and the IBI importer bulk re-import procedure. [Horizon: later] [Risk reduction: Med]

## Confidence

- **README completeness** is directly observed by reading the file. High confidence.
- **`.envrc.example` gaps** are confirmed by comparing the template against `runtime.exs` `fetch_env!` calls. High confidence.
- **Slice `@moduledoc` absence** is confirmed by checking all 10 slice files. High confidence.
- **Onboarding friction points** are inferred from reading docs and config — not validated by an actual fresh install. Treat as directional.
- **ADR absence** confirmed by filesystem search. High confidence.
- **`agentic-dev-improvements.md`** is read directly; its existence and content are confirmed.
