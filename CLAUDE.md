# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Dev server
mix phx.server
iex -S mix phx.server

# Tests (auto-migrates test DB)
mix test
mix test test/path/to/specific_test.exs
mix test test/path/to/specific_test.exs:42   # run single test at line

# Code quality (runs compile, format, credo, sobelow, dialyzer)
mix check

# Individual checks
mix format
mix credo --strict
mix dialyzer

# Database
mix ecto.setup          # create, migrate, seed
mix ecto.test_setup     # create and migrate test DB
mix ecto.reset          # drop and re-setup
```

Runtime is pinned via `.tool-versions` (Erlang 26, Elixir 1.16, Node 20). Use `asdf install` to get the right versions.

## Architecture

Phoenix LiveView app that creates and manages MBTA transit alerts. Alerts are published as GTFS-RT protobuf feeds exported by background Oban workers.

**Layers:**
- `lib/alerts_ui/` — business logic: Ecto contexts (`db_contexts/`), schemas (`models/`), feed output (`feed_output/`), Oban jobs (`jobs/`), and importers
- `lib/alerts_ui_web/` — Phoenix web layer: LiveView modules (`live/`), components (`components/`), traditional controllers (`controllers/`), router

**Two alert creation flows exist in parallel:**
- `create_alert_live.ex` — older multi-route alert flow
- `create_alert_mono_live/` — newer single-route ("mono") flow, organized as a directory with `alert_data.ex`, `slice.ex`, `slices/`, and `title.ex`

**Form components** (`live/form_components/`) are shared LiveView function components for alert form fields: `affected_service.ex`, `route_type_and_effect.ex`, `time_range.ex`, `delivery.ex`, `rider_reminders.ex`, `submit.ex`, etc.

**Router scopes** (`router.ex`) use three role-based plugs: `:viewer`, `:author`, and `:developer`. Authentication is OIDC via Keycloak (`lib/ueberauth/`).

**Feature flags** use two systems: client-side via Laboratory library (`/_flags`) and server-side (`/feature_flags`).

**Key models:** `Alert`, `InformedEntity`, `ActivePeriod`, `Cause`, `Effect`, `User`. PaperTrail provides audit history on alerts.

## Development URLs

- App: `localhost:4010`
- Oban dashboard: `/oban`
- LiveDashboard: `/dev/dashboard`
- DB viewer: `/db` (developer role)
- Feature flags: `/_flags` (client), `/feature_flags` (server)
- Swagger API docs: `/api/swagger`

## Testing Conventions

Tests use `ExUnit` with `Ecto.Adapters.SQL.Sandbox` for DB isolation. Factories are defined via `ex_machina` in `test/support/`. LiveView component tests use `live_isolated_component`. Property-based tests use `stream_data`.

CI runs in order: compile (warnings-as-errors) → format → credo → sobelow → tests → dialyzer.
