# Inventory

_Generated: 2026-05-14T14:54:00-05:00_

## Engagement

- **Client:** mbta
- **Project:** alerts-ui
- **Audit date:** 2026-05-14
- **Slug:** mbta-alerts-ui-2026-05-14

> **Headless-mode fallback:** Client and project names were derived from the working directory path (`/Users/jyurek/Development/clients/mbta/alerts_ui`). Override here if needed.

## Working directory

`/Users/jyurek/Development/clients/mbta/alerts_ui`

Layout: **Single-repo**

## Repos

### `alerts_ui`

- **Description:** A Phoenix LiveView application for creating and managing MBTA transit alerts. Alerts are published as GTFS-RT protobuf feeds exported to S3 via background Oban workers.
- **Primary language:** Elixir (351 source files, ~62,500 LOC)
- **Other languages:** HEEx templates (13 files, ~1,000 LOC); JavaScript (6 hand-authored files in `assets/`, ~668 LOC); SQL migrations (29 files in `priv/repo/migrations/`)
- **LOC (approx):** ~64,200 (Elixir + templates + JS; excludes `deps/`, `_build/`, `node_modules/`, `cover/`)
- **Manifests:**
  - `mix.exs` / `mix.lock` — Elixir/OTP project manifest
  - `assets/package.json` / `assets/package-lock.json` — Node assets
  - `.tool-versions` — runtime pins (Erlang 26.2.1, Elixir 1.16.0-otp-26, Node 20.10.0)
  - `Dockerfile` — multi-stage Docker build
- **Key frameworks:**
  - Phoenix 1.8.6 + Phoenix LiveView 1.0.1
  - Ecto 3.13.2 + PostgreSQL (postgrex)
  - Oban 2.16 (background jobs) + Oban Web 2.11 (dashboard)
  - Tailwind CSS + DaisyUI 4.4 (asset pipeline via `tailwind` hex package)
  - ueberauth + ueberauth_oidcc (OIDC authentication via Keycloak)
  - exprotobuf (GTFS-RT protobuf generation)
  - ex_aws + ex_aws_s3 (feed publishing to S3)
  - PaperTrail 1.1.2 (audit history on alerts)
  - Sentry 12.0 (error tracking)
  - Phoenix Swagger 0.8 (API docs)
  - Laboratory (client-side feature flags, GitHub fork)
  - Sobelow (security static analysis), Credo, Dialyzer
- **Total source files (non-vendor):** ~20,000 (includes `priv/`, `test/`, config; excludes `deps/`, `_build/`, `cover/`, `node_modules/`)
- **Default branch:** `main`
- **Recent activity:** Last commit 2026-05-14; first commit 2023-09-26; 1,194 total commits — **actively maintained**
- **Notes:**
  - Multi-stage Docker build: Elixir build → Node assets build → OTP release runtime (non-root `alertsui` user)
  - Deployed to 4 environments: dev-green, dev-orange, staging, prod (see README)
  - Two parallel alert creation flows: `create_alert_live.ex` (legacy multi-route) and `create_alert_mono_live/` (current single-route, `Slice` protocol)
  - Feature flags: client-side (Laboratory, `/_flags`) and server-side (`/feature_flags`)
  - Role-based auth: viewer / author / developer

## Source artifacts

| Path | Classification | Summary |
|------|----------------|---------|
| `README.md` | Runbook / onboarding | Setup instructions, dev server commands, environment descriptions, debug routes |
| `CLAUDE.md` | Developer guide | AI assistant context: commands, architecture layers, testing conventions |
| `CONTRIBUTORS.md` | Other | List of project contributors |
| `CODE_OF_CONDUCT.md` | Other | Community conduct standards |
| `Dockerfile` | Runbook | Multi-stage Docker build definition; Elixir + Node build pipeline, OTP release runtime |
| `.envrc.example` | Runbook | Required environment variables template; documents S3, MBTA API, DB, Trapeze SFTP config |

## Confidence

- **LOC counts** are `find` + `wc -l` based (v1 approach), not `cloc`/`tokei`. The 485 JS/TS files found in a first pass included files under `deps/` and `_build/`; corrected count is 6 hand-authored JS/TS files in `assets/`.
- **Framework detection** is based on manifest inspection and directory structure; confidence is high for all listed frameworks (all appear explicitly in `mix.exs` dependencies or characteristic config files).
- **LOC for HEEx** excludes the `cover/` directory, which contains ~190k lines of generated HTML coverage reports — these are not source files.
- **Git history** is available; all DORA-proxy metrics can be derived by the `delivery` dimension skill.
