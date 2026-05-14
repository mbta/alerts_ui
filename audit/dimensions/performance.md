# Performance

_Generated: 2026-05-14T17:30:00-05:00_
_Repos covered: alerts_ui_

## Summary

The `alerts_ui` performance posture is adequate for its current scale — an internal transit-ops tool managing a few hundred concurrent alerts with a small number of simultaneous users. Three structural concerns stand out: the `informed_entities`, `active_period`, and `reminder_times` tables have no index on their `alert_id` foreign key columns, meaning Ecto's batch preloads in the every-30-second `FeedWriter` job run full table scans. The MBTA V3 API calls in the alert-creation flow are issued serially on cache miss, with individual calls per stop or facility ID (fan-out N+1). A redundant S3 write of the enhanced feed occurs on every `FeedWriter` invocation. No application-level caching of DB query results exists, though MBTA API results are well-cached at 1-hour TTL via ConCache.

**Overall grade:** B

## Framework anchors

- ISO/IEC 25010 §6.3 — Performance Efficiency (time-behaviour, resource utilization, capacity)
- ISO/IEC 5055 — Performance Efficiency rules
- Brendan Gregg, USE method — utilization / saturation / errors lens

## Findings

### F1 — No FK indexes on `informed_entities.alert_id`, `active_period.alert_id`, `reminder_times.alert_id`

- **Severity:** High
- **Location:** Migrations `20231012125036_add_informed_entity_table.exs`, `20241017133433_create_active_period_table.exs`, `20240926175251_create_reminder_time_table.exs`
- **Evidence:** All three tables add `alert_id` as a foreign key via `references(:alerts)` but no corresponding `create index(:<table>, [:alert_id])` appears in any migration. No subsequent migration adds these indexes.
- **Impact:** Every invocation of `list_all_open/0` (called by `FeedWriter` every 30 seconds, by `FeedChecker` every minute, and by `RecurringAlertUpdater`) preloads these associations using `WHERE alert_id IN (...)`. Without an index on `alert_id`, Postgres performs a sequential scan on each association table. As the alert table grows — particularly `informed_entities`, which stores one row per route/stop/activity combination — these scans become progressively more expensive. With the feed-write hot path running every 30 seconds, this is the most operationally impactful finding. (ISO/IEC 25010 §6.3 — time-behaviour)

### F2 — `write_feed/0` writes the enhanced feed twice per invocation

- **Severity:** Medium
- **Location:** `lib/alerts_ui/feed_output/write_feed.ex:29-31`
- **Evidence:**
  ```elixir
  with {:ok, enhanced_alerts_json} <- write(:enhanced, enhanced_alerts),
       {:ok, _} <- write(:standard, open_alerts),
       {:ok, _} <- write(:enhanced, enhanced_alerts),   # duplicate
  ```
  `write(:enhanced, enhanced_alerts)` appears at lines 29 and 31. The second call re-encodes all alerts to JSON and makes a second S3 `put_object` call. The result is discarded.
- **Impact:** Every `FeedWriter` run (every 30 seconds) encodes enhanced alerts and writes to S3 twice. Redundant JSON serialization of the full alert list plus a redundant S3 round-trip. Impact scales with alert count and S3 latency. No data corruption results, but the operation is entirely wasted. (ISO/IEC 25010 §6.3 — resource utilization)

### F3 — Serial MBTA API fan-out on stop and facility ID lookups

- **Severity:** Medium
- **Location:** `lib/alerts_ui_web/live/create_alert_live.ex:447-448`, `:452-453`; `lib/alerts_ui_web/live/form_components/alert_details.ex:126`
- **Evidence:**
  - `Enum.flat_map(stop_ids, &RoutesRepo.by_stop(&1, "filter[type]": 3))` — one API call per stop_id, serialized
  - `Enum.flat_map(stop_ids, &RoutesRepo.by_stop(&1))` — same pattern for all route types
  - `Enum.map(alert_data.facility_ids, &FacilitiesRepo.get(&1))` — one API call per facility ID
- **Impact:** On cold start or after a 1-hour cache expiry (ConCache TTL), selecting a multi-stop affected service area serializes N MBTA API HTTP requests sequentially. For a bus-stop-route flow selecting all stops on a corridor (dozens), this adds perceptible latency to the alert creation form. Routes, Stops, and Facilities repos all use `RepoCache` (ConCache) with a 1-hour TTL, so cache hits are fast; the concern is cache-miss fan-out. There is no batch endpoint used for multi-stop/multi-facility lookups. (ISO/IEC 25010 §6.3 — time-behaviour)

### F4 — `list_all_open/0` used in three separate call sites per feed write cycle without result sharing

- **Severity:** Medium
- **Location:** `lib/alerts_ui/feed_output/write_feed.ex:46`; `lib/alerts_ui/alert_validation/alert_validator.ex:32`; `lib/alerts_ui/jobs/recurring_alert_updater.ex:22`
- **Evidence:** `write_feed/0` calls `Alerts.list_all_open()` once directly. Separately, `FeedChecker` (which also runs every minute) calls `alert_validator.ex:32` → `Alerts.list_all_open()`. `RecurringAlertUpdater` calls `Alerts.list_all_open()` independently. Each is a separate full DB query with preloads of `user`, `reminder_times`, `active_period`, and `informed_entity`. There is no shared in-memory cache of the open alerts list between jobs.
- **Impact:** In a 1-minute window, the open alerts list is loaded from DB at least twice (FeedWriter at 30s intervals + FeedChecker at 60s). For the current alert volume this is likely fine, but as alerts grow or if the `informed_entities` scan cost increases (F1), duplicated full-preload queries increase cumulative DB load. (ISO/IEC 25010 §6.3 — resource utilization)

### F5 — `view_alerts_live.ex` polls DB every 10 seconds per connected session with `page_size: 1_000` for the "current" timeline

- **Severity:** Low
- **Location:** `lib/alerts_ui_web/live/view_alerts_live.ex:32, 66, 529-533`
- **Evidence:** Each connected `ViewAlertsLive` session calls `Process.send_after(self(), :update, 10_000)` and on each tick executes `Alerts.list_all_paginated(flop)`. When the "current" timeline filter is active, `page_size` is set to 1,000 (line 532) rather than the default 50. The Flop query includes a non-trivial `service_pill_sort_key` fragment computed in SQL.
- **Impact:** With multiple simultaneous sessions open, each fires a DB query every 10 seconds. Under normal operator load (a handful of users) this is low impact. If page_size 1,000 is hit for a production system with hundreds of alerts, the query payload and rendering cost rise. The 10-second server-push model also means the browser does not benefit from LiveView's native diff compression when the entire alert list changes. (ISO/IEC 25010 §6.3 — capacity)

### F6 — `Plug.Static` served with `gzip: false` in endpoint

- **Severity:** Low
- **Location:** `lib/alerts_ui_web/endpoint.ex:26`
- **Evidence:** `plug Plug.Static, ..., gzip: false`. The endpoint comment notes "You should set gzip to true if you are running phx.digest when deploying your static files in production." The Dockerfile runs `phx.digest` (which generates `.gz` variants of static files), but the endpoint will not serve them because `gzip: false`.
- **Impact:** JS and CSS assets are served uncompressed to all clients. Tailwind CSS and the compiled LiveView JS bundle can be several hundred KB; serving uncompressed reduces transfer performance, particularly for first-load on slow connections. This is a minor issue for an internal tool. (ISO/IEC 25010 §6.3 — resource utilization)

## Metrics

| Repo | Metric | Value | Notes |
|------|--------|-------|-------|
| alerts_ui | Suspected N+1 patterns (DB) | 0 confirmed | Ecto preloads are batched (IN clauses), not per-row |
| alerts_ui | Suspected N+1 patterns (API) | 2 confirmed | `by_stop` and `FacilitiesRepo.get` called per-ID in loop |
| alerts_ui | Missing FK indexes | 3 | `informed_entities.alert_id`, `active_period.alert_id`, `reminder_times.alert_id` |
| alerts_ui | Missing hot-query indexes | 1 suspected | `alerts.closed_timestamp` (used in `WHERE closed_timestamp IS NULL` and range filter) — no index found in migrations |
| alerts_ui | Endpoints without pagination | 0 user-facing | `ViewAlertsLive` uses Flop pagination; API uses Flop. `list_all_open/0` is used only in background jobs/feed output, not user-facing list endpoints |
| alerts_ui | MBTA API caching | Present — 1-hour TTL | ConCache via `RepoCache`; Routes, Stops, Schedules, Facilities repos all use it |
| alerts_ui | App-level DB query caching | None | No ETS, Cachex, or in-process cache of DB results |
| alerts_ui | Redundant S3 writes per feed cycle | 1 | `write(:enhanced, ...)` called twice in `write_feed/0` |
| alerts_ui | Frontend bundle approach | Phoenix + esbuild (minimal) | 6 hand-authored JS files; no webpack or bundle splitting needed at this scale |
| alerts_ui | Static asset compression | gzip disabled | `Plug.Static gzip: false`; phx.digest does generate .gz files |
| alerts_ui | CDN / HTTP cache layer | None confirmed | No CloudFront, Nginx, or equivalent in-scope; deployment is direct ECS |

## Recommendations

- **R1** — Add `alert_id` indexes to `informed_entities`, `active_period`, and `reminder_times` tables. A single migration adding three `create index(:<table>, [:alert_id])` calls will be fast on the current dataset and directly reduces the cost of the every-30-second `FeedWriter` preload query. [Horizon: now] [Risk reduction: Hi]
- **R2** — Remove the duplicate `write(:enhanced, enhanced_alerts)` call at `write_feed.ex:31`. One call at the top of the `with` chain is sufficient; the second is a no-op that wastes CPU and an S3 round-trip every 30 seconds. [Horizon: now] [Risk reduction: Med]
- **R3** — Add an index on `alerts.closed_timestamp` to support the `WHERE closed_timestamp IS NULL` (open alerts) and `WHERE closed_timestamp > from_now(-5, "minute")` (recently-closed) queries used in feed writes. [Horizon: next] [Risk reduction: Med]
- **R4** — Replace the per-ID API fan-out in `get_routes_by_stop` and `alert_details.ex` with batch API requests: MBTA V3 supports `filter[id]=id1,id2,...` for stops and facilities. On cache miss, a single API call with all IDs reduces latency N-fold. [Horizon: next] [Risk reduction: Med]
- **R5** — Set `gzip: true` in `Plug.Static` in the production endpoint (or conditionally via config) to serve pre-compressed `.gz` assets generated by `phx.digest`. [Horizon: next] [Risk reduction: Lo]

## Confidence

- **Missing FK index finding (F1)** is confirmed by exhaustive grep across all 29 migration files — no `create index` on the three tables' `alert_id` columns exists. High confidence.
- **Duplicate S3 write (F2)** is confirmed by reading `write_feed.ex` — the `with` block clearly calls `write(:enhanced, ...)` twice. High confidence this is unintentional.
- **API fan-out (F3)** is confirmed by reading the `create_alert_live.ex` and `alert_details.ex` code. Whether this is perceptible to users depends on cache hit rate; cache hit rate was not measurable from code. Medium-high confidence on the pattern, medium confidence on impact.
- **`list_all_open` duplicate cost (F4)** is directional — exact query cost depends on current alert volume and index coverage. High confidence on the pattern, medium confidence on materialized impact at current scale.
- **No benchmarks or profiling data** were available. All findings are code-pattern-based and should be confirmed with `EXPLAIN ANALYZE` (DB findings) and `telemetry` metrics (API latency) before prioritizing rework.
