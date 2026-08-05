defmodule AlertsUI.AlertsTest do
  @moduledoc false
  use AlertsUI.DataCase, async: false
  import AlertsUI.Support.Factory
  import AlertsUI.UsersFixtures
  alias AlertsUI.Alerts
  alias AlertsUI.Models.{ActivePeriod, Alert, Effect}
  @now DateTime.utc_now()
  @five_minutes_ago @now
                    |> DateTime.add(-5, :minute)
                    |> DateTime.truncate(:second)

  @one_day_ago DateTime.add(@now, -1, :day)
  @six_hours_ago DateTime.add(@now, -6, :hour)
  @two_hours_ago DateTime.add(@now, -2, :hour)
  @one_hour_ago DateTime.add(@now, -1, :hour)
  @one_hour_from_now DateTime.add(@now, 1, :hour)
  @two_hours_from_now DateTime.add(@now, 2, :hour)
  @end_of_service_utc ActivePeriod.end_of_service_datetime_utc(@now)
  @one_day_from_now DateTime.add(@now, 1, :day)
  @two_days_from_now DateTime.add(@now, 2, :day)

  @user build(:user)

  describe "create_or_update_alert" do
    test "creates alert from params" do
      user = create_db_user()

      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          description_text: ""
        })

      {:ok, new_alert} =
        Alerts.create_or_update_alert(new_params, user)

      assert new_alert.alert_id == "123"
      assert new_alert.header_text == "new header text"
      assert new_alert.description_text == ""
      assert new_alert.user_id == user.id
      refute new_alert.created_at == nil
      refute new_alert.updated_at == nil
    end

    test "edits alert if it exists" do
      existing_alert =
        insert(
          :alert,
          %{
            alert_id: "123",
            header_text: "old header text",
            active_period: [
              build(:active_period),
              %{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:01:00Z]}
            ],
            user: @user
          }
        )

      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          active_period: [%{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:03:00Z]}],
          user: Map.from_struct(existing_alert.user)
        })

      Alerts.create_or_update_alert(new_params, build(:user), existing_alert)
      updated_alert = Alerts.get_by_id(existing_alert.id)
      assert updated_alert.alert_id == "123"
      assert updated_alert.header_text == "new header text"
      assert (updated_alert.active_period |> hd).end == ~U[2023-10-13 00:03:00Z]
    end

    test "updates updated_at when updating an existing alert" do
      existing_alert =
        insert(
          :alert,
          %{
            alert_id: "123",
            header_text: "old header text",
            updated_at: @five_minutes_ago,
            user: @user
          }
        )

      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          user: Map.from_struct(existing_alert.user)
        })

      Alerts.create_or_update_alert(new_params, build(:user), existing_alert)
      updated_alert = Repo.get_by(Alert, id: existing_alert.id)

      assert DateTime.compare(updated_alert.updated_at, @five_minutes_ago) == :gt
    end

    test "does not change created_at when updating an existing alert" do
      existing_alert =
        insert(
          :alert,
          %{
            alert_id: "123",
            header_text: "old header text",
            created_at: @five_minutes_ago,
            user: @user
          }
        )

      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          user: Map.from_struct(existing_alert.user)
        })

      Alerts.create_or_update_alert(new_params, build(:user), existing_alert)
      updated_alert = Repo.get_by(Alert, id: existing_alert.id)

      assert updated_alert.created_at == @five_minutes_ago
    end

    test "returns the resulting alert model" do
      existing_alert =
        insert(
          :alert,
          %{
            alert_id: "123",
            header_text: "old header text",
            active_period: [
              build(:active_period),
              %{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:01:00Z]}
            ],
            user: @user
          }
        )

      new_params =
        build(:alert_map, %{
          alert_id: "123",
          active_period: [%{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:03:00Z]}],
          user: Map.from_struct(existing_alert.user)
        })

      assert {:ok, updated_alert} =
               Alerts.create_or_update_alert(new_params, build(:user), existing_alert)

      assert updated_alert.alert_id == "123"
      assert (updated_alert.active_period |> hd).end == ~U[2023-10-13 00:03:00Z]
    end

    test "papertrail saves versions" do
      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          description_text: ""
        })

      {:ok, new_alert} =
        Alerts.create_or_update_alert(new_params, build(:user))

      %Alert{alert_id: stored_alert_id} = Repo.get!(Alert, new_alert.id)

      %PaperTrail.Version{item_changes: %{"alert_id" => version_alert_id}} =
        PaperTrail.Version.last()

      assert stored_alert_id == version_alert_id
    end

    test "creates alert with no id uses next in sequence" do
      new_params =
        build(:alert_map, %{
          header_text: "new header text",
          description_text: ""
        })

      {:ok, new_alert} =
        Alerts.create_or_update_alert(new_params, build(:user))

      assert new_alert.alert_id |> String.to_integer() |> is_integer()
      assert new_alert.header_text == "new header text"
      assert new_alert.description_text == ""
    end

    test "error if alert is incomplete" do
      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: nil,
          description_text: nil
        })

      {:error, changeset} = Alerts.create_or_update_alert(new_params, build(:user))
      assert changeset.errors == [header_text: {"is required", [validation: :required]}]
    end
  end

  describe "parse_changeset_errors/1" do
    test "puts changeset errors in readable format" do
      changeset =
        Alert.changeset(%Alert{}, %{header_text: "hello", informed_entity: [], user: @user})

      result = Alerts.parse_changeset_errors(changeset)

      assert result == %{
               informed_entity: ["should have at least 1 item(s)", "can't be blank"],
               active_period_start: ["is required"]
             }
    end
  end

  describe "get_max_alert_id/0" do
    test "returns highest alert_id" do
      insert(:alert, alert_id: "1")
      insert(:alert, alert_id: "2")
      insert(:alert, alert_id: "5")
      insert(:alert, alert_id: "104")

      assert Alerts.get_max_alert_id() == 104
    end
  end

  describe "last_modified_time_more_recent?/1" do
    test "returns true if incoming alert is more recent than stored alert" do
      existing_alert =
        insert(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-13 00:01:00Z]})

      incoming_alert =
        build(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-14 00:01:00Z]})

      assert Alerts.last_modified_time_more_recent?(
               Map.get(incoming_alert, :last_modified_timestamp),
               Map.get(existing_alert, :last_modified_timestamp)
             ) == true
    end

    test "returns true if incoming alert has same time as stored alert" do
      existing_alert =
        insert(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-13 00:01:00Z]})

      incoming_alert =
        build(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-13 00:01:00Z]})

      assert Alerts.last_modified_time_more_recent?(
               Map.get(incoming_alert, :last_modified_timestamp),
               Map.get(existing_alert, :last_modified_timestamp)
             ) == true
    end

    test "returns false if incoming alert is not more recent than stored alert" do
      existing_alert =
        insert(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-14 00:01:00Z]})

      incoming_alert =
        build(:alert_map, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-13 00:01:00Z]})

      assert Alerts.last_modified_time_more_recent?(
               Map.get(incoming_alert, :last_modified_timestamp),
               Map.get(existing_alert, :last_modified_timestamp)
             ) == false
    end

    test "returns false if incoming alert has no timestamp" do
      existing_alert =
        insert(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-14 00:01:00Z]})

      incoming_alert =
        build(:alert_map, %{alert_id: "123"})

      assert Alerts.last_modified_time_more_recent?(
               Map.get(incoming_alert, :last_modified_timestamp),
               Map.get(existing_alert, :last_modified_timestamp)
             ) == false
    end
  end

  describe "update_end_if_estimated/2" do
    test "don't update active_period and active_period_end if duration estimated and start in future" do
      current_time = ~U[2024-12-11 00:08:00Z]

      insert(:alert, %{
        alert_id: "123",
        active_period: [%{start: ~U[2024-12-11 09:00:00Z], end: ~U[2024-12-11 11:00:00Z]}],
        active_period_start: ~U[2024-12-11 09:00:00Z],
        active_period_end: ~U[2024-12-11 11:00:00Z],
        duration_certainty: :ESTIMATED
      })

      [result] = Alerts.list_all_open() |> Alerts.update_end_if_estimated(current_time)

      assert [%{start: ~U[2024-12-11 09:00:00Z], end: ~U[2024-12-11 11:00:00Z]}] =
               result.active_period

      assert result.active_period_end == ~U[2024-12-11 11:00:00Z]
    end

    test "update active_period and active_period_end if duration estimated and start in past" do
      current_time = ~U[2024-12-11 12:00:00Z]

      insert(:alert, %{
        alert_id: "123",
        active_period: [%{start: ~U[2024-12-11 11:00:00Z], end: ~U[2024-12-11 13:00:00Z]}],
        active_period_start: ~U[2024-12-11 11:00:00Z],
        active_period_end: ~U[2024-12-11 13:00:00Z],
        notification_period_end: ~U[2024-12-12 08:00:00Z],
        duration_certainty: :ESTIMATED,
        user: @user
      })

      [result] = Alerts.list_all_open() |> Alerts.update_end_if_estimated(current_time)

      assert [%{start: ~U[2024-12-11 11:00:00Z], end: ~U[2024-12-11 14:00:00Z]}] =
               result.active_period

      assert result.active_period_end == ~U[2024-12-11 14:00:00Z]
    end

    test "update end to notification_period_end if the notification_period_end is less than 2 hours from now" do
      current_time = ~U[2024-12-11 06:30:00Z]

      insert(:alert, %{
        alert_id: "123",
        active_period: [%{start: ~U[2024-12-09 23:00:00Z], end: ~U[2024-12-11 05:00:00Z]}],
        active_period_start: ~U[2024-12-09 23:00:00Z],
        active_period_end: ~U[2024-12-11 01:00:00Z],
        notification_period_end: ~U[2024-12-11 08:00:00Z],
        duration_certainty: :ESTIMATED,
        user: @user
      })

      [result] = Alerts.list_all_open() |> Alerts.update_end_if_estimated(current_time)

      expected_end =
        NaiveDateTime.new!(~D[2024-12-11], ActivePeriod.end_of_service_time())
        |> DateTime.from_naive!("America/New_York")
        |> DateTime.shift_zone!("Etc/UTC")

      assert [%{start: ~U[2024-12-09 23:00:00Z], end: ^expected_end}] = result.active_period
      assert result.active_period_end == expected_end
    end

    test "make no change if duration not estimated" do
      current_time = ~U[2024-12-11 00:08:00Z]

      insert(:alert, %{
        alert_id: "123",
        active_period: [%{start: ~U[2024-12-11 06:00:00Z], end: ~U[2024-12-11 09:00:00Z]}],
        active_period_end: ~U[2024-12-11 09:00:00Z],
        duration_certainty: :KNOWN
      })

      [result] = Alerts.list_all_open() |> Alerts.update_end_if_estimated(current_time)

      assert [%{start: ~U[2024-12-11 06:00:00Z], end: ~U[2024-12-11 09:00:00Z]}] =
               result.active_period

      assert result.active_period_end == ~U[2024-12-11 09:00:00Z]
    end

    test "make no change if multiple active periods" do
      current_time = ~U[2024-12-11 00:08:00Z]

      insert(:alert, %{
        alert_id: "123",
        active_period: [
          %{start: ~U[2024-12-10 06:00:00Z], end: ~U[2024-12-10 09:00:00Z]},
          %{start: ~U[2024-12-11 06:00:00Z], end: ~U[2024-12-11 09:00:00Z]}
        ],
        active_period_end: ~U[2024-12-11 09:00:00Z],
        duration_certainty: :KNOWN
      })

      [result] = Alerts.list_all_open() |> Alerts.update_end_if_estimated(current_time)

      assert result.active_period_end == ~U[2024-12-11 09:00:00Z]
    end
  end

  describe "close_if_end_is_past/2" do
    test "closes if end time is past current time" do
      current_time = ~U[2024-06-05 00:00:00Z]
      insert(:alert, %{alert_id: "123", active_period_end: ~U[2024-06-04 00:00:00Z]})
      insert(:alert, %{alert_id: "234", active_period_end: ~U[2024-06-06 00:00:00Z]})
      insert(:alert, %{alert_id: "345"})
      result = Alerts.list_all_open() |> Alerts.close_if_end_is_past(current_time)
      [result1, result2, result3] = result |> Enum.sort_by(& &1.alert_id)
      refute is_nil(result1.closed_timestamp)
      assert result2.closed_timestamp == nil
      assert result3.closed_timestamp == nil
    end
  end

  describe "update_recurring_active_periods/1" do
    test "adds more active periods to end of recurring alert" do
      alert =
        insert(:alert, %{
          alert_id: "123",
          recurrence_days: [:monday, :tuesday, :wednesday, :thursday, :friday],
          recurrence_start_time: ~T[09:00:00],
          recurrence_end_time: ~T[12:00:00],
          active_period: [
            build(:active_period, %{
              start: ~U[2024-10-21 13:00:00Z],
              end: ~U[2024-10-21 16:00:00Z]
            }),
            build(:active_period, %{
              start: ~U[2024-10-22 13:00:00Z],
              end: ~U[2024-10-22 16:00:00Z]
            }),
            build(:active_period, %{
              start: ~U[2024-10-23 13:00:00Z],
              end: ~U[2024-10-23 16:00:00Z]
            })
          ],
          active_period_end: nil
        })

      Alerts.update_recurring_active_periods(alert, ~U[2023-10-24 13:00:00Z])

      [ap_1, ap_2, ap_3, ap_4] = Alerts.get_by_alert_id("123").active_period
      assert [~U[2024-10-21 13:00:00Z], ~U[2024-10-21 16:00:00Z]] = [ap_1.start, ap_1.end]
      assert [~U[2024-10-22 13:00:00Z], ~U[2024-10-22 16:00:00Z]] = [ap_2.start, ap_2.end]
      assert [~U[2024-10-23 13:00:00Z], ~U[2024-10-23 16:00:00Z]] = [ap_3.start, ap_3.end]
      assert [~U[2024-10-24 13:00:00Z], ~U[2024-10-24 16:00:00Z]] = [ap_4.start, ap_4.end]
    end

    test "handles daylight savings time conversions so times stay the same for eastern timezone" do
      alert =
        insert(:alert, %{
          alert_id: "123",
          recurrence_days: [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday],
          recurrence_start_time: ~T[08:00:00],
          recurrence_end_time: ~T[02:30:00],
          active_period: [
            build(:active_period, %{
              start: ~U[2027-03-12 13:00:00Z],
              end: ~U[2027-03-13 07:30:00Z]
            })
          ],
          active_period_end: nil
        })

      Alerts.update_recurring_active_periods(alert, ~U[2026-03-14 13:00:00Z])

      [first_ap, second_ap, last_ap] = Alerts.get_by_alert_id("123").active_period

      # this is the original one, hasn't been modified. I have it here to make it easy to compare to the others
      # dates are in ISO for readability
      assert first_ap.start |> DateTime.shift_zone!("America/New_York") |> DateTime.to_iso8601() ==
               "2027-03-12T08:00:00-05:00"

      assert first_ap.end |> DateTime.shift_zone!("America/New_York") |> DateTime.to_iso8601() ==
               "2027-03-13T02:30:00-05:00"

      # this is the day of daylight savings time. End has been rounded up to the end of the "gap".
      assert second_ap.start |> DateTime.shift_zone!("America/New_York") |> DateTime.to_iso8601() ==
               "2027-03-13T08:00:00-05:00"

      assert second_ap.end |> DateTime.shift_zone!("America/New_York") |> DateTime.to_iso8601() ==
               "2027-03-14T03:00:00-04:00"

      # the time is the same but the timezone has been shifted. still starts at "8am" from the perspective
      # of someone in the eastern time zone.
      assert last_ap.start |> DateTime.shift_zone!("America/New_York") |> DateTime.to_iso8601() ==
               "2027-03-14T08:00:00-04:00"

      assert last_ap.end |> DateTime.shift_zone!("America/New_York") |> DateTime.to_iso8601() ==
               "2027-03-15T02:30:00-04:00"
    end

    test "adds more active periods to end of recurring alert when start and end are different days" do
      alert =
        insert(:alert, %{
          alert_id: "123",
          recurrence_days: [:monday, :tuesday, :wednesday, :thursday, :friday],
          recurrence_start_time: ~T[09:00:00],
          recurrence_end_time: ~T[21:00:00],
          active_period: [
            build(:active_period, %{
              start: ~U[2024-10-22 13:00:00Z],
              end: ~U[2024-10-23 01:00:00Z]
            }),
            build(:active_period, %{
              start: ~U[2024-10-23 13:00:00Z],
              end: ~U[2024-10-24 01:00:00Z]
            })
          ],
          active_period_end: nil
        })

      Alerts.update_recurring_active_periods(alert, ~U[2023-10-24 13:00:00Z])

      [ap_1, ap_2, ap_3] = Alerts.get_by_alert_id("123").active_period
      assert [~U[2024-10-22 13:00:00Z], ~U[2024-10-23 01:00:00Z]] = [ap_1.start, ap_1.end]
      assert [~U[2024-10-23 13:00:00Z], ~U[2024-10-24 01:00:00Z]] = [ap_2.start, ap_2.end]
      assert [~U[2024-10-24 13:00:00Z], ~U[2024-10-25 01:00:00Z]] = [ap_3.start, ap_3.end]
    end

    test "does nothing if active periods are empty" do
      alert =
        insert(:alert, %{
          alert_id: "123",
          recurrence_days: [:monday, :tuesday, :wednesday, :thursday, :friday],
          active_period: [],
          active_period_end: nil
        })

      Alerts.update_recurring_active_periods(alert, ~U[2023-10-24 13:00:00Z])

      [] = Alerts.get_by_alert_id("123").active_period
    end

    test "Does nothing if recurrence days are empty" do
      alert =
        insert(:alert, %{
          alert_id: "123",
          recurrence_days: [],
          active_period: [
            build(:active_period, %{
              start: ~U[2024-10-22 13:00:00Z],
              end: ~U[2024-10-23 01:00:00Z]
            }),
            build(:active_period, %{
              start: ~U[2024-10-23 13:00:00Z],
              end: ~U[2024-10-24 01:00:00Z]
            })
          ],
          active_period_end: nil
        })

      Alerts.update_recurring_active_periods(alert, ~U[2023-10-24 13:00:00Z])

      [ap_1, ap_2] = Alerts.get_by_alert_id("123").active_period
      assert [~U[2024-10-22 13:00:00Z], ~U[2024-10-23 01:00:00Z]] = [ap_1.start, ap_1.end]
      assert [~U[2024-10-23 13:00:00Z], ~U[2024-10-24 01:00:00Z]] = [ap_2.start, ap_2.end]
    end

    test "Does nothing if recurrence days are nil" do
      alert =
        insert(:alert, %{
          alert_id: "123",
          active_period: [
            build(:active_period, %{
              start: ~U[2024-10-22 13:00:00Z],
              end: ~U[2024-10-23 01:00:00Z]
            }),
            build(:active_period, %{
              start: ~U[2024-10-23 13:00:00Z],
              end: ~U[2024-10-24 01:00:00Z]
            })
          ],
          active_period_end: nil
        })

      Alerts.update_recurring_active_periods(alert, ~U[2023-10-24 13:00:00Z])

      [ap_1, ap_2] = Alerts.get_by_alert_id("123").active_period
      assert [~U[2024-10-22 13:00:00Z], ~U[2024-10-23 01:00:00Z]] = [ap_1.start, ap_1.end]
      assert [~U[2024-10-23 13:00:00Z], ~U[2024-10-24 01:00:00Z]] = [ap_2.start, ap_2.end]
    end

    test "doesn't add active periods if alert doesn't recur on that day" do
      alert =
        insert(:alert, %{
          alert_id: "123",
          recurrence_days: [:monday, :tuesday, :wednesday],
          recurrence_start_time: ~T[09:00:00],
          recurrence_end_time: ~T[21:00:00],
          active_period: [
            build(:active_period, %{
              start: ~U[2024-10-22 13:00:00Z],
              end: ~U[2024-10-23 01:00:00Z]
            }),
            build(:active_period, %{
              start: ~U[2024-10-23 13:00:00Z],
              end: ~U[2024-10-24 01:00:00Z]
            })
          ],
          active_period_end: nil
        })

      Alerts.update_recurring_active_periods(alert, ~U[2023-10-24 13:00:00Z])

      [ap_1, ap_2] = Alerts.get_by_alert_id("123").active_period
      assert [~U[2024-10-22 13:00:00Z], ~U[2024-10-23 01:00:00Z]] = [ap_1.start, ap_1.end]
      assert [~U[2024-10-23 13:00:00Z], ~U[2024-10-24 01:00:00Z]] = [ap_2.start, ap_2.end]
    end
  end

  describe "list_all_paginated/1" do
    test "list all alerts with flop" do
      insert(:alert, %{alert_id: "234"})
      insert(:alert, %{alert_id: "456"})
      insert(:alert, %{alert_id: "123", draft: false})
      insert(:alert, %{alert_id: "321", draft: true})
      {results, %Flop.Meta{}} = Alerts.list_all_paginated(%Flop{order_by: []})
      assert length(results) == 3
      assert Enum.map(results, & &1.alert_id) |> Enum.sort() == [123, 234, 456]
    end

    test "filter by active_period" do
      insert(:alert, %{alert_id: "123", active_period_start: ~U[2023-10-14 00:01:00Z]})
      insert(:alert, %{alert_id: "234", active_period_start: ~U[2023-10-16 00:01:00Z]})
      insert(:alert, %{alert_id: "345", active_period_start: ~U[2023-10-15 00:01:00Z]})

      {result, _meta} =
        Alerts.list_all_paginated(%Flop{
          order_by: [:active_period_start, :integer_alert_id],
          order_directions: [:asc, :desc]
        })

      assert result |> Enum.map(& &1.alert_id) == [123, 345, 234]
    end

    test "filter by service type" do
      insert(:alert, %{alert_id: "123"})
      insert(:alert, %{alert_id: "234", primary_service_type: "access"})
      insert(:alert, %{alert_id: "345", primary_service_type: "access"})
      insert(:alert, %{alert_id: "456", primary_service_type: "systemwide"})

      {result_1, _meta} =
        Alerts.list_all_paginated(%{
          order_by: [:integer_alert_id],
          filters: [%{"field" => "service_type", "value" => ["1"]}]
        })

      assert result_1 |> Enum.map(& &1.alert_id) == [123]

      {result_2, _meta} =
        Alerts.list_all_paginated(%{
          order_by: [:integer_alert_id],
          filters: [%{"field" => "service_type", "value" => ["access"]}]
        })

      assert result_2 |> Enum.map(& &1.alert_id) == [234, 345]

      {result_3, _meta} =
        Alerts.list_all_paginated(%{
          order_by: [:integer_alert_id],
          filters: [%{"field" => "service_type", "value" => ""}]
        })

      assert result_3 |> Enum.map(& &1.alert_id) == [123, 234, 345, 456]
    end

    test "filter by effects" do
      [name1, name2, name3 | _] =
        Effect.effects_tuples() |> Enum.map(fn {name, _e, _d} -> name end)

      insert(:alert, %{alert_id: "123", effect_name: name1})
      insert(:alert, %{alert_id: "234", effect_name: name2})
      insert(:alert, %{alert_id: "345", effect_name: name3})

      {result_1, _meta} =
        Alerts.list_all_paginated(%{
          order_by: [:integer_alert_id],
          filters: [%{"field" => "effects", "value" => [name1, name3]}]
        })

      assert result_1 |> Enum.map(& &1.alert_id) == [123, 345]

      {result_2, _meta} =
        Alerts.list_all_paginated(%{
          order_by: [:integer_alert_id],
          filters: [%{"field" => "effects", "value" => [name2]}]
        })

      assert result_2 |> Enum.map(& &1.alert_id) == [234]

      {result_3, _meta} =
        Alerts.list_all_paginated(%{
          order_by: [:integer_alert_id],
          filters: [%{"field" => "effects", "value" => ""}]
        })

      assert result_3 |> Enum.map(& &1.alert_id) == [123, 234, 345]
    end

    test "filter by timeline- past" do
      insert(:alert, %{
        alert_id: "10000",
        active_period_start: @two_hours_ago,
        active_period_end: @one_hour_ago
      })

      insert(:alert, %{
        alert_id: "10100",
        active_period_start: @six_hours_ago,
        active_period_end: @one_hour_ago
      })

      insert(:alert, %{
        alert_id: "10200",
        active_period_start: @six_hours_ago,
        active_period_end: @two_hours_ago
      })

      insert(:alert, %{
        alert_id: "10300",
        active_period_start: @one_hour_ago,
        active_period_end: @one_hour_from_now
      })

      insert(:alert, %{
        alert_id: "10400",
        active_period_start: @one_day_ago,
        active_period_end: @six_hours_ago
      })

      insert(:alert, %{
        alert_id: "10500",
        active_period_start: @one_hour_ago,
        active_period_end: nil
      })

      insert(:alert, %{
        alert_id: "10700",
        active_period_start: @one_hour_ago,
        active_period_end: @now
      })

      {current_results, _meta} =
        Alerts.list_all_paginated(%{
          order_by: [:integer_alert_id],
          filters: [%{"field" => "timeline", "value" => "past"}]
        })

      assert current_results |> Enum.map(& &1.alert_id) == [
               10_000,
               10_100,
               10_200,
               10_400,
               10_700
             ]
    end

    test "filter by timeline- current" do
      insert(:alert, %{
        alert_id: "10000",
        notification_period_start: @two_hours_ago,
        active_period_end: @one_hour_ago,
        notification_period_end: @one_hour_ago,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10100",
        notification_period_start: @two_hours_ago,
        active_period_end: @now,
        notification_period_end: @now,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10200",
        notification_period_start: @two_hours_ago,
        active_period_end: @two_hours_from_now,
        notification_period_end: @two_hours_from_now,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10300",
        notification_period_start: @one_hour_ago,
        active_period_end: @two_hours_from_now,
        notification_period_end: @end_of_service_utc,
        duration_certainty: :ESTIMATED
      })

      insert(:alert, %{
        alert_id: "10400",
        notification_period_start: @two_hours_ago,
        active_period_end: @end_of_service_utc,
        notification_period_end: @end_of_service_utc,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10500",
        notification_period_start: @one_hour_ago,
        active_period_end: @end_of_service_utc,
        notification_period_end: @end_of_service_utc,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10600",
        notification_period_start: @one_hour_ago,
        active_period_end: nil,
        notification_period_end: nil,
        duration_certainty: :UNKNOWN
      })

      insert(:alert, %{
        alert_id: "10700",
        notification_period_start: @two_hours_ago,
        active_period_end: nil,
        notification_period_end: nil,
        duration_certainty: :UNKNOWN
      })

      insert(:alert, %{
        alert_id: "10800",
        active_period_start: @now,
        active_period_end: @two_days_from_now,
        notification_period_end: @two_days_from_now,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10900",
        notification_period_start: @one_hour_from_now,
        active_period_end: @two_days_from_now,
        notification_period_end: @two_days_from_now,
        duration_certainty: :KNOWN
      })

      {current_results, _meta} =
        Alerts.list_all_paginated(%{
          order_by: [:integer_alert_id],
          filters: [%{"field" => "timeline", "value" => "current"}]
        })

      assert current_results |> Enum.map(& &1.alert_id) == [
               10_200,
               10_300,
               10_400,
               10_500,
               10_600,
               10_700,
               10_800
             ]
    end

    test "filter by timeline- future" do
      insert(:alert, %{
        alert_id: "10000",
        active_period_start: @two_hours_ago,
        notification_period_start: @two_hours_ago,
        active_period_end: @one_hour_ago,
        notification_period_end: @one_hour_ago,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10100",
        active_period_start: @now,
        notification_period_start: @now,
        active_period_end: @two_hours_from_now,
        notification_period_end: @now,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10200",
        active_period_start: @two_hours_ago,
        notification_period_start: @one_hour_from_now,
        active_period_end: @two_hours_from_now,
        notification_period_end: @two_hours_from_now,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10300",
        active_period_start: @one_hour_from_now,
        notification_period_start: @one_hour_from_now,
        active_period_end: @two_hours_from_now,
        notification_period_end: @end_of_service_utc,
        duration_certainty: :ESTIMATED
      })

      insert(:alert, %{
        alert_id: "10400",
        active_period_start: @one_hour_from_now,
        notification_period_start: @one_hour_from_now,
        active_period_end: @end_of_service_utc,
        notification_period_end: @end_of_service_utc,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10500",
        active_period_start: @two_days_from_now,
        notification_period_start: @two_days_from_now,
        active_period_end: nil,
        notification_period_end: nil,
        duration_certainty: :UNKNOWN
      })

      insert(:alert, %{
        alert_id: "10600",
        active_period_start: @one_hour_from_now,
        notification_period_start: @one_hour_from_now,
        active_period_end: nil,
        notification_period_end: nil,
        duration_certainty: :UNKNOWN
      })

      insert(:alert, %{
        alert_id: "10700",
        active_period_start: @two_days_from_now,
        notification_period_start: @two_days_from_now,
        active_period_end: @two_days_from_now,
        notification_period_end: @two_days_from_now,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10800",
        active_period_start: @two_days_from_now,
        notification_period_start: @two_days_from_now,
        active_period_end: @two_days_from_now,
        notification_period_end: @two_days_from_now,
        duration_certainty: :KNOWN,
        closed_timestamp: @now
      })

      {current_results, _meta} =
        Alerts.list_all_paginated(%{
          order_by: [:integer_alert_id],
          filters: [%{"field" => "timeline", "value" => "future"}]
        })

      assert current_results |> Enum.map(& &1.alert_id) == [
               10_200,
               10_300,
               10_400,
               10_500,
               10_600,
               10_700
             ]
    end

    test "filter by timeline- all" do
      insert(:alert, %{
        alert_id: "10000",
        active_period_start: @six_hours_ago,
        notification_period_start: @six_hours_ago,
        active_period_end: nil,
        notification_period_end: nil,
        duration_certainty: :UNKNOWN
      })

      insert(:alert, %{
        alert_id: "10100",
        active_period_start: @one_day_ago,
        notification_period_start: @one_day_ago,
        active_period_end: nil,
        notification_period_end: nil,
        duration_certainty: :UNKNOWN
      })

      insert(:alert, %{
        alert_id: "10300",
        active_period_start: @six_hours_ago,
        notification_period_start: @six_hours_ago,
        active_period_end: @one_hour_from_now,
        notification_period_end: @one_hour_from_now,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10400",
        active_period_start: @one_hour_from_now,
        notification_period_start: @one_hour_from_now,
        active_period_end: @two_hours_from_now,
        notification_period_end: @two_hours_from_now,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10500",
        active_period_start: @two_hours_ago,
        notification_period_start: @two_hours_ago,
        active_period_end: @two_hours_from_now,
        notification_period_end: @end_of_service_utc,
        duration_certainty: :ESTIMATED
      })

      insert(:alert, %{
        alert_id: "10600",
        active_period_start: @one_day_ago,
        notification_period_start: @one_day_ago,
        active_period_end: @end_of_service_utc,
        notification_period_end: @end_of_service_utc,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10700",
        active_period_start: @one_day_ago,
        notification_period_start: @one_day_ago,
        active_period_end: @six_hours_ago,
        notification_period_end: @six_hours_ago,
        duration_certainty: :KNOWN
      })

      insert(:alert, %{
        alert_id: "10800",
        active_period_start: @one_day_from_now,
        notification_period_start: @one_day_from_now,
        active_period_end: @two_days_from_now,
        notification_period_end: @two_days_from_now,
        duration_certainty: :KNOWN
      })

      {current_results, _meta} =
        Alerts.list_all_paginated(%{
          order_by: [:integer_alert_id],
          filters: [%{"field" => "timeline", "value" => "all"}]
        })

      assert current_results |> Enum.map(& &1.alert_id) == [
               10_000,
               10_100,
               10_300,
               10_400,
               10_500,
               10_600,
               10_700,
               10_800
             ]
    end
  end

  describe "filter_on_notification_period_start/2" do
    test "returns all if no notification period" do
      current_time = ~U[2024-09-06 04:00:00Z]

      alerts = [
        build(:alert, %{alert_id: "123"}),
        build(:alert, %{alert_id: "234"}),
        build(:alert, %{alert_id: "456"})
      ]

      result = Alerts.filter_on_notification_period_start(alerts, current_time)
      assert result |> Enum.map(fn r -> r.alert_id end) |> Enum.sort() == ["123", "234", "456"]
    end

    test "filters out if notification start after current time" do
      current_time = ~U[2024-09-06 04:00:00Z]

      alerts = [
        build(:alert, %{
          alert_id: "123",
          notification_period_start: DateTime.add(current_time, -1, :hour)
        }),
        build(:alert, %{
          alert_id: "234",
          notification_period_start: DateTime.add(current_time, 1, :hour)
        }),
        build(:alert, %{alert_id: "456", notification_period_start: nil})
      ]

      result = Alerts.filter_on_notification_period_start(alerts, ~U[2024-09-06 04:00:00Z])
      assert result |> Enum.map(fn r -> r.alert_id end) |> Enum.sort() == ["123", "456"]
    end
  end

  describe "list_all_open/0" do
    test "lists all alerts" do
      active_period_1 =
        build(:active_period, %{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:01:00Z]})

      active_period_2 =
        build(:active_period, %{start: ~U[2023-10-10 00:01:00Z], end: ~U[2023-10-11 00:01:00Z]})

      insert(:alert, %{alert_id: "234", closed_timestamp: ~U[2023-10-14 00:01:00Z]})
      insert(:alert, %{alert_id: "456"})
      insert(:alert, %{alert_id: "123", active_period: [active_period_1, active_period_2]})

      [alert_1, alert_2] = Alerts.list_all_open()
      assert alert_1.alert_id == "123"
      assert alert_2.alert_id == "456"

      [active_period_result_1, active_period_result_2] = alert_1.active_period
      assert active_period_result_1.start == ~U[2023-10-10 00:01:00Z]
      assert active_period_result_2.start == ~U[2023-10-12 00:01:00Z]
    end
  end

  describe "list_a_month_of_commuter_rail/1" do
    test "lists all commuter rail alerts created in most recent calendar month" do
      insert(:alert, %{
        alert_id: "123",
        created_timestamp: ~U[2025-11-30 00:01:00Z],
        primary_service_type: "2"
      })

      insert(:alert, %{
        alert_id: "234",
        created_timestamp: ~U[2025-12-10 00:01:00Z],
        primary_service_type: "2"
      })

      insert(:alert, %{
        alert_id: "345",
        created_timestamp: ~U[2025-12-10 00:01:00Z],
        primary_service_type: "3"
      })

      insert(:alert, %{
        alert_id: "456",
        created_timestamp: ~U[2025-12-30 00:01:00Z],
        primary_service_type: "2"
      })

      insert(:alert, %{
        alert_id: "567",
        created_timestamp: ~U[2026-01-02 00:01:00Z],
        primary_service_type: "2"
      })

      ["234", "456"] = Alerts.list_a_month_of_commuter_rail(12, 2025)
    end
  end

  describe "list_all_recently_closed/0" do
    test "lists all alerts that were closed more recently than 5 minutes ago" do
      current_time = DateTime.utc_now()
      three_minutes_ago = DateTime.add(current_time, -3, :minute)
      seven_minutes_ago = DateTime.add(current_time, -7, :minute)
      one_minute_from_now = DateTime.add(current_time, 1, :minute)
      insert(:alert, %{alert_id: "3_minutes_ago", closed_timestamp: three_minutes_ago})
      insert(:alert, %{alert_id: "7_minutes_ago", closed_timestamp: seven_minutes_ago})
      insert(:alert, %{alert_id: "one_minute_from_now", closed_timestamp: one_minute_from_now})
      insert(:alert, %{alert_id: "no_closed_timestamp"})

      all_alerts = Alerts.list_all_recently_closed()

      assert Enum.find(all_alerts, &(&1.alert_id == "3_minutes_ago"))
      assert Enum.find(all_alerts, &(&1.alert_id == "one_minute_from_now"))
      refute Enum.find(all_alerts, &(&1.alert_id == "7_minutes_ago"))
      refute Enum.find(all_alerts, &(&1.alert_id == "no_closed_timestamp"))
    end
  end

  describe "list_all/0" do
    test "lists all alerts" do
      insert(:alert, %{alert_id: "123"})
      insert(:alert, %{alert_id: "234"})

      all_alerts = Alerts.list_all()

      assert Enum.find(all_alerts, &(&1.alert_id == "123"))
      assert Enum.find(all_alerts, &(&1.alert_id == "234"))
    end
  end

  describe "get_by_alert_id/1" do
    test "returns alert with matching alert_id" do
      expected_alert = insert(:alert, %{alert_id: "123", header_text: "this is the right alert"})
      insert(:alert, %{alert_id: "234", header_text: "wrong alert here"})
      assert Alerts.get_by_alert_id("123").header_text == expected_alert.header_text
    end
  end

  describe "get_by_id/1" do
    test "returns alert with matching alert_id" do
      expected_uuid = Ecto.UUID.generate()

      expected_alert =
        insert(:alert, %{id: expected_uuid, header_text: "this is the right alert"})

      insert(:alert, %{alert_id: "456", header_text: "wrong alert here"})
      assert Alerts.get_by_id(expected_uuid).header_text == expected_alert.header_text
    end
  end

  describe "get_alert_id_by_uuid/1" do
    test "returns alert with matching alert_id" do
      uuid = Ecto.UUID.generate()

      insert(:alert, %{id: uuid, header_text: "this is the right alert", alert_id: "123"})

      assert Alerts.get_uuid_by_alert_id("123") == uuid
    end

    test "returns nil if alert not found" do
      assert Alerts.get_uuid_by_alert_id("123") == nil
    end
  end

  describe "get_all_versions/1" do
    test "returns all versions with the earliest first" do
      user = build(:user)

      original_alert_map =
        build(
          :alert_map,
          %{
            alert_id: "123",
            header_text: "old header text",
            user: user
          }
        )

      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          active_period: [%{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:03:00Z]}],
          user: user
        })

      Alerts.create_or_update_alert(original_alert_map, user)

      existing_alert = Alerts.get_by_alert_id("123")

      Alerts.create_or_update_alert(new_params, user, existing_alert)

      alert = Alerts.get_by_alert_id("123")
      [version_1, version_2] = Alerts.get_all_versions(alert.id)
      assert version_1.item_changes["header_text"] == "old header text"
      assert version_2.item_changes["header_text"] == "new header text"
    end
  end

  describe "draft?/1" do
    test "returns false if alert draft is false" do
      insert(:alert, %{alert_id: "123", draft: false})
      refute Alerts.draft?("123")
    end

    test "returns false if alert draft is nil" do
      alert = insert(:alert, %{alert_id: "123", draft: nil})
      refute Alerts.draft?(alert)
    end

    test "returns true if alert draft is true" do
      insert(:alert, %{alert_id: "123", draft: true})
      assert Alerts.draft?("123")
    end
  end

  describe "close_automatically/2" do
    test "closes alert and updates LPNT if duration certainty is UNKNOWN" do
      current_time = ~U[2024-06-04 00:01:11Z]

      insert(:alert, %{
        alert_id: "123",
        duration_certainty: :UNKNOWN,
        last_push_notification_timestamp: ~U[2024-06-02 00:00:00Z],
        active_period: [
          build(:active_period, %{start: ~U[2024-06-02 00:00:00Z]})
        ]
      })

      Alerts.get_by_alert_id("123") |> Alerts.close_automatically(current_time)
      result = Alerts.get_by_alert_id("123")
      assert result.last_push_notification_timestamp == current_time
    end

    test "closes alert and does not update LPNT if duration certainty is ESTIMATED" do
      current_time = ~U[2024-06-04 00:01:11Z]

      insert(:alert, %{
        alert_id: "123",
        duration_certainty: :ESTIMATED,
        last_push_notification_timestamp: ~U[2024-06-03 00:00:00Z],
        active_period: [
          build(:active_period, %{start: ~U[2024-06-03 00:00:00Z], end: ~U[2024-06-03 00:02:00Z]})
        ]
      })

      Alerts.get_by_alert_id("123") |> Alerts.close_automatically(current_time)
      result = Alerts.get_by_alert_id("123")
      assert result.last_push_notification_timestamp == ~U[2024-06-03 00:00:00Z]
    end

    test "closes alert and does not update LPNT if duration certainty is KNOWN" do
      current_time = ~U[2024-06-04 00:01:11Z]

      insert(:alert, %{
        alert_id: "123",
        duration_certainty: :KNOWN,
        last_push_notification_timestamp: ~U[2024-06-02 00:00:00Z],
        active_period: [
          build(:active_period, %{start: ~U[2024-06-01 00:00:00Z], end: ~U[2024-06-02 00:00:00Z]}),
          build(:active_period, %{start: ~U[2024-06-03 00:00:00Z], end: ~U[2024-06-04 04:00:00Z]})
        ]
      })

      Alerts.get_by_alert_id("123") |> Alerts.close_automatically(current_time)
      result = Alerts.get_by_alert_id("123")
      assert result.last_push_notification_timestamp == ~U[2024-06-02 00:00:00Z]
    end
  end

  describe "close/4" do
    test "closes alert when send_all_clear? is false" do
      current_time = ~U[2024-06-04 00:01:11Z]

      user = build(:user)

      insert(:alert, %{
        alert_id: "123",
        duration_certainty: :ESTIMATED,
        last_push_notification_timestamp: ~U[2024-06-02 00:00:00Z],
        active_period: [
          build(:active_period, %{start: ~U[2024-06-01 00:00:00Z], end: ~U[2024-06-02 00:00:00Z]}),
          build(:active_period, %{start: ~U[2024-06-03 00:00:00Z], end: ~U[2024-06-04 04:00:00Z]})
        ]
      })

      Alerts.get_by_alert_id("123") |> Alerts.close(user, false, current_time)

      result = Alerts.get_by_alert_id("123")

      assert result.active_period_end == current_time
      assert result.closed_timestamp == current_time
      assert result.notification_period_end == current_time
      assert result.last_push_notification_timestamp == ~U[2024-06-02 00:00:00Z]
      assert result.duration_certainty == :KNOWN
    end

    test "closes alert when send_all_clear? is true" do
      current_time = ~U[2024-06-04 00:01:11Z]

      insert(:alert, %{
        alert_id: "123",
        duration_certainty: :ESTIMATED,
        last_push_notification_timestamp: ~U[2024-06-02 00:00:00Z],
        active_period: [
          build(:active_period, %{start: ~U[2024-06-01 00:00:00Z], end: ~U[2024-06-02 00:00:00Z]}),
          build(:active_period, %{start: ~U[2024-06-03 00:00:00Z], end: ~U[2024-06-04 04:00:00Z]})
        ]
      })

      Alerts.get_by_alert_id("123") |> Alerts.close(build(:user), true, current_time)
      result = Alerts.get_by_alert_id("123")
      assert result.last_push_notification_timestamp == current_time
    end
  end

  describe "publishable?/1" do
    test "returns true if alert draft is false" do
      insert(:alert, %{alert_id: "123", draft: false})
      assert Alerts.publishable?("123")
    end

    test "returns true if alert draft is nil" do
      alert = insert(:alert, %{alert_id: "123", draft: nil})
      assert Alerts.publishable?(alert)
    end

    test "returns false if alert draft is true" do
      insert(:alert, %{alert_id: "123", draft: true})
      refute Alerts.publishable?("123")
    end
  end

  describe "delete/1" do
    test "deletes alert" do
      insert(:alert, %{
        alert_id: "123",
        duration_certainty: :ESTIMATED,
        active_period: [
          build(:active_period, %{start: ~U[2024-06-01 00:00:00Z], end: ~U[2024-06-02 00:00:00Z]}),
          build(:active_period, %{start: ~U[2024-06-03 00:00:00Z], end: ~U[2024-06-04 04:00:00Z]})
        ]
      })

      assert Alerts.get_by_alert_id("123")

      Alerts.delete("123")

      refute Alerts.get_by_alert_id("123")
    end
  end
end
