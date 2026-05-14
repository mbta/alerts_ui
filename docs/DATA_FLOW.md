# Alert Data Flow: End-to-End

This document traces the life of an alert from the moment a user fills out the form to the moment it appears in a published GTFS-RT feed on S3.

---

## Overview

```
Browser Form
    │  LiveView events ("validate", "save")
    ▼
CreateAlertMonoLive (LiveView)
    │  AlertData.init / AlertData.sync
    ▼
AlertData + Slices (Ecto embedded schema + protocol)
    │  AlertData.sync → cast → transform → validate → assigns
    ▼
AlertBuilder.build_alert/3 (on submit)
    │  Transforms form data → DB-ready map
    ▼
Alerts.create_or_update_alert/3 (Ecto + PaperTrail)
    │  Alert changeset → PostgreSQL
    ▼
── alert is now in the database ──
    │  (Oban cron, every minute)
    ▼
FeedWriter.write_feed/1
    │  Queries open alerts → transforms → writes 7 feed flavors
    ▼
CreateOutputAlert.build_alert/1   ←→   CreateStandardAlert.build_standard_alert/1
    │  GTFS-RT JSON map                      │  GTFS-spec-only field filter
    ▼
CreateGtfsJson / CreateGtfsProtobuf
    │  JSON binary or Protobuf binary
    ▼
WriteToS3.write/2  (or WriteLocal in dev)
    │  PUT to S3 bucket
    ▼
Published GTFS-RT feeds (7 variants)
```

---

## Phase 1: Form Initialization

**Entry:** `CreateAlertMonoLive.mount/3` → `start_socket/2` → `AlertData.init/4`

The LiveView mounts and initializes the form state. If creating a new alert, `alert` is `%Alert{}`. If editing or duplicating, the existing alert is fetched and preloaded:

```elixir
Repo.preload(alert, :informed_entity)
```

`AlertData.init/4` iterates over the active slices for this socket and runs two callbacks per slice:

1. `Slice.extract(slice, alert, params)` — populates the slice struct from the existing alert
2. `Slice.mount(slice, socket, params)` — allows the slice to set up async data loading or socket assigns

All slice structs are merged into a single map, used to construct the `AlertData` struct (which is an Ecto embedded schema). The pipeline then calls `AlertData.sync/4` with `init_param_fields/0` (only `:alert_id`, `:effect_name`, `:route_type`) to produce the initial changeset.

---

## Phase 2: Slice Dispatch — Which Slices Are Active?

**Key function:** `AlertData.slices/1`

The active slice list is fixed except for the service slice, which is dispatched based on the current `combination` value:

```
TimelineSlice
UrlSlice
ServiceSliceDispatcher.affected_service_component(combination)  ← varies
AlertDetailsSlice
ReminderTimesSlice
DeliverySlice
SubmitSlice
```

**Combination → Service Slice mapping:**

| Combination | Service Slice | Who uses it |
|---|---|---|
| `nil` (systemwide) | `SystemwideServiceSlice` | No route/stop/trip; service types only |
| `:R` | `AffectedServiceSlice` | Route-only; one entity per route |
| `:RDS` | `AffectedServiceSlice` | Route + direction + stops |
| `:RDT` | `AffectedServiceSlice` | Route + direction + trips |
| `:RDTS` | `AffectedServiceSlice` | Route + direction + trips + stops |
| `:SR` | `StopRouteServiceSlice` | Single route + stops; validates stops are on route |
| `:ACCESS` | `AccessAffectedServiceSlice` | Facilities; expands to stops + routes |

The `combination` is derived from (`route_type_int`, `effect_name`) via `GetKeyForModeEffect.get_value_of_key/3`. It changes when the user selects a different route type or effect on the first form step.

---

## Phase 3: The Sync Pipeline (Every Form Change)

**Trigger:** `"validate"` LiveView event → `AlertData.sync/4`

Every form input fires a validate event that runs the full sync pipeline:

```
1. cast(changeset, params["alert_data"], form_fields(socket))
       Ecto type-casts incoming string params into typed fields.
       Only fields returned by form_fields/1 (union of all active slice struct keys) are accepted.

2. transform(changeset, params, socket)
       Each slice's transform/3 callback runs in order.
       Example: AlertDetailsSlice detects if the user manually edited header_text
       and flips header_sync_toggle, or regenerates header_text from a template.

3. validate(changeset, params, socket)
       Each slice's validate/3 callback adds Ecto validations.
       Example: AlertDetailsSlice validates header_text is present, URL is well-formed,
       image URL is reachable and from cdn.mbta.com, alt text is present if image is set.

4. apply_action(:validate)
       Marks the changeset as validated, populating changeset.errors.

5. assigns(socket, params)
       Each slice's assigns/3 callback populates socket assigns used by the template.
       Example: AlertDetailsSlice computes cause_options and image_size.
```

The socket is updated with `assign(:form, to_form(changeset))`. If validation failed, errors are present in the form.

---

## Phase 4: Async Service Data Loading

The service slices (e.g., `AffectedServiceSlice`) use `assign_async/3` to load route/stop/trip data from the MBTA V3 API in the background. These loads are triggered when relevant fields change (route IDs, direction, date).

Async results populate the `:selections` assign, which drives the dropdown options in the form. If the async task hasn't completed, the assigns contain `AsyncResult.loading()` and the UI shows a loading state.

---

## Phase 5: Review and Submit

**Trigger:** `"check_predictions"` event → shows `ReviewModal`

When the user clicks "Review and Submit", `SubmitSlice` checks for prediction suppression warnings via `PredictionSuppressionWarningModal.show_warning?/1`. The review modal renders a preview of the alert using `AlertBuilder.original_selections/1` to reconstruct human-readable descriptions of what was selected.

**Trigger:** `"save"` event → `send(self(), :create_alert)`

The save event is async (sent via `send/2`) to avoid blocking the LiveView process.

---

## Phase 6: AlertBuilder — Form Data → DB Map

**Module:** `AlertsUI.AlertBuilder`  
**Entry:** `AlertBuilder.build_alert(alert_data, combination, current_time, opts \\ [])`

This is the most complex transformation step. It converts the `AlertData` form struct into a flat map ready for the `Alert` changeset.

### Direct copy fields
These fields are passed through unchanged:
`header_text`, `description_text`, `service_effect_text`, `banner_text`, `url`, `image_url`, `image_alternative_text`, `recurrence_days`, `severity`, `source`, `created_timestamp`, `closed_timestamp`, `work_order_id`

### Computed fields

| Field | Logic |
|---|---|
| `recurrence_text` | Joins recurrence day atoms into human-readable string |
| `last_push_notification_timestamp` | Set to `current_time` if `notification_toggle: true`, else preserved |
| `severity_level` | Integer severity (1–10) → `SeverityLevel` atom (`:minor`, `:moderate`, `:severe`, `:unknown`) |
| `primary_service_type` | `route_type + combination` → string (`"0"`, `"1"`, `"access"`, `"systemwide"`, etc.) |
| `cause` | `cause_detail` string → enum atom via `Cause.get_by_mode_and_detail/2` |
| `effect` + `effect_detail` | `effect_name` string → `{effect_atom, effect_detail}` via `Effect.effect_map_by_name/1` |
| `reminder_times` | Naive Eastern datetimes → UTC (skipped for IBI-sourced alerts) |
| `plaintext_reminder_selections` | Reminder times formatted as ISO 8601 strings for audit history |

### Original selections (for audit/edit round-trip)
User selections are stored as pipe-delimited strings:
- `original_route_selections: ["Green Line|Green"]`
- `original_direction_selections: ["Outbound|0", "Inbound|1"]`
- `original_stop_selections: ["place-north"]`
- `original_trip_selections: ["Trip Name|trip_id"]`
- `original_facility_selections: ["Elevator|facility_id"]`

### Active periods

**One-time alerts:** `ActivePeriodBuilder.build_one_time_active_period/2`
- Converts start/end specifiers (`:now`, `:start_of_service`, `:custom`, `:end_of_service`, `:until_further_notice`, `:later_today`) + date/time inputs → UTC `DateTime` values
- **All times from the form are naive Eastern timezone. They are converted to UTC here.**

**Recurring alerts:** `ActivePeriodBuilder.build_recurring_active_period/1`
- Generates one `%{start: DateTime, end: DateTime}` entry per recurrence date, up to 1 year forward
- Uses `recurrence_days` to determine which days of the week apply

### Informed entities (combination-specific)

This is where `:R` vs `:RDTS` diverge most dramatically:

| Combination | Entity structure | Notes |
|---|---|---|
| `nil` (systemwide) | `[%{agency_id: "1"}]` or `[%{route_type: N}]` per service type | |
| `:R` | `[%{route_id: id, activities: [...]}]` per route | Green "route_id" expands to branch routes |
| `:RDS` | `[%{route_id: r, stop_id: s, direction_id: d}]` per (route, stop, dir) | Parent stops expanded to child stops via route patterns |
| `:RDT` | `[%{trip: %{trip_id:, route_id:, direction_id:}}]` per trip | Trip data fetched from API |
| `:RDTS` | `[%{route_id: r, stop_id: s, trip: ..., direction_id: d}]` | Both stop and trip expansion |
| `:SR` | `[%{route_id: r, stop_id: s, direction_id: d}]` | Stops validated to be on the route |
| `:ACCESS` | `[%{facility_id: f, stop_id: s, route_id: r}]` | Facility → child stops → routes |

Combinations `:RDS`, `:RDTS`, and `:SR` call `child_stops_with_context/3`, which fetches route patterns from the MBTA API to expand parent stop IDs into platform/child stop IDs.

---

## Phase 7: Database Write

**Module:** `AlertsUI.DBContexts.Alerts`  
**Function:** `Alerts.create_or_update_alert(params, user, existing_alert \\ %Alert{})`

```
Alert.changeset(existing_alert, params)
    │  Ecto validations + type casting against Alert schema
    ▼
Ecto.Changeset.put_assoc(:user, user)
    ▼
PaperTrail.insert_or_update(changeset, user: user, origin: "user")
    │  Writes to PostgreSQL; records audit version in versions table
    ▼
{:ok, %{model: alert}} | {:error, changeset}
```

`PaperTrail` records every insert and update in a `versions` table, storing a diff of changed fields. The `origin: "user"` tag distinguishes human-created versions from automated ones (e.g., IBI importer).

---

## Phase 8: Feed Export (Oban, every minute)

**Job:** `AlertsUI.Jobs.FeedWriter` (Oban cron: `*/1 * * * *`)  
**Entry:** `FeedWriter.perform/2` → `WriteFeed.write_feed/1`

### Alert fetching and filtering

```
Alerts.list_all_open()           # WHERE closed_timestamp IS NULL
    │  Preloads: :user, :reminder_times, active_period (ordered), informed_entity with :trip
    ▼
Alerts.update_end_if_estimated() # If start is past, move estimated end to 2h from now
    ▼
Alerts.close_if_end_is_past()    # Auto-closes alerts whose active_period_end <= now
    ▼
Alerts.filter_on_notification_period_start()  # Exclude if notification_period_start > now
    ▼
Enum.map(&CreateOutputAlert.build_alert/1)    # DB struct → GTFS-RT map
```

Recently closed alerts (last 5 minutes) follow the same path without the filtering steps.

IBI alerts are fetched directly from S3 as JSON and concatenated without deduplication.

### Feed transformation

`CreateOutputAlert.build_alert/1` converts an `Alert` struct to a GTFS-RT-shaped map:

- Text fields → `%{translation: [%{text: ..., language: "en"}]}` (TranslatedString)
- `DateTime` values → Unix integer timestamps
- `active_period` records → `[%{start: unix, end: unix}]` (past-end periods filtered out)
- `informed_entity` records → maps with `route_id`, `stop_id`, `direction_id`, `activities`, etc.
- `nil` values are removed from the output map

`CreateStandardAlert.build_standard_alert/1` further filters to only the fields allowed by the GTFS-RT spec.

### Feed variants and filenames

| Flavor | Input alerts | Module | Output file |
|---|---|---|---|
| `:standard` | Open only | `CreateGtfsJson.output_standard_json/1` | `alerts_manager_feed.json` |
| `:enhanced` | Open + recently closed | `CreateGtfsJson.output_enhanced_json/1` | `alerts_manager_feed_enhanced.json` |
| `:protobuf` | Open only | `CreateGtfsProtobuf.output_protobuf/1` | `alerts_manager_feed.pb` |
| `:combined_standard` | Open + IBI standard | `CreateGtfsJson.output_standard_json/1` | `alerts_feed.json` |
| `:combined_enhanced` | Open + recently closed + IBI enhanced | `CreateGtfsJson.output_enhanced_json/1` | `alerts_feed_enhanced.json` |
| `:combined_enhanced_sita` | Same as above, SITA-filtered | `CreateGtfsJson.output_enhanced_json/1` | `alerts_feed_enhanced_SITA.json` |
| `:combined_protobuf` | Open + IBI standard | `CreateGtfsProtobuf.output_protobuf/1` | `alerts_feed.pb` |

**SITA filtering** (`Filters.filter_sita_alerts/1`): For commuter rail alerts with effect_detail in `["SHUTTLE", "SUSPENSION", "STATION_CLOSURE"]`, removes `stop_id` and `activities` from informed entities so the alert affects the entire line rather than individual stops.

### Protobuf encoding

`CreateGtfsProtobuf.output_protobuf/1` converts the standard JSON map to a protobuf binary:
- Keys atomized via `Map.Helpers.atomize_keys/1`
- Nested structs constructed: `Alert.new/1`, `EntitySelector.new/1`, `FeedEntity.new/1`, `FeedHeader.new/1`
- Enum fields (`effect`, `cause`, `severity_level`, `schedule_relationship`) converted to atoms via `String.to_existing_atom/1`
- Final binary via `FeedMessage.encode/1`

### S3 write

```elixir
# Production
WriteToS3.write(filename, data)
    └─ ExAws.S3.put_object(bucket, "#{prefix}/#{filename}", data, content_type: ...)

# Development
WriteLocal.write(filename, data)
    └─ File.write("./assets/outputs/#{filename}", data)
```

Bucket and prefix come from `S3_BUCKET_NAME` and `S3_BUCKET_PREFIX` environment variables.

---

## Phase 9: Feed Verification

**Job:** `AlertsUI.Jobs.FeedChecker` (Oban cron: `*/1 * * * *`)

After each write cycle, `FeedChecker` fetches all 4 published feeds from S3, computes MD5 checksums, and logs them:

```
enhanced=<md5> standard=<md5> sita=<md5> protobuf=<md5>
```

This provides a lightweight integrity signal without validating GTFS structure.

---

## Key Invariants

1. **All times in the form are naive Eastern timezone.** `ActivePeriodBuilder` converts them to UTC before any DB write. Feed output converts UTC `DateTime` values to Unix timestamps.

2. **Informed entities are deduplicated** at the end of `AlertBuilder.build_informed_entities/3` via `.uniq()`.

3. **Slices are order-dependent.** `AlertDetailsSlice` reads fields set by `UrlSlice` (combination, route_type, effect_name) and `TimelineSlice` (active_period_start/end). The order in `AlertData.slices/1` is not arbitrary.

4. **IBI alerts are not deduplicated** against local alerts. Their IDs are assumed not to conflict with local `alert_id` values.

5. **`nil` values are stripped** from GTFS-RT output maps at every level (alert, informed_entity, trip, active_period). This keeps feeds compact and avoids sending null fields to consumers.

6. **Green Line expansion:** The `"Green"` route ID is treated specially in `AlertBuilder` — it is expanded into branch routes (B, C, D, E) when building informed entities for `:R` and `:RDS` combinations.
