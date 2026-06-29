# Edit Alert: Time Range Initialization Bug

## Summary

When editing an existing alert in the mono flow, two symptoms appear on initial page load:
1. **Missing date selectors**: The date picker inputs for the effect period are not visible
2. **Incorrect duration text**: The duration shows the wrong end date (e.g., "Friday June 5" instead of "Thursday June 4")

Both symptoms vanish after the user interacts with the form (e.g., types in any text field), which triggers a `phx-change="validate"` event.

---

## How the Bug Manifests (Data Flow)

**`build_alert_data/2`** (`lib/alerts_ui_web/live/form_components/helpers/alert_data.ex`)

Converts a DB `Alert` struct to form data. Specifiers are returned as **strings**, not atoms:

```elixir
# line 357–358
active_period_start_specifier: determine_start_specifier(shifted_active_period_start),
active_period_end_specifier: end_specifier,   # e.g. "end_of_service"
```

`determine_end_specifier/3` (line 457) returns `"end_of_service"` (string). The end date is
back-adjusted by one day to get the *service* date:

```elixir
# line 424
def end_date(ap_end, "end_of_service"), do: ap_end |> NaiveDateTime.to_date() |> Date.add(-1)
```

So for an alert stored as `active_period_end = ~N[2026-06-05 03:00:00]` (end-of-service for
June 4), `active_period_end_date = ~D[2026-06-04]`.

**`AlertData.init/4`** (`lib/alerts_ui_web/live/create_alert_mono_live/alert_data.ex`, line 267)

Calls `sync` with only 3 fields:

```elixir
sync(struct, socket, params, init_param_fields())
# init_param_fields/0 = [:alert_id, :effect_name, :route_type]
```

Because only 3 fields are cast, `active_period_end_specifier` is **never passed through
`Ecto.Changeset.cast`**, so it stays as the string `"end_of_service"` rather than being
normalised to the atom `:end_of_service`.

---

## Three Hypotheses (Ranked by Plausibility)

### Hypothesis 1 — String specifier silently skips `ensure_end_date_values_for_specifier`, leaving the raw DB datetime uncorrected *(most plausible)*

**Root cause:** `ensure_end_date_values_for_specifier` in `time_range_slice.ex` pattern-matches
only on **atoms**:

```elixir
# lines 302–312
def ensure_end_date_values_for_specifier(changeset, :end_of_service, _, d, _) do
  force_change(changeset, :active_period_end,
    NaiveDateTime.new!(d, ActivePeriod.end_of_service_time()))
end

def ensure_end_date_values_for_specifier(changeset, _, _, _, _), do: changeset  # catch-all no-op
```

When the specifier is the string `"end_of_service"`, the clause above is skipped and the
catch-all runs. `active_period_end` is never recomputed from `active_period_end_date`
(`~D[2026-06-04]`); it stays as the raw DB value (`~N[2026-06-05 03:00:00]`).

**Why the duration shows the wrong date:**

`DurationText.one_time_duration_end_phrase/1` (`lib/alerts_ui_web/live/create_alert_mono_live/helpers/duration_text.ex`, line 27) reads:

```elixir
end_dt = ensure_naive_datetime_format(form[:active_period_end].value)
end_text(form[:active_period_end_specifier].value, end_dt)
```

With `active_period_end = ~N[2026-06-05 03:00:00]`, this formats as "Friday Jun 5" — the
raw, un-adjusted DB date — rather than "Thursday Jun 4", the correct *service* date.

**After user interaction:** The `"validate"` event fires with full form params. `AlertData.sync`
casts **all** fields via `form_fields(socket)` (no restriction). Ecto.Enum converts
`"end_of_service"` → `:end_of_service`. The atom specifier now matches the ensure function's
clause. `active_period_end` is recomputed as `NaiveDateTime.new!(~D[2026-06-04], end_of_service_time())`.
Duration correctly shows "Thursday Jun 4".

**Key files:**
- `time_range_slice.ex:254–312` — `ensure_end_date_values_for_specifier` (atom-only clauses)
- `alert_data.ex:362` — `init_param_fields/0`
- `form_components/helpers/alert_data.ex:357–358, 424, 457–463` — string specifiers and date back-adjustment
- `duration_text.ex:27–29` — reads raw `active_period_end` value

---

### Hypothesis 2 — Template visibility checks for `end_of_service`/`start_of_service` specifiers use atom-only comparisons, hiding the date pickers when the specifier is a string *(plausible — explains missing selectors)*

**Root cause:** Commit `90ab206a` ("Fix date selector not showing up when editing an alert
with custom start/end") is described as fixing the `:custom` specifier case. If the
`end_of_service` and `start_of_service` visibility checks were **not** updated in that commit,
they would still use atom-only comparisons:

```elixir
# before fix (hypothesised original):
if fv(@form, :active_period_end_specifier) == :end_of_service, do: "", else: "hidden"

# after fix for custom only (90ab206a likely changed):
if fv(@form, :active_period_start_specifier) in [:custom, "custom"], do: "", else: "hidden"
# but may have left end_of_service unchanged at:
if fv(@form, :active_period_end_specifier) == :end_of_service, do: "", else: "hidden"
```

With a string specifier `"end_of_service"`, `"end_of_service" == :end_of_service` is `false`
in Elixir. The picker gets the `hidden` CSS class → **date selector is invisible**.

After user interaction, Ecto.Enum cast converts the string to an atom. The atom comparison
succeeds → picker becomes visible.

**Current code state:** The code at lines 552 and 570 of `time_range_slice.ex` does include
both atoms and strings in the checks. If those checks are present, this hypothesis explains
the bug that *existed prior to* those lines being added. If the `end_of_service` checks were
NOT updated alongside the `:custom` checks in `90ab206a`, this is the mechanism that causes
the missing selector.

**Key files:**
- `time_range_slice.ex:541, 552, 570, 577` — template visibility conditions
- Commit `90ab206a` (scope of fix: "custom start/end" specifically)

---

### Hypothesis 3 — `init_param_fields()` design creates a systemic atom/string inconsistency that breaks every atom-specific function in the time-range pipeline *(structural root cause)*

**Root cause:** The choice to cast only `[:alert_id, :effect_name, :route_type]` during init
means that the entire time-range subsystem is initialised with string specifiers. Every
downstream function that pattern-matches on atoms silently skips the string case:

| Function | String specifier result |
|---|---|
| `ensure_end_date_values_for_specifier` | catch-all no-op — wrong `active_period_end` |
| `required_one_time_end_fields` | catch-all `[]` — no required-field validation |
| `validate_recurring_start` via `specifier == :custom` | skipped — no past-start validation |
| `end_error/2` in `get_recurring_end_errors` | catch-all error message |

The pattern is: any function that pattern-matches on atoms will silently degrade for string
specifiers, producing subtly wrong behaviour that only appears on first render (before any
user interaction triggers a full-fields cast).

`alert_data_v1_to_v2/1` (`alert_data.ex:372`) is the natural place to normalise these
strings to atoms, but currently only handles `effect_name` and toggle fields:

```elixir
def alert_data_v1_to_v2(v1_alert_data) do
  v1_alert_data
  |> normalize_effect_name()
  |> set_sync_toggles()
  # missing: normalize specifier strings to atoms
end
```

**Key files:**
- `alert_data.ex:362` — `init_param_fields/0`
- `alert_data.ex:372–376` — `alert_data_v1_to_v2/1` (missing specifier normalisation)
- `time_range_validators.ex:346–352` — `required_one_time_end_fields` (atom-only)
- `time_range_validators.ex:83` — `== :custom` atom-only guard

---

## Evidence Summary

| Evidence | Source |
|---|---|
| `determine_end_specifier` returns strings | `form_components/helpers/alert_data.ex:457–463` |
| `init_param_fields` excludes specifier fields | `alert_data.ex:362` |
| Ensure functions pattern-match only on atoms | `time_range_slice.ex:254–312` |
| Duration text reads raw `active_period_end` value | `duration_text.ex:27` |
| After validate event: full cast via `form_fields/1` | `alert_data.ex:278`, `create_alert_mono_live.ex:90–92` |
| `alert_data_v1_to_v2` normalises only effect name | `alert_data.ex:372–376` |

## Suggested Fix Direction

The cleanest fix is to normalise string specifiers to atoms **before** the mono flow processes
them, either in `build_alert_data` itself (change return type from strings to atoms) or in
`alert_data_v1_to_v2`. A secondary fix is to extend `ensure_end_date_values_for_specifier`
and its sibling to also match string variants of each specifier.
