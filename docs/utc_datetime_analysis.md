# UTC vs Local DateTime Analysis — Mono Alert Feature

## Background

The app's architectural contract for datetimes:

- **Database**: all alert times stored as UTC (`:utc_datetime` Ecto type)
- **User-facing layer**: all form/display times are Eastern (`America/New_York`)
- **On save**: `AlertBuilder` converts NaiveDateTime form values (assumed Eastern) to UTC via `ActivePeriodBuilder.naive_eastern_datetime_to_utc/1`
- **On load**: UTC times are converted back to Eastern naive via `shift_to_naive/1` in `form_components/helpers/alert_data.ex:414–417`

The findings below identify places in the mono feature where this contract is broken or where UTC bleeds into the local-time layer.

---

## Issues

### 1. UTC date used for schedule API lookup

**File:** `lib/alerts_ui_web/live/create_alert_mono_live/slices/affected_service_slice.ex:199`

```elixir
"default" ->
  DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d")
```

When the trip schedule modal opens with `modal_date: "default"`, this UTC date string is passed to `CreateAlertLive.get_schedules_by_date/3`. Between midnight Eastern and midnight UTC (midnight–5am Eastern), this returns the wrong date — tomorrow's schedules instead of today's.

The two other date functions in the same file correctly use `DateTime.now!("America/New_York")` (lines 427, 437), making this inconsistency likely a bug.

---

### 2. UTC trip times silently stripped of timezone — **highest risk**

**File:** `lib/alerts_ui_web/live/create_alert_mono_live/slices/time_range_slice.ex:674–675`

```elixir
defp utc_datetime_to_naive(nil), do: nil
defp utc_datetime_to_naive(datetime), do: DateTime.to_naive(datetime)
```

This is called when populating the form from trip schedule data (departure/arrival times from the MBTA schedule API, which are UTC `DateTime` values):

- `get_trip_departure_time/1` (line 371) — sets `active_period_start`
- `get_trip_arrival_time/2` (line 380) — sets `active_period_end`
- `get_trip_arrival_time_for_validate/2` (line 401) — used during validation

`DateTime.to_naive/1` drops timezone info without converting. A UTC `DateTime` of `14:30:00Z` becomes a `NaiveDateTime` of `14:30:00`, which the rest of the pipeline treats as Eastern — meaning the stored active period will be off by 5 hours (or 4 during EDT).

The correct conversion already exists in the codebase:
```elixir
# form_components/helpers/alert_data.ex:414–417
def shift_to_naive(time) do
  time |> DateTime.shift_zone!("America/New_York") |> DateTime.to_naive()
end
```

---

### 3. `NaiveDateTime.local_now()` — depends on server timezone

**Files and lines:**
- `time_range_slice.ex`: lines 55, 200, 239, 247, 255, 293, 321, 343, 406
- `notification_period_slice.ex`: lines 43, 104, 138, 158, 194
- `time_range_validators.ex`: lines 146, 269

`NaiveDateTime.local_now/0` returns the server's wall-clock time with no timezone attached. All downstream code treats these values as Eastern (comparing against `~T[03:00:00]` start-of-service, validating times aren't in the past). This is correct only if the server runs in `America/New_York`.

This is a latent risk, not a current bug. The explicit equivalent — `DateTime.now!("America/New_York") |> DateTime.to_naive()` — is already used in `DateTimeHelpers.current_time/0` (`form_components/helpers/date_time_helpers.ex:11`).

---

## UTC Values That Are Correct (Not Bugs)

| Field | Location | Why UTC is correct |
|---|---|---|
| `created_timestamp`, `last_edited_at`, `last_push_notification_timestamp` | `alert_data.ex:149,151,153` | System metadata; displayed via `DateTime.shift_zone!(..., "America/New_York")` |
| `reminder_time` (DB) | `lib/alerts_ui/models/reminder_time.ex:21` | Stored UTC, converted on read |
| `active_period_start/end`, `notification_period_start/end` (DB) | `lib/alerts_ui/models/active_period.ex:20–21` | Canonical UTC storage |
| `now: DateTime.utc_now()` in review modal | `review_modal.ex:124` | Immediately shifted to Eastern before display (lines 352, 380) |

---

## Summary

| Priority | Location | Issue |
|---|---|---|
| High | `time_range_slice.ex:674–675` | `DateTime.to_naive` drops UTC offset from trip times; active period set 4–5 hours off |
| Medium | `affected_service_slice.ex:199` | UTC date used for schedule API query; wrong date midnight–5am Eastern |
| Low | `time_range_slice.ex`, `notification_period_slice.ex`, `time_range_validators.ex` | `NaiveDateTime.local_now()` assumes server timezone = Eastern; latent deployment risk |
