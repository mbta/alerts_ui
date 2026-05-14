# Domain Ontology

_Generated: 2026-05-14T19:30:00-05:00_
_Repos covered: alerts_ui_

## Source of truth

Primary source is the Ecto schema definitions in `lib/alerts_ui/models/` cross-referenced
against migration files in `priv/repo/migrations/`. Where the two agree, the schema is
cited. The migration files are used to confirm column presence and foreign key structure.
The external MBTA V3 API types (Route, Stop, Schedule, Facility) are owned by the
`deps/mbta_v3_api` git dependency — this ontology covers their local representations only.

---

## Entities

### Alert
- **Purpose:** A transit service disruption, change, or notice that operators author and publish to riders via GTFS-RT feeds and MBTA digital channels.
- **Key attributes:**
  - `alert_id` — public-facing string identifier (human-readable, prefixed, e.g. "113462")
  - `effect` / `effect_detail` / `effect_name` — what is happening (e.g. `:NO_SERVICE`, `"SUSPENSION"`, `"Suspension"`)
  - `cause` / `cause_detail` — why it's happening (e.g. `:MAINTENANCE`, `"TRACK_WORK"`)
  - `header_text` / `description_text` — rider-facing message text
  - `draft` — whether the alert has been published or is still in draft
  - `closed_timestamp` — when the alert was closed (nil = open)
  - `primary_service_type` — the mode selected on the form ("bus", "subway", "access", etc.)
  - `source` — where the alert originated (`:alerts_ui`, `:ibi`, etc.)
  - `work_order_id` — optional link to a Trapeze work order
  - `recurring` — whether the alert recurs on a schedule
- **Source:** `lib/alerts_ui/models/alert.ex:210`

### InformedEntity
- **Purpose:** A single affected service entity within an alert — the specific route, stop, facility, or direction that a disruption affects. An alert may have many InformedEntities covering different parts of the network.
- **Key attributes:**
  - `route_id` — GTFS route ID (e.g. "Red", "39")
  - `stop_id` — GTFS stop ID (e.g. "place-dwnxg")
  - `facility_id` — GTFS facility ID (e.g. elevator or escalator ID)
  - `route_type` — integer mode code (0=light rail, 1=subway, 2=commuter rail, 3=bus, 4=ferry, nil=systemwide/facility)
  - `direction_id` — 0 or 1 (inbound/outbound); nil if whole route affected
  - `activities` — list of affected rider activities (e.g. `:BOARD`, `:EXIT`, `:RIDE`, `:using_wheelchair`)
- **Source:** `lib/alerts_ui/models/informed_entity.ex:57`

### ActivePeriod
- **Purpose:** A time window during which an alert is active. An alert may have multiple non-overlapping active periods (e.g. for recurring or multi-day disruptions). Service day boundaries are defined as 3:00 AM Eastern.
- **Key attributes:**
  - `start` — start of the active window (nil = open-ended start)
  - `end` — end of the active window (nil = open-ended end)
- **Source:** `lib/alerts_ui/models/active_period.ex:18`

### TripDescriptor
- **Purpose:** Identifies a specific trip affected by an alert, per the GTFS-RT spec. Attached to an InformedEntity when the disruption targets a specific scheduled trip rather than a whole route or stop.
- **Key attributes:**
  - `trip_id` — GTFS trip ID (if known)
  - `route_id` — route of the trip
  - `direction_id` — direction of the trip
  - `start_time` — scheduled departure time of the trip
  - `start_date` — service date of the trip
  - `schedule_relationship` — `:SCHEDULED`, `:ADDED`, `:UNSCHEDULED`, `:CANCELED`
- **Source:** `lib/alerts_ui/models/trip_descriptor.ex:26`

### ReminderTime
- **Purpose:** A scheduled time at which the system will send a push notification reminding riders about a future disruption. Each reminder is a single UTC datetime; an alert may have multiple reminders.
- **Key attributes:**
  - `reminder_time` — UTC datetime for the notification delivery
- **Source:** `lib/alerts_ui/models/reminder_time.ex:19`

### User
- **Purpose:** An MBTA staff member who authors and manages alerts. Users are provisioned via Keycloak OIDC; the database record is created lazily on first alert creation. Roles control which UI features and actions are available.
- **Key attributes:**
  - `keycloak_id` — stable external identity from Keycloak (used to correlate across sessions)
  - `email` — MBTA email address
  - `first_name` / `last_name` — display name
  - `roles` — virtual field populated from Keycloak JWT: `:viewer`, `:author`, `:developer`
- **Source:** `lib/alerts_ui/models/user.ex:24`

### IBIAlert
- **Purpose:** A raw alert record imported from IBI (a third-party transit operations vendor). Each row represents a single version of an IBI alert. Multiple versions with the same `alert_id` and increasing `integer_version_no` represent revisions to the same alert.
- **Key attributes:**
  - `alert_id` — IBI's alert identifier (different namespace from the local `Alert.alert_id`)
  - `integer_version_no` — monotonically increasing version counter
  - `alert_time_type` — alert classification (e.g. "Planned", "Realtime", "Template"; Templates are excluded from the active view)
  - `is_closed` — string flag; "true" means the alert is closed in IBI
  - `header` / `details` — rider-facing text
  - `effect_name` / `cause_name` / `severity_name` — IBI-native classification strings (must be mapped to local enum values during import)
- **Source:** `lib/alerts_ui/models/ibi_alert.ex:104`

### LatestIBIAlert
- **Purpose:** A database view that surfaces only the most-recent version of each IBI alert, excluding Template alerts. Used by the IBI importer to determine which alerts are current without scanning all historical versions.
- **Key attributes:** (same columns as IBIAlert — view inherits all fields)
- **Source:** `lib/alerts_ui/models/latest_ibi_alert.ex:27`

### FeatureFlag
- **Purpose:** A named boolean switch that enables or disables application-wide features at runtime. Stored in the database (not in code) so operators can toggle without a deployment.
- **Key attributes:**
  - `name` — feature flag identifier string
  - `enabled` — boolean state
- **Source:** `lib/alerts_ui/models/feature_flag.ex:20`

---

## Value Objects (non-entity types)

These types carry domain meaning but have no independent database identity.

| Type | Purpose | Source |
|------|---------|--------|
| `Effect` | Enumerated GTFS-RT effect codes (`:NO_SERVICE`, `:DETOUR`, `:REDUCED_SERVICE`, etc.) with human-readable display names and free-text `effect_detail` strings | `lib/alerts_ui/models/effect.ex:6` |
| `Cause` | Enumerated GTFS-RT cause codes (`:MAINTENANCE`, `:WEATHER`, `:ACCIDENT`, etc.) with per-mode detail strings | `lib/alerts_ui/models/cause.ex:1` |
| `AlertLifecycle` | Alert lifecycle phase: `:NEW_ALERT`, `:ONGOING_ALERT`, `:UPDATED_ALERT`, `:UPCOMING_ALERT` | `lib/alerts_ui/models/alert_lifecycle.ex` |
| `DurationCertainty` | Whether an alert's end time is known: `:UNKNOWN`, `:ESTIMATED`, `:KNOWN` | `lib/alerts_ui/models/duration_certainty.ex` |
| `SeverityLevel` | GTFS-RT severity: `:INFO`, `:WARNING`, `:SEVERE` | `lib/alerts_ui/models/severity_level.ex` |
| `Activity` | Rider activity types for InformedEntity: `:BOARD`, `:EXIT`, `:RIDE`, `:PARK_CAR`, `:BRINGING_BIKE`, `:STORE_BIKE`, `:USING_WHEELCHAIR`, `:USING_ESCALATOR` | `lib/alerts_ui/models/activity.ex` |
| `ScheduleRelationship` | GTFS-RT trip schedule relationship: `:SCHEDULED`, `:ADDED`, `:UNSCHEDULED`, `:CANCELED` | `lib/alerts_ui/models/schedule_relationship.ex` |
| `Source` | Where an alert originated: `:alerts_ui`, `:ibi`, `:trapeze` | `lib/alerts_ui/models/source.ex` |
| `ExtendedTime` | Embedded time representation with hours beyond 24 (for overnight GTFS trips) | `lib/alerts_ui/models/extended_time.ex` |

---

## Relationships

| From | To | Type | Cardinality | Evidence |
|------|----|------|-------------|----------|
| Alert | User | belongs-to | Many-to-one, optional (nil if user deleted) | `lib/alerts_ui/models/alert.ex:211` `belongs_to :user` |
| Alert | InformedEntity | has-many | One-to-many, zero or more | `lib/alerts_ui/models/alert.ex:244` `has_many :informed_entity` |
| Alert | ActivePeriod | has-many | One-to-many, one or more | `lib/alerts_ui/models/alert.ex:236` `has_many :active_period` |
| Alert | ReminderTime | has-many | One-to-many, zero or more | `lib/alerts_ui/models/alert.ex:235` `has_many :reminder_times` |
| InformedEntity | Alert | belongs-to | Many-to-one | `lib/alerts_ui/models/informed_entity.ex:58` `belongs_to :alert` |
| InformedEntity | TripDescriptor | has-one | One-to-one, optional | `lib/alerts_ui/models/informed_entity.ex:66` `has_one :trip` |
| TripDescriptor | InformedEntity | belongs-to | Many-to-one | `lib/alerts_ui/models/trip_descriptor.ex:27` `belongs_to :informed_entity` |
| ActivePeriod | Alert | belongs-to | Many-to-one | `lib/alerts_ui/models/active_period.ex:19` `belongs_to :alert` |
| ReminderTime | Alert | belongs-to | Many-to-one | `lib/alerts_ui/models/reminder_time.ex:19` `belongs_to :alert` |
| User | Alert | has-many | One-to-many | `lib/alerts_ui/models/user.ex:31` `has_many :alerts` |
| IBIAlert | (none) | standalone | Row per version; no FK to Alert | `ibi_alerts` table has `alert_id` string but no foreign key to `alerts` |
| LatestIBIAlert | IBIAlert | view over | Database view, not a separate table | `lib/alerts_ui/models/latest_ibi_alert.ex:27` |

**External (non-persisted) references:** `InformedEntity.route_id`, `.stop_id`, and `.facility_id` are string identifiers whose canonical records live in the MBTA V3 API (via the `MBTAV3API` git dependency), not in the local database. These are resolved at runtime via ConCache-backed repos.

---

## Glossary

| Term | Definition | Where it appears |
|------|-----------|-----------------|
| Alert | A transit service disruption, change, or notice authored by MBTA staff and published to riders. The central entity of the system. | `lib/alerts_ui/models/alert.ex`, throughout |
| InformedEntity | A single affected service scope within an alert — the specific route, stop, facility, or direction the disruption touches. One alert usually has several. | `lib/alerts_ui/models/informed_entity.ex` |
| ActivePeriod | A time window during which the alert is in effect. Multiple non-contiguous periods are used for recurring or multi-day disruptions. | `lib/alerts_ui/models/active_period.ex` |
| Effect / Effect Detail | What is operationally happening (e.g. "Suspension", "Delay"). `effect` is the GTFS-RT enum atom; `effect_detail` is a free-text subtype; `effect_name` is the human-readable label shown in the UI. | `lib/alerts_ui/models/effect.ex` |
| Cause / Cause Detail | Why the disruption is happening (e.g. "Track Work"). `cause` is the GTFS-RT enum; `cause_detail` is a mode-specific free-text subtype. | `lib/alerts_ui/models/cause.ex` |
| Draft | An alert that has been saved but not yet published. Draft alerts are not included in the GTFS-RT feed. | `lib/alerts_ui/models/alert.ex:245` |
| Closed | An alert with a non-nil `closed_timestamp`. Closed alerts are excluded from the live feed. | `lib/alerts_ui/models/alert.ex:229` |
| Service Day | MBTA's transit service day, which runs from 3:00 AM to 3:00 AM the following calendar day. Times before 3:00 AM are considered part of the previous day. | `lib/alerts_ui/models/active_period.ex:10-11` |
| Primary Service Type | The top-level mode selected during alert creation: "bus", "subway", "light_rail", "commuter_rail", "ferry", "access", or "systemwide". Denormalized on the Alert for display and filtering. | `lib/alerts_ui/models/alert.ex:249` |
| Combination | An atom (`:ACCESS`, `:R`, `:RDS`, `:RDT`, `:RDTS`, `:SR`) in the `CreateAlertMonoLive` form flow that encodes which service selection pattern the user has chosen, controlling which form slices are activated. Currently undocumented — meaning inferred from `ServiceSliceDispatcher` logic. | `lib/alerts_ui_web/live/create_alert_mono_live/alert_data.ex:37-38` |
| Slice | A module implementing the `Slice` protocol in the mono alert creation flow. Each slice owns one step of the multi-step form (`mount/3`, `extract/3`, `transform/3`, `validate/3`, `assigns/3`). | `lib/alerts_ui_web/live/create_alert_mono_live/slice.ex` |
| GTFS-RT | General Transit Feed Specification — Realtime. The protobuf-based format used to publish alert data to MBTA apps and third-party consumers. The feed is assembled by `FeedWriter` every 30 seconds and written to AWS S3. | `lib/alerts_ui/feed_output/`, `lib/alerts_ui/jobs/` |
| IBI Alert | An alert record imported from IBI, a third-party transit operations vendor. IBI alerts are stored verbatim and then converted to the local `Alert` format by the `IBIAlertImporter`. | `lib/alerts_ui/models/ibi_alert.ex` |
| Trapeze Work Order | A work order from the Trapeze maintenance management system, linked to an alert via `work_order_id`. The `Trapeze.Importer` Oban worker polls Trapeze via SFTP to import new work orders. | `lib/alerts_ui/trapeze/` |
| Notification Period | The time window during which push notifications about the alert may be sent to riders (distinct from the `ActivePeriod`, which is when the disruption is in effect). | `lib/alerts_ui/models/alert.ex:246-247` |
| Reminder Time | A scheduled datetime at which the system will fire a push notification reminding riders about an upcoming disruption. | `lib/alerts_ui/models/reminder_time.ex` |
| Feature Flag | A named boolean stored in the database that enables or disables a code path at runtime, without requiring a deployment. | `lib/alerts_ui/models/feature_flag.ex` |
| PaperTrail | The audit history library recording all changes to Alert records. Each mutation creates a version row in the `versions` table (added in migration `20240318165608_add_versions.exs`). | `priv/repo/migrations/20240318165608_add_versions.exs` |
| Enhanced Feed | A proprietary JSON feed (not GTFS-RT) written to S3 alongside the standard feed, containing additional MBTA-specific fields not present in the GTFS-RT protobuf. | `lib/alerts_ui/feed_output/write_feed.ex` |
| Source | Which system created an alert — `:alerts_ui` (authored here), `:ibi` (imported from IBI), or `:trapeze` (imported from Trapeze). | `lib/alerts_ui/models/source.ex`, `lib/alerts_ui/models/alert.ex:143` |

---

## Bounded Contexts

The codebase organizes around three loosely separated concerns. There are no hard service
boundaries (single-repo, single database), but the module structure reflects implicit grouping.

### Alert Authoring
The core domain — creating, editing, validating, and publishing alerts authored by MBTA staff.

**Entities:** Alert, InformedEntity, ActivePeriod, TripDescriptor, ReminderTime, User

**Key modules:**
- `AlertsUI.DBContexts.Alerts` — query context (list, get, create, update, close)
- `AlertsUIWeb.Live.CreateAlertLive` — legacy multi-route creation flow
- `AlertsUIWeb.Live.CreateAlertMonoLive` — newer single-route creation flow with Slice protocol
- `AlertsUI.Models.*` — Ecto schemas

### Feed Publication
Assembles and exports GTFS-RT and enhanced JSON feeds from open alerts to AWS S3.

**Entities:** Alert (read-only), InformedEntity, ActivePeriod, TripDescriptor

**Key modules:**
- `AlertsUI.FeedOutput.*` — feed assembly pipeline
- `AlertsUI.Jobs.FeedWriter` — Oban worker (every 30 seconds)
- `AlertsUI.Jobs.FeedChecker` — validates published feed against DB state (every minute)
- `AlertsUI.Jobs.FeedExporter` — export to additional downstream systems

### External Ingestion
Imports alerts from third-party systems (IBI, Trapeze) and converts them to the local Alert format.

**Entities:** IBIAlert, LatestIBIAlert; produces Alert records

**Key modules:**
- `AlertsUI.IBIAlertImporter.*` — IBI import pipeline
- `AlertsUI.Trapeze.*` — Trapeze SFTP work-order bridge
- `AlertsUI.Jobs.Trapeze.Importer` — Oban worker polling Trapeze

### Infrastructure
Cross-cutting concerns: feature flags, authentication, validation.

**Entities:** FeatureFlag, User (authentication only)

**Key modules:**
- `AlertsUI.Models.FeatureFlag` + `AlertsUI.DBContexts.FeatureFlags`
- `AlertsUIWeb.Router` — OIDC-protected scopes (`:viewer`, `:author`, `:developer`)
- `AlertsUI.AlertValidation.*` — validates alerts against live GTFS data

---

## Confidence

- **Entity definitions** are directly observed from Ecto schema `schema "..."` blocks and `@type t` typespecs. High confidence.
- **Relationships** are confirmed from `belongs_to`, `has_many`, `has_one` declarations and migration foreign key definitions. High confidence.
- **Glossary entries for Combination and Slice** are inferred from the code structure and `ServiceSliceDispatcher` logic — these terms have no written definitions in the codebase (documented as a gap in `dimensions/documentation.md` F1–F2). Medium confidence on the `Combination` semantics.
- **IBIAlert → Alert relationship** is implicit — the importer uses `alert_id` as a string correlation key, not a database foreign key. Confirmed by reading the IBI importer and migration files.
- **Bounded context grouping** is inferred from module directory structure and is coarse. No explicit bounded-context documentation exists in the codebase. Treat as directional.
- **External API entities** (Route, Stop, Schedule, Facility from MBTAV3API) are not listed as primary entities — they are owned by an external system and cached locally with 1-hour TTL. Their shapes are defined in `deps/mbta_v3_api/`, outside this repo's domain boundary.
