# Reliability

_Generated: 2026-05-14T16:25:00-05:00_
_Repos covered: alerts_ui_

## Summary

The `alerts_ui` reliability posture is solid at its core: Oban provides durable job queuing with persistent state; Sentry captures exceptions at the Phoenix endpoint and plug level; slow-query telemetry is instrumented; and the health endpoint performs a real DB check. The most significant finding is a silent-failure pattern in `DelayedJob` — the rescue clause logs a warning and returns `nil`, causing Oban to record the job as successful even when the underlying work failed. Six DB operations in `IBIAlertImporter` use `timeout: :infinity`, risking unbounded connection-pool exhaustion during bulk imports. No distributed tracing is present, and the telemetry metrics reporter is commented out, meaning Phoenix/Ecto metrics are collected but not exported anywhere.

**Overall grade:** B

## Framework anchors

- ISO/IEC 25010 §6.2 — Reliability (maturity, availability, fault tolerance, recoverability)
- ISO/IEC 5055 — Reliability rules
- Google SRE Book — observability practices

## Findings

### F1 — `DelayedJob.perform/2` swallows errors, reporting success to Oban

- **Severity:** High
- **Location:** `lib/alerts_ui/jobs/delayed_job.ex:43-44`
- **Evidence:**
  ```elixir
  rescue
    e -> Logger.warning("Error delaying job. args=#{inspect(args)}: #{inspect(e)}")
  ```
  `Logger.warning/1` returns `:ok`. In Oban, `perform/1` returning `nil` or `:ok` is treated as job success. When the underlying `module.perform(job, opts)` raises, `DelayedJob` logs a warning and exits normally — Oban marks the job `completed`, no retry is triggered, and no Sentry capture occurs.
- **Impact:** Any error in a job dispatched via `DelayedJob` is silently swallowed. Since `DelayedJob` is used to offset `FeedWriter` runs by 30 seconds (and runs every minute), a persistent error in `FeedWriter` would log warnings but never surface as an Oban failure, preventing alerting. (ISO/IEC 25010 §6.2 — fault tolerance)

### F2 — `IBIAlertImporter` holds DB connections with `timeout: :infinity` (6 occurrences)

- **Severity:** High**
- **Location:** `lib/alerts_ui/ibi_alert_importer.ex:42, 55, 98, 210, 251, 407`
- **Evidence:** Six `Repo.transact(fn -> ..., timeout: :infinity)` and bulk DB operations (`delete_all`, `insert_all`) with no upper bound on execution time. The largest transaction processes thousands of IBI alerts in a loop with N+1 potential.
- **Impact:** A slow or hung bulk import holds DB connections for an unbounded duration. With a pool of 20 connections (default in `runtime.exs`), a long-running import can starve all other DB operations, causing cascading timeouts across the application. This is particularly relevant during the developer-triggered "re-import all IBI alerts" path in `IBIImporterLive`. (ISO/IEC 25010 §6.2 — availability)

### F3 — `FeedReader` uses `Req.get!/1` (bang form) with no timeout

- **Severity:** Medium
- **Location:** `lib/alerts_ui/feed_reader.ex:23`
- **Evidence:** `get_http_fn = AlertsUI.config(:get_http_fn, &Req.get!/1)` — the bang form raises on non-2xx or network error. No timeout option is passed to `Req`. Req's default `receive_timeout` is configurable globally; if not set, defaults to Finch's transport timeout.
- **Impact:** If the S3 bucket or IBI API is slow or unresponsive, `FeedReader` calls will block for an unspecified time. Because `FeedChecker` does a pattern-match on `{:ok, file} = FeedReader.alerts_json(flavor)`, any non-2xx response raises `MatchError`, which Oban will catch and mark as failure — but the call may first block for an extended period. (ISO/IEC 25010 §6.2 — fault tolerance)

### F4 — Metrics reporter disabled; telemetry metrics are collected but not exported

- **Severity:** Medium
- **Location:** `lib/alerts_ui_web/telemetry.ex:21` (commented out: `# {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}`)
- **Evidence:** `AlertsUIWeb.Telemetry` defines a comprehensive set of summary metrics for Phoenix endpoints, LiveView, DB queries, and VM memory/CPU — but no reporter is configured. The `ConsoleReporter` is commented out, and no Prometheus exporter, StatsD adapter, or other reporter is present.
- **Impact:** All collected telemetry metrics are silently discarded. There is no operational visibility into request latency, LiveView socket counts, or database query time trends beyond what Sentry captures as exceptions. Engineers cannot detect degradation before it becomes an error. (Google SRE — observability)

### F5 — All minute-level Oban cron jobs configured with `max_attempts: 1`

- **Severity:** Low
- **Location:** `config/config.exs:113, 121, 124, 126, 135`
- **Evidence:** `FeedWriter`, `DelayedJob` (FeedWriter offset), `FeedChecker`, `Trapeze.Importer`, and `AlertValidationUpcomingWorker` all set `max_attempts: 1`. Failures are not retried — the next scheduled run picks up.
- **Impact:** A transient failure (network blip, brief S3 unavailability) causes a missed run with no retry. Because these jobs run every minute, a single missed run is low-impact. However, if a failure window exceeds one minute, multiple consecutive runs fail with no escalation signal. `max_attempts: 1` combined with `DelayedJob`'s silent-failure pattern (F1) means errors may not surface at all.

### F6 — No distributed tracing

- **Severity:** Low
- **Location:** Entire codebase
- **Evidence:** No OpenTelemetry, Datadog, or Jaeger imports found. Sentry captures exceptions but not traces. Telemetry events are defined but not correlated across requests.
- **Impact:** When a slow alert-creation form submission triggers a cascade of MBTA API calls (routes, stops, schedules, route patterns), there is no trace to follow. Debugging intermittent latency requires correlating logs by timestamp, which is error-prone. (Google SRE — distributed observability)

## Metrics

| Repo | Metric | Value | Notes |
|------|--------|-------|-------|
| alerts_ui | Silent-catch / swallowing rescue blocks | 1 confirmed | `delayed_job.ex` — others log+reraise or return `{:error, ...}` |
| alerts_ui | `timeout: :infinity` DB calls | 6 | All in `ibi_alert_importer.ex` |
| alerts_ui | HTTP calls without explicit timeout | 2 | `feed_reader.ex` (Req.get!), `alert_validation_upcoming_worker.ex` (Req.get) |
| alerts_ui | Logging maturity | Structured (partial) | Logger with metadata (`request_id`); structured format configured; no log correlation IDs beyond request_id |
| alerts_ui | Metrics maturity | Counters defined, no export | Telemetry.Metrics defined; no reporter; no Prometheus/StatsD |
| alerts_ui | Tracing presence | None | No OpenTelemetry or equivalent |
| alerts_ui | Health endpoint | Liveness only | `/_health` does `SELECT 1`; no readiness or dependency-health checks |
| alerts_ui | Sentry integration | Present | `Sentry.PlugCapture` + `Sentry.PlugContext` at endpoint; DSN from env; enabled in deployed envs |
| alerts_ui | Oban job retry behaviour | `max_attempts: 1` on all critical periodic jobs | |
| alerts_ui | Recurring defect themes | N/A | No source_artifacts with incident history |

## Recommendations

- **R1** — Fix `DelayedJob` to reraise errors instead of returning `:ok`. Change `rescue e -> Logger.warning(...)` to `rescue e -> Logger.warning(...); reraise e, __STACKTRACE__` so Oban marks the job as failed and Sentry captures the event. [Horizon: now] [Risk reduction: Hi]
- **R2** — Add explicit timeouts to the six `ibi_alert_importer.ex` DB transactions: set a reasonable upper bound (e.g. 5 minutes per transaction) and log + surface timeout as a job error rather than silently hanging. Separately, evaluate whether the bulk import should run in a dedicated DB pool to avoid starving application traffic. [Horizon: next] [Risk reduction: Hi]
- **R3** — Add `receive_timeout:` and `connect_timeout:` options to all `Req` calls in `feed_reader.ex` and `alert_validation_upcoming_worker.ex`. Configure a module-level default of ~10 seconds. [Horizon: next] [Risk reduction: Med]
- **R4** — Configure a telemetry reporter: add `telemetry_metrics_prometheus` (if Prometheus/Grafana is available) or `{Telemetry.Metrics.ConsoleReporter, metrics: metrics()}` as a minimum so metrics are not silently discarded. [Horizon: next] [Risk reduction: Med]
- **R5** — Add a readiness check to `/_health` that verifies Oban queue depth is not stalled — e.g. confirm no jobs are stuck in `executing` for more than 2× their expected run time. [Horizon: later] [Risk reduction: Lo]

## Confidence

- **Silent-failure finding (F1)** is directly observed from code. High confidence — `Logger.warning/1` returns `:ok`, and Oban treats `:ok` as job success.
- **Timeout findings** are observed from source code. Actual impact depends on traffic patterns and DB pool saturation; assessed as High based on the pattern, but no production incident data was available to confirm.
- **Metrics / tracing absence** is confirmed by exhaustive grep. High confidence.
- **No source_artifacts with incident history** were available. Reliability assessment is code-only; real recurring failure modes that don't leave code traces may exist.
