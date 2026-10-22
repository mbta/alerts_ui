defmodule AlertsUIWeb.CreateAlertLive.Helpers.TimeRangeValidatorsTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AlertsUIWeb.CreateAlertLive.AlertData
  alias AlertsUIWeb.CreateAlertLive.Helpers.TimeRangeValidators

  @naive_now DateTime.now!("America/New_York") |> DateTime.to_naive()

  # All validators read via Ecto.Changeset.get_field and validate_change, which
  # read from changes (then data). Building the changeset via change/2 puts
  # every test attribute into changes, so validate_change sees them.
  defp changeset(attrs) do
    Ecto.Changeset.change(%AlertData{}, attrs)
  end

  # A NaiveDateTime far enough in the future that "is_after_now" passes
  # regardless of when the test runs.
  defp future_naive(offset_days \\ 365) do
    DateTime.now!("America/New_York")
    |> DateTime.to_naive()
    |> NaiveDateTime.add(offset_days, :day)
  end

  defp future_date do
    future_naive() |> NaiveDateTime.to_date()
  end

  describe "validate_required_fields/1 for one-time alerts" do
    test "requires active_period_start when start specifier is :custom" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_start_specifier: :custom,
          active_period_end_specifier: :later_today
        })
        |> TimeRangeValidators.validate_required_fields()

      assert cs.errors[:active_period_start] ==
               {"Enter a valid time range start", [validation: :required]}
    end

    test "requires active_period_start_date when start specifier is :start_of_service" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_start_specifier: :start_of_service,
          active_period_end_specifier: :later_today
        })
        |> TimeRangeValidators.validate_required_fields()

      assert cs.errors[:active_period_start_date] ==
               {"Enter a valid time range start", [validation: :required]}
    end

    test "requires active_period_end when end specifier is :custom" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_start_specifier: :now,
          active_period_end_specifier: :custom
        })
        |> TimeRangeValidators.validate_required_fields()

      assert cs.errors[:active_period_end] ==
               {"Enter a valid time range end", [validation: :required]}
    end

    test "requires active_period_end_date when end specifier is :end_of_service" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_start_specifier: :now,
          active_period_end_specifier: :end_of_service
        })
        |> TimeRangeValidators.validate_required_fields()

      assert cs.errors[:active_period_end_date] ==
               {"Enter a valid time range end", [validation: :required]}
    end

    test "passes when one-time start and end are populated according to their specifiers" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_start_specifier: :custom,
          active_period_start: ~N[2099-01-01 09:00:00],
          active_period_end_specifier: :custom,
          active_period_end: ~N[2099-01-01 11:00:00]
        })
        |> TimeRangeValidators.validate_required_fields()

      assert cs.errors == []
    end
  end

  describe "validate_required_fields/1 for recurring alerts" do
    test "requires active_period_start_time when start_time_specifier is :custom" do
      cs =
        changeset(%{
          alert_timing: :recurring,
          active_period_start_time_specifier: :custom,
          active_period_end_time_specifier: :end_of_service,
          active_period_end_specifier: :until_further_notice,
          active_period_start_date: ~D[2099-01-01]
        })
        |> TimeRangeValidators.validate_required_fields()

      assert cs.errors[:active_period_start_time] ==
               {"Enter a valid time range start", [validation: :required]}
    end

    test "requires active_period_end_time when end_time_specifier is :custom" do
      cs =
        changeset(%{
          alert_timing: :recurring,
          active_period_start_time_specifier: :start_of_service,
          active_period_end_time_specifier: :custom,
          active_period_end_specifier: :until_further_notice,
          active_period_start_date: ~D[2099-01-01]
        })
        |> TimeRangeValidators.validate_required_fields()

      assert cs.errors[:active_period_end_time] ==
               {"Enter a valid time range end", [validation: :required]}
    end

    test "always requires active_period_start_date for recurring alerts" do
      cs =
        changeset(%{
          alert_timing: :recurring,
          active_period_start_time_specifier: :start_of_service,
          active_period_end_time_specifier: :end_of_service,
          active_period_end_specifier: :until_further_notice
        })
        |> TimeRangeValidators.validate_required_fields()

      assert cs.errors[:active_period_start_date] ==
               {"Enter a valid start date", [validation: :required]}
    end

    test "requires active_period_end_date only when end specifier is :custom" do
      cs_custom =
        changeset(%{
          alert_timing: :recurring,
          active_period_start_time_specifier: :start_of_service,
          active_period_end_time_specifier: :end_of_service,
          active_period_end_specifier: :custom,
          active_period_start_date: ~D[2099-01-01]
        })
        |> TimeRangeValidators.validate_required_fields()

      assert cs_custom.errors[:active_period_end_date] ==
               {"Enter a valid end date", [validation: :required]}

      cs_until =
        changeset(%{
          alert_timing: :recurring,
          active_period_start_time_specifier: :start_of_service,
          active_period_end_time_specifier: :end_of_service,
          active_period_end_specifier: :until_further_notice,
          active_period_start_date: ~D[2099-01-01]
        })
        |> TimeRangeValidators.validate_required_fields()

      assert cs_until.errors[:active_period_end_date] == nil
    end
  end

  describe "validate_end_after_start/1 for one-time alerts" do
    test "errors on :active_period_end_specifier when end <= start with :later_today" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_start: ~N[2099-01-01 09:00:00],
          active_period_end: ~N[2099-01-01 08:00:00],
          active_period_end_specifier: :later_today
        })
        |> TimeRangeValidators.validate_end_after_start()

      assert {msg, []} = cs.errors[:active_period_end_specifier]
      assert msg =~ "Effect must end after"
    end

    test "errors on :active_period_end_date when end <= start with :end_of_service" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_start: ~N[2099-01-01 09:00:00],
          active_period_end: ~N[2099-01-01 09:00:00],
          active_period_end_specifier: :end_of_service
        })
        |> TimeRangeValidators.validate_end_after_start()

      assert {msg, []} = cs.errors[:active_period_end_date]
      assert msg =~ "Effect must end after"
    end

    test "errors on :active_period_end for other end specifiers" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_start: ~N[2099-01-01 09:00:00],
          active_period_end: ~N[2099-01-01 08:00:00],
          active_period_end_specifier: :custom
        })
        |> TimeRangeValidators.validate_end_after_start()

      assert {msg, []} = cs.errors[:active_period_end]
      assert msg =~ "Effect must end after"
    end

    test "passes when end is strictly after start" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_start: ~N[2099-01-01 09:00:00],
          active_period_end: ~N[2099-01-01 10:00:00],
          active_period_end_specifier: :custom
        })
        |> TimeRangeValidators.validate_end_after_start()

      assert cs.errors == []
    end

    test "is a no-op when active_period_start is nil" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_end: ~N[2099-01-01 09:00:00],
          active_period_end_specifier: :custom
        })
        |> TimeRangeValidators.validate_end_after_start()

      assert cs.errors == []
    end
  end

  describe "validate_end_after_start/1 for recurring alerts" do
    test "errors on :active_period_end_date when end < start (date+time pair)" do
      cs =
        changeset(%{
          alert_timing: :recurring,
          active_period_start_date: ~D[2099-01-02],
          active_period_start_time: ~T[09:00:00],
          active_period_end_date: ~D[2099-01-01],
          active_period_end_time: ~T[09:00:00]
        })
        |> TimeRangeValidators.validate_end_after_start()

      assert {msg, []} = cs.errors[:active_period_end_date]
      assert msg =~ "Effect must end after"
    end

    test "passes when end >= start" do
      cs =
        changeset(%{
          alert_timing: :recurring,
          active_period_start_date: ~D[2099-01-01],
          active_period_start_time: ~T[09:00:00],
          active_period_end_date: ~D[2099-01-05],
          active_period_end_time: ~T[09:00:00]
        })
        |> TimeRangeValidators.validate_end_after_start()

      assert cs.errors == []
    end
  end

  describe "validate_start_is_after_now/1" do
    test "is a no-op when editing" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_start_specifier: :custom,
          active_period_start: ~N[2020-01-01 09:00:00]
        })
        |> TimeRangeValidators.validate_start_is_after_now(@naive_now, :editing)

      assert cs.errors == []
    end

    test "errors on :active_period_start for a one-time :custom start in the past" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_start_specifier: :custom,
          active_period_start: ~N[2020-01-01 09:00:00]
        })
        |> TimeRangeValidators.validate_start_is_after_now(@naive_now, :new)

      assert cs.errors[:active_period_start] ==
               {"Effect can't start in the past", []}
    end

    test "errors on :active_period_start_date for one-time :start_of_service in the past" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_start_specifier: :start_of_service,
          active_period_start_date: ~D[2020-01-01]
        })
        |> TimeRangeValidators.validate_start_is_after_now(@naive_now, :new)

      assert cs.errors[:active_period_start_date] ==
               {"Effect can't start in the past", []}
    end

    test "errors on :active_period_start_specifier for recurring :now start in the past" do
      cs =
        changeset(%{
          alert_timing: :recurring,
          active_period_start_specifier: :now,
          active_period_start_date: ~D[2020-01-01],
          active_period_start_time: ~T[09:00:00]
        })
        |> TimeRangeValidators.validate_start_is_after_now(@naive_now, :new)

      assert cs.errors[:active_period_start_specifier] ==
               {"Effect can't start in the past", []}
    end

    test "errors on :active_period_start_date for recurring :custom start in the past" do
      cs =
        changeset(%{
          alert_timing: :recurring,
          active_period_start_specifier: :custom,
          active_period_start_date: ~D[2020-01-01],
          active_period_start_time: ~T[09:00:00]
        })
        |> TimeRangeValidators.validate_start_is_after_now(@naive_now, :new)

      assert cs.errors[:active_period_start_date] ==
               {"Effect can't start in the past", []}
    end

    test "passes for a one-time :custom start in the future" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_start_specifier: :custom,
          active_period_start: future_naive()
        })
        |> TimeRangeValidators.validate_start_is_after_now(@naive_now, :new)

      assert cs.errors == []
    end

    test "is a no-op for recurring when start_date or start_time is nil" do
      cs =
        changeset(%{
          alert_timing: :recurring,
          active_period_start_specifier: :now,
          active_period_start_date: ~D[2020-01-01]
        })
        |> TimeRangeValidators.validate_start_is_after_now(@naive_now, :new)

      assert cs.errors == []
    end
  end

  describe "validate_at_least_one_recurrence/1" do
    test "errors when recurrence_days is empty and alert is recurring" do
      cs =
        changeset(%{alert_timing: :recurring, recurrence_days: []})
        |> TimeRangeValidators.validate_at_least_one_recurrence()

      assert cs.errors[:recurrence_days] ==
               {"Select one or more days for alert to recur", []}
    end

    test "passes when recurrence_days has at least one entry" do
      cs =
        changeset(%{alert_timing: :recurring, recurrence_days: [:monday]})
        |> TimeRangeValidators.validate_at_least_one_recurrence()

      assert cs.errors == []
    end

    test "is a no-op for one-time alerts even with empty recurrence_days" do
      cs =
        changeset(%{alert_timing: :"one-time", recurrence_days: []})
        |> TimeRangeValidators.validate_at_least_one_recurrence()

      assert cs.errors == []
    end
  end

  describe "validate_start_date_matches_weekday/1" do
    test "errors when the start_date weekday isn't in recurrence_days (:now)" do
      # 2099-01-05 is a Monday.
      cs =
        changeset(%{
          alert_timing: :recurring,
          active_period_start_specifier: :now,
          active_period_start_date: ~D[2099-01-05],
          recurrence_days: [:tuesday]
        })
        |> TimeRangeValidators.validate_start_date_matches_weekday()

      assert cs.errors[:active_period_start_date] ==
               {"Alert start day must match a selected day of the week.", []}
    end

    test "errors with :custom specifier when start_date weekday isn't in recurrence_days" do
      cs =
        changeset(%{
          alert_timing: :recurring,
          active_period_start_specifier: :custom,
          active_period_start_date: ~D[2099-01-05],
          recurrence_days: [:wednesday]
        })
        |> TimeRangeValidators.validate_start_date_matches_weekday()

      assert cs.errors[:active_period_start_date] ==
               {"Alert start day must match a selected day of the week.", []}
    end

    test "passes when the start_date weekday matches one of the recurrence_days" do
      # 2099-01-05 is a Monday.
      cs =
        changeset(%{
          alert_timing: :recurring,
          active_period_start_specifier: :now,
          active_period_start_date: ~D[2099-01-05],
          recurrence_days: [:monday, :wednesday]
        })
        |> TimeRangeValidators.validate_start_date_matches_weekday()

      assert cs.errors == []
    end

    test "passes when recurrence_days is empty (the at-least-one validator handles that)" do
      cs =
        changeset(%{
          alert_timing: :recurring,
          active_period_start_specifier: :now,
          active_period_start_date: ~D[2099-01-05],
          recurrence_days: []
        })
        |> TimeRangeValidators.validate_start_date_matches_weekday()

      assert cs.errors == []
    end

    test "is a no-op for one-time alerts" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_start_specifier: :custom,
          active_period_start_date: ~D[2099-01-05],
          recurrence_days: [:tuesday]
        })
        |> TimeRangeValidators.validate_start_date_matches_weekday()

      assert cs.errors == []
    end
  end

  describe "validate_not_dst_gap/1" do
    test "errors when active_period_start lands in the EST→EDT gap" do
      # On 2024-03-10, 02:30 EST does not exist (clocks spring forward 2→3 AM).
      cs =
        changeset(%{
          active_period_start: ~N[2024-03-10 02:30:00],
          active_period_end: ~N[2024-03-10 10:00:00]
        })
        |> TimeRangeValidators.validate_not_dst_gap()

      assert {msg, []} = cs.errors[:active_period_start]
      assert msg =~ "skipped daylight savings"
    end

    test "errors when active_period_end lands in the EST→EDT gap" do
      cs =
        changeset(%{
          active_period_start: ~N[2024-03-09 10:00:00],
          active_period_end: ~N[2024-03-10 02:30:00]
        })
        |> TimeRangeValidators.validate_not_dst_gap()

      assert {msg, []} = cs.errors[:active_period_end]
      assert msg =~ "skipped daylight savings"
    end

    test "passes for timestamps outside any DST gap" do
      cs =
        changeset(%{
          active_period_start: ~N[2024-06-01 09:00:00],
          active_period_end: ~N[2024-06-01 11:00:00]
        })
        |> TimeRangeValidators.validate_not_dst_gap()

      assert cs.errors == []
    end
  end

  describe "validate_start_is_before_trip/2" do
    test "is a no-op when trip_arrival_time is nil" do
      cs =
        changeset(%{active_period_start: ~N[2099-01-01 09:00:00]})
        |> TimeRangeValidators.validate_start_is_before_trip(nil)

      assert cs.errors == []
    end

    test "adds errors on start and start_date when start is more than 60 min after trip" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_start: ~N[2099-01-01 12:00:00]
        })
        |> TimeRangeValidators.validate_start_is_before_trip(~N[2099-01-01 10:00:00])

      assert {start_msg, []} = cs.errors[:active_period_start]
      assert start_msg =~ "Effect must start before"

      assert {date_msg, []} = cs.errors[:active_period_start_date]
      assert date_msg =~ "Effect must start before"
    end

    test "is a no-op for recurring alerts" do
      cs =
        changeset(%{
          alert_timing: :recurring,
          active_period_start: ~N[2099-01-01 12:00:00]
        })
        |> TimeRangeValidators.validate_start_is_before_trip(~N[2099-01-01 10:00:00])

      assert cs.errors == []
    end

    test "passes when start is within an hour after trip arrival" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          active_period_start: ~N[2099-01-01 10:30:00]
        })
        |> TimeRangeValidators.validate_start_is_before_trip(~N[2099-01-01 10:00:00])

      assert cs.errors == []
    end
  end

  describe "validate_notification_time/3" do
    # Build a changeset whose `data` holds the originally-saved notification start
    # while `changes` holds the (force-changed) current value — mirrors how the
    # form's transform always force_changes notification_period_start.
    defp editing_changeset(original, current, attrs) do
      %AlertData{notification_period_start: original}
      |> Ecto.Changeset.change(attrs)
      |> Ecto.Changeset.force_change(:notification_period_start, current)
    end

    test "errors when notification_period_start is in the past (req 1)" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          notification_specifier: :custom,
          active_period_start: future_naive(),
          notification_period_start: ~N[2020-01-01 09:00:00]
        })
        |> TimeRangeValidators.validate_notification_time(@naive_now, :new)

      assert {msg1, []} = cs.errors[:notification_period_start]
      assert msg1 =~ "in the past"

      assert {msg2, []} = cs.errors[:notification_period_start_date]
      assert msg2 =~ "in the past"
    end

    test "passes when start is after actual now but before a future effect start (req 1)" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          notification_specifier: :custom,
          active_period_start: future_naive(30),
          notification_period_start: future_naive(10)
        })
        |> TimeRangeValidators.validate_notification_time(@naive_now, :editing)

      assert cs.errors == []
    end

    test ":same_as_effect_period is never flagged, even with a past effect start" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          notification_specifier: :same_as_effect_period,
          active_period_start: ~N[2020-01-01 09:00:00],
          notification_period_start: ~N[2020-01-01 09:00:00]
        })
        |> TimeRangeValidators.validate_notification_time(@naive_now, :editing)

      assert cs.errors == []
    end

    test "editing: an unchanged saved past value stays valid (req 2)" do
      past = ~N[2020-01-01 09:00:00]

      cs =
        editing_changeset(past, past, %{
          alert_timing: :"one-time",
          notification_specifier: :custom,
          active_period_start: future_naive()
        })
        |> TimeRangeValidators.validate_notification_time(@naive_now, :editing)

      assert cs.errors == []
    end

    test "editing: changing to a different past value errors (req 2)" do
      cs =
        editing_changeset(~N[2020-01-01 09:00:00], ~N[2019-06-01 09:00:00], %{
          alert_timing: :"one-time",
          notification_specifier: :custom,
          active_period_start: future_naive()
        })
        |> TimeRangeValidators.validate_notification_time(@naive_now, :editing)

      assert {msg, []} = cs.errors[:notification_period_start]
      assert msg =~ "in the past"
    end

    test "duplicate: an unchanged carried-over value is not validated" do
      past = ~N[2020-01-01 09:00:00]

      cs =
        editing_changeset(past, past, %{
          alert_timing: :"one-time",
          notification_specifier: :custom,
          active_period_start: future_naive()
        })
        |> TimeRangeValidators.validate_notification_time(@naive_now, :duplicating)

      assert cs.errors == []
    end

    test "duplicate: a changed value is validated against the effect start" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          notification_specifier: :custom,
          active_period_start: future_naive(10),
          notification_period_start: future_naive(20)
        })
        |> TimeRangeValidators.validate_notification_time(@naive_now, :duplicating)

      assert {msg, []} = cs.errors[:notification_period_start]
      assert msg =~ "Notification period must start on or before"
    end

    test "create: errors when after the effect start" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          notification_specifier: :custom,
          active_period_start: future_naive(10),
          notification_period_start: future_naive(20)
        })
        |> TimeRangeValidators.validate_notification_time(@naive_now, :new)

      assert {msg, []} = cs.errors[:notification_period_start]
      assert msg =~ "Notification period must start on or before"
    end

    test "create: passes when on or before the effect start" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          notification_specifier: :custom,
          active_period_start: future_naive(20),
          notification_period_start: future_naive(10)
        })
        |> TimeRangeValidators.validate_notification_time(@naive_now, :new)

      assert cs.errors == []
    end

    test "create: the notification period end does not bound the start" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          notification_specifier: :custom,
          active_period_start: future_naive(20),
          notification_period_end: future_naive(5),
          notification_period_start: future_naive(10)
        })
        |> TimeRangeValidators.validate_notification_time(@naive_now, :new)

      assert cs.errors == []
    end

    test "editing: errors when after the notification period end" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          notification_specifier: :custom,
          notification_period_end: future_naive(10),
          notification_period_start: future_naive(20)
        })
        |> TimeRangeValidators.validate_notification_time(@naive_now, :editing)

      assert {msg, []} = cs.errors[:notification_period_start]
      assert msg =~ "Notification period must start on or before"
    end

    test "editing: passes when on or before the notification period end" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          notification_specifier: :custom,
          notification_period_end: future_naive(20),
          notification_period_start: future_naive(10)
        })
        |> TimeRangeValidators.validate_notification_time(@naive_now, :editing)

      assert cs.errors == []
    end

    test "editing: the effect start does not bound the start" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          notification_specifier: :custom,
          active_period_start: future_naive(10),
          notification_period_end: future_naive(30),
          notification_period_start: future_naive(20)
        })
        |> TimeRangeValidators.validate_notification_time(@naive_now, :editing)

      assert cs.errors == []
    end

    test "editing: has no upper bound when the notification period has no end" do
      cs =
        changeset(%{
          alert_timing: :"one-time",
          notification_specifier: :custom,
          notification_period_end: nil,
          notification_period_start: future_naive(365)
        })
        |> TimeRangeValidators.validate_notification_time(@naive_now, :editing)

      assert cs.errors == []
    end

    test "errors for recurring alerts with a past notification start (req 1)" do
      cs =
        changeset(%{
          alert_timing: :recurring,
          notification_specifier: :custom,
          active_period_start_date: future_date(),
          active_period_start_time: ~T[09:00:00],
          notification_period_start: ~N[2020-01-01 09:00:00]
        })
        |> TimeRangeValidators.validate_notification_time(@naive_now, :new)

      assert {msg, []} = cs.errors[:notification_period_start]
      assert msg =~ "in the past"
    end
  end

  describe "validate_required_notification_fields/1" do
    test "requires nothing for :same_as_effect_period" do
      cs =
        changeset(%{notification_specifier: :same_as_effect_period})
        |> TimeRangeValidators.validate_required_notification_fields()

      assert cs.errors == []
    end

    test "requires :notification_period_start_date for :start_of_service" do
      cs =
        changeset(%{notification_specifier: :start_of_service})
        |> TimeRangeValidators.validate_required_notification_fields()

      assert cs.errors[:notification_period_start_date] ==
               {"Enter a valid date and/or time", [validation: :required]}
    end

    test "requires :notification_period_start for :now" do
      cs =
        changeset(%{notification_specifier: :now})
        |> TimeRangeValidators.validate_required_notification_fields()

      assert cs.errors[:notification_period_start] ==
               {"Enter a valid date and/or time", [validation: :required]}
    end

    test "requires :notification_period_start for :custom" do
      cs =
        changeset(%{notification_specifier: :custom})
        |> TimeRangeValidators.validate_required_notification_fields()

      assert cs.errors[:notification_period_start] ==
               {"Enter a valid date and/or time", [validation: :required]}
    end
  end
end
