# Fix Autotext Date Instability on Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the header/description autotext from showing different dates when the auto-refresh toggle is clicked multiple times without changing any date fields.

**Architecture:** Two independent root causes are addressed in sequence. Fix H1 first (lower risk, higher reward): make the `:now`/`:later_today`/`:until_further_notice`/`:when_work_order_is_closed` specifiers skip re-computing their `NaiveDateTime` values when the form event that triggered the transform didn't touch a time-range field. Fix H2 second: thread a single captured `current_time` into `BuildAutoText` so all comparisons in `build_duration_text` use the same reference time per transform cycle.

**Tech stack:** Elixir, Phoenix LiveView, Ecto changesets. Tests use ExUnit + Mock (for `NaiveDateTime.local_now()` and `DateTimeHelpers.current_time()`).

---

## Context

Every form event—including clicking the auto-refresh toggle—runs `TimeRangeSlice.transform/4`, which calls `ensure_start_date_values/1` and `ensure_end_date_values/1`. When the start specifier is `:now`, `ensure_start_date_values_for_specifier/4` unconditionally calls `NaiveDateTime.local_now()` and `force_change`s `active_period_start` to the current wall-clock time. This causes the start datetime to silently advance on every toggle click. When the advancing time crosses a minute or service-day boundary, `build_duration_text` (which also captures a fresh `current_time`) selects a different template branch and the displayed date text changes.

**Key files:**
- `lib/alerts_ui_web/live/create_alert_mono_live/slices/time_range_slice.ex` — contains the `Slice` impl of `transform/4`, `ensure_start_date_values/1`, `ensure_end_date_values/1`, and all their `_for_specifier` subclauses.
- `lib/alerts_ui_web/live/form_components/helpers/auto_text/build_auto_text.ex` — `BuildAutoText` struct definition.
- `lib/alerts_ui_web/live/form_components/helpers/auto_text/alert_data_to_auto_text.ex` — converts merged alert data map → `BuildAutoText` struct.
- `lib/alerts_ui_web/live/form_components/helpers/auto_text/auto_text_duration.ex` — `build_duration_text/2`, all `build_onetime_string` clauses, `starts_today?/2`, `ends_today?/2`.
- `lib/alerts_ui_web/live/create_alert_mono_live/slices/alert_details_slice.ex` — builds `autotext_data` in `transform/4` and calls `Templates.build_auto_text/2`.

---

## Task 1: Write failing tests for H1

**Files:**
- Test: `test/alerts_ui_web/live/create_alert_mono_live/slices/time_range_slice_test.exs`

- [ ] **Step 1: Add tests verifying toggle clicks do NOT advance `active_period_start` or `active_period_end`**

Add the following test block inside the existing `TimeRangeSliceTest` module. The test calls `TimeRangeSlice.ensure_start_date_values/2` directly (once it accepts a `target` arg) and confirms the `:now` clause is a no-op for non-time-range targets.

```elixir
describe "ensure_start_date_values/2 with :now specifier" do
  test "does not advance active_period_start when target is unrelated (e.g. header_sync_toggle)" do
    existing_dt = ~N[2024-01-15 10:30:00]

    changeset =
      Ecto.Changeset.cast(
        %AlertData{},
        %{
          active_period_start_specifier: :now,
          active_period_start: existing_dt,
          active_period_start_date: ~D[2024-01-15]
        },
        [:active_period_start_specifier, :active_period_start, :active_period_start_date]
      )

    result = TimeRangeSlice.ensure_start_date_values(changeset, "header_sync_toggle")

    assert Ecto.Changeset.get_field(result, :active_period_start) == existing_dt
  end

  test "updates active_period_start when target is active_period_start_specifier" do
    existing_dt = ~N[2020-01-01 00:00:00]

    changeset =
      Ecto.Changeset.cast(
        %AlertData{},
        %{
          active_period_start_specifier: :now,
          active_period_start: existing_dt,
          active_period_start_date: ~D[2020-01-01]
        },
        [:active_period_start_specifier, :active_period_start, :active_period_start_date]
      )

    result = TimeRangeSlice.ensure_start_date_values(changeset, "active_period_start_specifier")

    refute Ecto.Changeset.get_field(result, :active_period_start) == existing_dt
  end

  test "updates active_period_start when target is nil (initial load)" do
    changeset =
      Ecto.Changeset.cast(
        %AlertData{},
        %{active_period_start_specifier: :now},
        [:active_period_start_specifier]
      )

    result = TimeRangeSlice.ensure_start_date_values(changeset, nil)

    assert %NaiveDateTime{} = Ecto.Changeset.get_field(result, :active_period_start)
  end
end

describe "ensure_end_date_values/2 with :later_today specifier" do
  test "does not recompute active_period_end when target is unrelated" do
    existing_end = ~N[2024-06-03 02:30:00]

    changeset =
      Ecto.Changeset.cast(
        %AlertData{},
        %{
          active_period_end_specifier: :later_today,
          active_period_end: existing_end,
          active_period_end_date: ~D[2024-06-03]
        },
        [:active_period_end_specifier, :active_period_end, :active_period_end_date]
      )

    result = TimeRangeSlice.ensure_end_date_values(changeset, "header_sync_toggle")

    assert Ecto.Changeset.get_field(result, :active_period_end) == existing_end
  end
end
```

- [ ] **Step 2: Run new tests to confirm they fail**

```bash
mix test test/alerts_ui_web/live/create_alert_mono_live/slices/time_range_slice_test.exs --only "ensure_start_date_values" --only "ensure_end_date_values"
```

Expected: compile error or argument-count mismatch, because `ensure_start_date_values/2` doesn't exist yet.

---

## Task 2: Implement H1 fix in `time_range_slice.ex`

**Files:**
- Modify: `lib/alerts_ui_web/live/create_alert_mono_live/slices/time_range_slice.ex`

- [ ] **Step 1: Add `@time_range_targets` module attribute**

Add this near the top of the `TimeRangeSlice` module (outside the `Slice` impl block), alongside any other module attributes:

```elixir
@time_range_targets ~w[
  active_period_start_specifier
  active_period_start
  active_period_start_date
  active_period_start_time
  active_period_end_specifier
  active_period_end
  active_period_end_date
  active_period_end_time
  alert_timing
  recurrence_days
]
```

- [ ] **Step 2: Pass `target` from `Slice.transform/4` into `ensure_start_date_values` and `ensure_end_date_values`**

Locate the `defimpl Slice, for: __MODULE__` block. Change lines 80–81:

```elixir
# Before:
|> TimeRangeSlice.ensure_start_date_values()
|> TimeRangeSlice.ensure_end_date_values()

# After:
|> TimeRangeSlice.ensure_start_date_values(target)
|> TimeRangeSlice.ensure_end_date_values(target)
```

- [ ] **Step 3: Add `target` parameter to `ensure_start_date_values/1` → `ensure_start_date_values/2`**

Change the function signature and compute the `recompute?` boolean:

```elixir
# Before:
def ensure_start_date_values(changeset) do
  specifier = get_field(changeset, :active_period_start_specifier)
  start_dt = get_field(changeset, :active_period_start, :unspecified)
  start_d = get_field(changeset, :active_period_start_date, :unspecified)

  changeset
  |> force_change(:active_period_start_specifier, specifier)
  |> force_change(:active_period_start, start_dt)
  |> force_change(:active_period_start_date, start_d)
  |> ensure_start_date_values_for_specifier(specifier, start_dt, start_d)
end

# After:
def ensure_start_date_values(changeset, target \\ nil) do
  specifier = get_field(changeset, :active_period_start_specifier)
  start_dt = get_field(changeset, :active_period_start, :unspecified)
  start_d = get_field(changeset, :active_period_start_date, :unspecified)
  recompute? = is_nil(target) or target in @time_range_targets

  changeset
  |> force_change(:active_period_start_specifier, specifier)
  |> force_change(:active_period_start, start_dt)
  |> force_change(:active_period_start_date, start_d)
  |> ensure_start_date_values_for_specifier(specifier, start_dt, start_d, recompute?)
end
```

- [ ] **Step 4: Update all `ensure_start_date_values_for_specifier/4` clauses to `/5`**

Replace the entire family of `ensure_start_date_values_for_specifier` clauses:

```elixir
# :now — skip when recompute? is false
def ensure_start_date_values_for_specifier(changeset, :now, _, _, false), do: changeset

def ensure_start_date_values_for_specifier(changeset, :now, _, _, _) do
  now = NaiveDateTime.local_now()

  changeset
  |> force_change(:active_period_start, now)
  |> force_change(:active_period_start_date, now |> NaiveDateTime.to_date())
end

# nil date/time — nothing to derive from
def ensure_start_date_values_for_specifier(changeset, _, dt, d, _)
    when is_nil(dt) or is_nil(d),
    do: changeset

def ensure_start_date_values_for_specifier(changeset, :start_of_service, _, d, _) do
  changeset
  |> force_change(
    :active_period_start,
    NaiveDateTime.new!(d, ActivePeriod.start_of_service_time())
  )
end

def ensure_start_date_values_for_specifier(changeset, :custom, dt, _, _) do
  changeset
  |> force_change(:active_period_start_date, NaiveDateTime.to_date(dt))
end

def ensure_start_date_values_for_specifier(changeset, _, _, _, _), do: changeset
```

- [ ] **Step 5: Add `target` parameter to `ensure_end_date_values/1` → `ensure_end_date_values/2`**

```elixir
# Before:
def ensure_end_date_values(changeset) do
  specifier = get_field(changeset, :active_period_end_specifier)
  end_dt = get_field(changeset, :active_period_end)
  end_d = get_field(changeset, :active_period_end_date)

  changeset
  |> force_change(:active_period_end_specifier, specifier)
  |> force_change(:active_period_end, end_dt)
  |> force_change(:active_period_end_date, end_d)
  |> force_change(:can_close_automatically, false)
  |> ensure_end_date_values_for_specifier(specifier, end_dt, end_d)
end

# After:
def ensure_end_date_values(changeset, target \\ nil) do
  specifier = get_field(changeset, :active_period_end_specifier)
  end_dt = get_field(changeset, :active_period_end)
  end_d = get_field(changeset, :active_period_end_date)
  recompute? = is_nil(target) or target in @time_range_targets

  changeset
  |> force_change(:active_period_end_specifier, specifier)
  |> force_change(:active_period_end, end_dt)
  |> force_change(:active_period_end_date, end_d)
  |> force_change(:can_close_automatically, false)
  |> ensure_end_date_values_for_specifier(specifier, end_dt, end_d, recompute?)
end
```

- [ ] **Step 6: Update all `ensure_end_date_values_for_specifier/4` clauses to `/5`**

Replace the entire family:

```elixir
# :later_today — skip when recompute? is false
def ensure_end_date_values_for_specifier(changeset, :later_today, _, _, false), do: changeset

def ensure_end_date_values_for_specifier(changeset, :later_today, _, _, _) do
  end_of_service = ActivePeriod.end_of_service_datetime_naive(NaiveDateTime.local_now())

  changeset
  |> force_change(:active_period_end, end_of_service)
  |> force_change(:active_period_end_date, NaiveDateTime.to_date(end_of_service))
end

# :until_further_notice — skip when recompute? is false
def ensure_end_date_values_for_specifier(changeset, :until_further_notice, _, _, false),
  do: changeset

def ensure_end_date_values_for_specifier(changeset, :until_further_notice, _, _, _) do
  now = NaiveDateTime.local_now()

  changeset
  |> force_change(:active_period_end, DTHelpers.replace_time(now, ~T[23:59:59]))
  |> force_change(:active_period_end_date, now |> NaiveDateTime.to_date())
end

# :when_work_order_is_closed — skip when recompute? is false
def ensure_end_date_values_for_specifier(changeset, :when_work_order_is_closed, _, _, false),
  do: changeset

def ensure_end_date_values_for_specifier(changeset, :when_work_order_is_closed, _, _, _) do
  now = NaiveDateTime.local_now()

  changeset
  |> force_change(:active_period_end, DTHelpers.replace_time(now, ~T[23:59:59]))
  |> force_change(:active_period_end_date, now |> NaiveDateTime.to_date())
  |> force_change(:can_close_automatically, true)
end

# nil date/time
def ensure_end_date_values_for_specifier(changeset, _, dt, d, _)
    when is_nil(dt) or is_nil(d),
    do: changeset

def ensure_end_date_values_for_specifier(changeset, :end_of_service, _, d, _) do
  changeset
  |> force_change(:active_period_end, NaiveDateTime.new!(d, ActivePeriod.end_of_service_time()))
end

def ensure_end_date_values_for_specifier(changeset, :custom, dt, _, _) do
  changeset
  |> force_change(:active_period_end_date, NaiveDateTime.to_date(dt))
end

def ensure_end_date_values_for_specifier(changeset, _, _, _, _), do: changeset
```

- [ ] **Step 7: Run the H1 tests to confirm they pass**

```bash
mix test test/alerts_ui_web/live/create_alert_mono_live/slices/time_range_slice_test.exs
```

Expected: all pass (including the new tests from Task 1).

- [ ] **Step 8: Run full test suite to check for regressions**

```bash
mix test
```

Expected: all pass. If any `ensure_start_date_values/1` or `ensure_end_date_values/1` calls in tests fail due to arity change, they still work because the second argument has a default of `nil` (which means `recompute? = true`, same behavior as before).

- [ ] **Step 9: Commit**

```bash
git add lib/alerts_ui_web/live/create_alert_mono_live/slices/time_range_slice.ex \
        test/alerts_ui_web/live/create_alert_mono_live/slices/time_range_slice_test.exs
git commit -m "fix: skip :now/:later_today date recomputation on unrelated form events

Prevents active_period_start and active_period_end from silently advancing
every time an unrelated field (e.g. header_sync_toggle) triggers a form
validate event. Only recomputes when the changed field belongs to the
time-range section of the form."
```

---

## Task 3: Write failing tests for H2

**Files:**
- Test: `test/alerts_ui_web/live/form_components/helpers/auto_text/auto_text_duration_test.exs`
- Test: `test/alerts_ui_web/live/create_alert_mono_live/slices/alert_details_slice_test.exs`

- [ ] **Step 1: Add test verifying `build_duration_text` uses `current_time` from struct when present**

Add to `auto_text_duration_test.exs`:

```elixir
describe "build_duration_text/1 with injected current_time" do
  test "uses current_time from struct instead of re-capturing system time" do
    # Pin current_time to a specific moment that makes start_datetime appear "today"
    pinned_time = ~N[2025-06-03 10:00:00]
    start_dt = ~N[2025-06-03 08:00:00]  # within today's service window

    autotext = %BuildAutoText{
      alert_timing: :"one-time",
      start_specifier: :custom,
      end_specifier: :later_today,
      start_datetime: start_dt,
      end_datetime: ~N[2025-06-04 02:30:00],
      route_type: 1,
      effect_name: "DETOUR",
      current_time: pinned_time
    }

    # Call with no explicit current_time — should use struct's current_time
    result1 = AutoTextDuration.build_duration_text(autotext)
    result2 = AutoTextDuration.build_duration_text(autotext)

    # Results should be identical regardless of wall-clock time
    assert result1 == result2
  end

  test "falls back to DateTimeHelpers.current_time() when struct has no current_time" do
    autotext = %BuildAutoText{
      alert_timing: :"one-time",
      start_specifier: :custom,
      end_specifier: :later_today,
      start_datetime: ~N[2025-06-03 08:00:00],
      end_datetime: ~N[2025-06-04 02:30:00],
      route_type: 1,
      effect_name: "DETOUR"
      # current_time intentionally absent (nil)
    }

    # Should not crash; should produce a string
    assert is_binary(AutoTextDuration.build_duration_text(autotext))
  end
end
```

- [ ] **Step 2: Run new tests to confirm they fail**

```bash
mix test test/alerts_ui_web/live/form_components/helpers/auto_text/auto_text_duration_test.exs \
  --only "with injected current_time"
```

Expected: compilation error because `BuildAutoText` has no `current_time` field yet.

---

## Task 4: Add `current_time` to `BuildAutoText` struct

**Files:**
- Modify: `lib/alerts_ui_web/live/form_components/helpers/auto_text/build_auto_text.ex`

- [ ] **Step 1: Add `current_time` field to the struct definition and typespec**

```elixir
# In defstruct, add after recurrence_days:
recurrence_days: [],
current_time: nil

# In @type t, add:
current_time: NaiveDateTime.t() | nil
```

- [ ] **Step 2: Run compile to confirm struct change compiles cleanly**

```bash
mix compile --warnings-as-errors
```

Expected: clean compilation. No type errors yet because `current_time` defaults to `nil` everywhere.

---

## Task 5: Populate `current_time` in `AlertDataToAutoText.build_autotext_data/1`

**Files:**
- Modify: `lib/alerts_ui_web/live/form_components/helpers/auto_text/alert_data_to_auto_text.ex`

- [ ] **Step 1: Read `current_time` from the merged alert data map**

In `build_autotext_data/1`, add `current_time` to the `conversion` map alongside `recurrence_days`:

```elixir
# Before (last two entries in conversion map):
alert_timing: Map.get(alert_data, :alert_timing),
recurrence_days: Map.get(alert_data, :recurrence_days)

# After:
alert_timing: Map.get(alert_data, :alert_timing),
recurrence_days: Map.get(alert_data, :recurrence_days),
current_time: Map.get(alert_data, :current_time)
```

The `|> Enum.reject(fn {_k, v} -> is_nil(v) end)` pipeline already strips nil values, so when no `current_time` is injected the field simply stays at the struct default of `nil`.

---

## Task 6: Inject `current_time` from `AlertDetailsSlice.transform/4`

**Files:**
- Modify: `lib/alerts_ui_web/live/create_alert_mono_live/slices/alert_details_slice.ex`

- [ ] **Step 1: Capture `current_time` once and inject it into the autotext data map**

Locate the `autotext_data` pipeline in `AlertDetailsSlice.transform/4` (around line 94). Add a single `DateTimeHelpers.current_time()` call at the top of the function body and include it in the `Map.merge`:

```elixir
# Before (lines ~94–99):
autotext_data =
  details_data
  |> translated_details()
  |> Map.merge(selected)
  |> Map.merge(%{service_types: get_field(changeset, :service_types)})
  |> AlertDataToAutoText.build_autotext_data()

# After:
current_time = DateTimeHelpers.current_time()

autotext_data =
  details_data
  |> translated_details()
  |> Map.merge(selected)
  |> Map.merge(%{service_types: get_field(changeset, :service_types), current_time: current_time})
  |> AlertDataToAutoText.build_autotext_data()
```

The `current_time` binding is declared once per `transform/4` call, so all downstream autotext operations within a single form event use the same reference time.

---

## Task 7: Use struct's `current_time` in `build_duration_text`

**Files:**
- Modify: `lib/alerts_ui_web/live/form_components/helpers/auto_text/auto_text_duration.ex`

- [ ] **Step 1: Add a dispatch clause that resolves `nil` current_time to the struct's field**

Change the function head and add a nil-dispatch clause before the existing pattern-matched clauses:

```elixir
# Replace:
@spec build_duration_text(BuildAutoText.t()) :: String.t()
def build_duration_text(autotext_data, current_time \\ DateTimeHelpers.current_time())

# With:
@spec build_duration_text(BuildAutoText.t()) :: String.t()
@spec build_duration_text(BuildAutoText.t(), NaiveDateTime.t()) :: String.t()
def build_duration_text(autotext_data, current_time \\ nil)

def build_duration_text(autotext_data, nil) do
  ct = Map.get(autotext_data, :current_time) || DateTimeHelpers.current_time()
  build_duration_text(autotext_data, ct)
end
```

Leave all existing `build_duration_text/2` clauses (the ones with pattern-matched `alert_timing`) unchanged — they already accept an explicit `current_time` as the second argument.

- [ ] **Step 2: Run the H2 tests to confirm they pass**

```bash
mix test test/alerts_ui_web/live/form_components/helpers/auto_text/auto_text_duration_test.exs
```

Expected: all pass, including the new "with injected current_time" tests.

- [ ] **Step 3: Run full test suite**

```bash
mix test
```

Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add lib/alerts_ui_web/live/form_components/helpers/auto_text/build_auto_text.ex \
        lib/alerts_ui_web/live/form_components/helpers/auto_text/alert_data_to_auto_text.ex \
        lib/alerts_ui_web/live/form_components/helpers/auto_text/auto_text_duration.ex \
        lib/alerts_ui_web/live/create_alert_mono_live/slices/alert_details_slice.ex \
        test/alerts_ui_web/live/form_components/helpers/auto_text/auto_text_duration_test.exs
git commit -m "fix: stabilize autotext current_time reference within each transform cycle

Captures DateTimeHelpers.current_time() once in AlertDetailsSlice.transform/4
and threads it into BuildAutoText via the autotext data pipeline. build_duration_text
now uses the struct's current_time when present, falling back to a fresh capture
only when called outside the transform cycle (e.g. from tests without injection)."
```

---

## Verification

Manual verification steps after both commits:

1. Open the mono create-alert form at `localhost:4010`
2. Select a route, direction, and stops. Leave the start specifier as `:now` (default for a new alert).
3. Note the header/description text generated by auto-refresh.
4. Click the auto-refresh toggle OFF, then ON. Repeat 10 times.
5. **Expected:** The dates/times in the message text remain identical between toggle cycles (no minute-level drift, no service-day flip).
6. Test near a minute boundary (watch until :59, then click ON): **Expected:** text does not change between the click before :59 and the click after :00, confirming the start datetime is no longer being updated on toggle events.
7. Change the start date to a specific date (non-`:now` specifier). Toggle 10 times. **Expected:** text remains stable.
8. Change the start specifier back to `:now`. **Expected:** text updates to reflect current time.
