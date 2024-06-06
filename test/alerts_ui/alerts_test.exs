defmodule AlertsUI.AlertsTest do
  @moduledoc false
  use AlertsUI.DataCase, async: false
  import AlertsUI.Support.Factory
  import Test.Support.Helpers
  alias AlertsUI.Alerts
  alias AlertsUI.Models.Alert

  @five_minutes_ago DateTime.utc_now()
                    |> DateTime.add(-5, :minute)
                    |> DateTime.truncate(:second)

  describe "create_or_update_alert" do
    test "creates alert from params" do
      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          description_text: ""
        })

      {:ok, new_alert} =
        Alerts.create_or_update_alert(new_params)

      assert new_alert.alert_id == "123"
      assert new_alert.header_text == "new header text"
      assert new_alert.description_text == ""
      refute new_alert.created_timestamp == nil
      refute new_alert.last_modified_timestamp == nil
    end

    test "uses provided created_timestamp and last_modified_timestamp if given" do
      new_params =
        build(:alert_map, %{
          alert_id: "123",
          created_timestamp: @five_minutes_ago,
          last_modified_timestamp: @five_minutes_ago
        })

      {:ok, new_alert} =
        Alerts.create_or_update_alert(new_params)

      assert new_alert.alert_id == "123"
      assert new_alert.created_timestamp == @five_minutes_ago
      assert new_alert.last_modified_timestamp == @five_minutes_ago
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
            ]
          }
        )

      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          last_modified_timestamp: ~U[2023-10-12 00:01:00Z],
          active_period: [%{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:03:00Z]}]
        })

      Alerts.create_or_update_alert(new_params, existing_alert)
      updated_alert = Repo.get_by(Alert, id: existing_alert.id)
      assert updated_alert.alert_id == "123"
      assert updated_alert.header_text == "new header text"
      assert (updated_alert.active_period |> hd).end == ~U[2023-10-13 00:03:00Z]
    end

    test "updates last_modified_timestamp when updating an existing alert" do
      existing_alert =
        insert(
          :alert,
          %{
            alert_id: "123",
            header_text: "old header text",
            last_modified_timestamp: @five_minutes_ago
          }
        )

      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text"
        })

      Alerts.create_or_update_alert(new_params, existing_alert)
      updated_alert = Repo.get_by(Alert, id: existing_alert.id)

      assert DateTime.compare(updated_alert.last_modified_timestamp, @five_minutes_ago) == :gt
    end

    test "does not change created_timestamp when updating an existing alert" do
      existing_alert =
        insert(
          :alert,
          %{
            alert_id: "123",
            header_text: "old header text",
            created_timestamp: @five_minutes_ago
          }
        )

      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text"
        })

      Alerts.create_or_update_alert(new_params, existing_alert)
      updated_alert = Repo.get_by(Alert, id: existing_alert.id)

      assert updated_alert.created_timestamp == @five_minutes_ago
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
            ]
          }
        )

      new_params =
        build(:alert_map, %{
          alert_id: "123",
          last_modified_timestamp: ~U[2023-10-12 00:01:00Z],
          active_period: [%{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:03:00Z]}]
        })

      assert {:ok, updated_alert} = Alerts.create_or_update_alert(new_params, existing_alert)
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
        Alerts.create_or_update_alert(new_params)

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
        Alerts.create_or_update_alert(new_params)

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

      {:error, changeset} = Alerts.create_or_update_alert(new_params)
      assert changeset.errors == [header_text: {"is required", [validation: :required]}]
    end

    test "error if feed compare is true" do
      reassign_env(:alerts_ui, :compare_feed, "true")

      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: nil,
          description_text: nil
        })

      {:error, changeset} = Alerts.create_or_update_alert(new_params)

      assert changeset.errors == [
               alert_id: {"cannot create alert while feed is being compared", []}
             ]
    end
  end

  describe "parse_changeset_errors/1" do
    test "puts changeset errors in readable format" do
      changeset =
        Alert.changeset(%Alert{}, %{header_text: "hello", informed_entity: []})

      result = Alerts.parse_changeset_errors(changeset)

      assert result == %{
               informed_entity: ["should have at least 1 item(s)", "can't be blank"]
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

  describe "create_or_modify_alert_from_feed/1" do
    test "creates alert if new" do
      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          description_text: "",
          last_modified_timestamp: ~U[2023-10-12 00:01:00Z]
        })

      Alerts.create_or_modify_alert_from_feed(new_params)
      new_alert = Repo.get_by(Alert, alert_id: "123")
      assert new_alert.alert_id == "123"
      assert new_alert.header_text == "new header text"
      assert new_alert.description_text == ""
    end

    test "updates alert if ids match" do
      existing_alert =
        insert(
          :alert,
          %{
            alert_id: "123",
            header_text: "old header text",
            active_period: [
              build(:active_period),
              %{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:01:00Z]}
            ]
          }
        )

      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          last_modified_timestamp: ~U[2023-10-12 00:01:00Z],
          active_period: [%{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:03:00Z]}]
        })

      Alerts.create_or_modify_alert_from_feed(new_params)
      updated_alert = Repo.get_by(Alert, id: existing_alert.id)
      assert updated_alert.alert_id == "123"
      assert updated_alert.header_text == "new header text"
      assert (updated_alert.active_period |> hd).end == ~U[2023-10-13 00:03:00Z]
    end

    test "saves papertrail versions" do
      alert_id = Ecto.UUID.generate()

      first_params =
        build(:alert_map, %{
          alert_id: alert_id,
          header_text: "old header text",
          last_modified_timestamp: ~U[2023-10-12 00:00:00Z],
          active_period: [
            %{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:01:00Z]}
          ]
        })

      second_params =
        build(:alert_map, %{
          alert_id: alert_id,
          header_text: "new header text",
          last_modified_timestamp: ~U[2023-10-12 00:01:00Z],
          active_period: [%{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:03:00Z]}]
        })

      assert :ok = Alerts.create_or_modify_alert_from_feed(first_params)
      assert :ok = Alerts.create_or_modify_alert_from_feed(second_params)

      current_alert = Alerts.get_by_alert_id(alert_id)
      version = PaperTrail.get_version(current_alert)
      %PaperTrail.Version{item_changes: original_version} = version

      assert current_alert.header_text == "new header text"
      assert original_version["header_text"] == "old header text"
    end

    test "does not update active period if empty and closed" do
      existing_alert =
        insert(
          :alert,
          %{
            alert_id: "123",
            header_text: "old header text",
            active_period: [
              build(:active_period),
              %{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:01:00Z]}
            ]
          }
        )

      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          last_modified_timestamp: ~U[2023-10-12 00:01:00Z],
          closed_timestamp: ~U[2023-10-13 00:01:00Z],
          active_period: []
        })

      Alerts.create_or_modify_alert_from_feed(new_params)
      updated_alert = Repo.get_by(Alert, id: existing_alert.id)
      assert (updated_alert.active_period |> hd).end == ~U[2023-10-13 00:01:00Z]
    end

    @tag :capture_log
    test "does not update alert if ids dont match" do
      existing_alert =
        insert(
          :alert,
          %{
            alert_id: "123",
            header_text: "old header text"
          }
        )

      new_params =
        build(:alert_map, %{
          alert_id: "234",
          header_text: "new header text",
          last_modified_timestamp: ~U[2023-10-12 00:01:00Z]
        })

      Alerts.create_or_modify_alert_from_feed(new_params)
      unmodified_alert = Repo.get_by!(Alert, id: existing_alert.id)
      assert unmodified_alert.alert_id == "123"
      assert unmodified_alert.header_text == "old header text"
    end

    test "does not update alert if incoming is not newer" do
      insert(
        :alert,
        %{
          alert_id: "123",
          header_text: "old header text",
          last_modified_timestamp: ~U[2023-10-14 00:01:00Z]
        }
      )

      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          last_modified_timestamp: ~U[2023-10-12 00:01:00Z]
        })

      Alerts.create_or_modify_alert_from_feed(new_params)
      unmodified_alert = Repo.get_by!(Alert, alert_id: "123")
      assert unmodified_alert.header_text == "old header text"
    end

    @tag :capture_log
    test "does not create invalid alert" do
      before_alerts_length = Alerts.list_all() |> length

      alert = %{
        alert_id: "123",
        description_text: "b",
        informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}]
      }

      Alerts.create_or_modify_alert_from_feed(alert)
      assert length(Alerts.list_all()) - before_alerts_length == 0
    end
  end

  describe "create_changeset_from_feed/3" do
    test "create new changeset if no stored alert" do
      params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          description_text: "",
          last_modified_timestamp: ~U[2023-10-12 00:01:00Z]
        })

      {:ok, changeset} =
        Alerts.create_changeset_from_feed(:repo, %{most_recent_alert: nil}, params)

      assert changeset.changes.alert_id == "123"
    end

    test "create modification changeset if stored alert is older" do
      stored_alert =
        insert(:alert, %{
          alert_id: "123",
          header_text: "old header text",
          description_text: "",
          last_modified_timestamp: ~U[2023-10-12 00:01:00Z],
          active_period: [
            build(:active_period),
            %{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:01:00Z]}
          ]
        })

      params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          description_text: "",
          last_modified_timestamp: ~U[2023-10-13 00:01:00Z],
          active_period: [
            %{
              start: ~U[2023-10-20 16:15:00Z],
              end: ~U[2023-10-21 18:45:38Z]
            }
          ]
        })

      {:ok, changeset} =
        Alerts.create_changeset_from_feed(:repo, %{most_recent_alert: stored_alert}, params)

      assert changeset.changes.header_text == "new header text"
      assert changeset.changes.active_period |> length == 3
    end

    test "do not overwrite active period if incoming has closed timestamp and empty active period" do
      stored_alert =
        insert(:alert, %{
          alert_id: "123",
          header_text: "old header text",
          description_text: "",
          last_modified_timestamp: ~U[2023-10-12 00:01:00Z],
          active_period: [
            build(:active_period),
            %{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:01:00Z]}
          ],
          active_period_start: ~U[2023-10-12 00:01:00Z],
          active_period_end: ~U[2023-10-13 00:01:00Z]
        })

      params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          description_text: "",
          last_modified_timestamp: ~U[2023-10-13 00:01:00Z],
          closed_timestamp: ~U[2023-10-14 00:01:00Z],
          active_period: [],
          active_period_start: nil,
          active_period_end: nil
        })

      {:ok, changeset} =
        Alerts.create_changeset_from_feed(:repo, %{most_recent_alert: stored_alert}, params)

      assert changeset.changes.header_text == "new header text"
      assert Map.has_key?(changeset.changes, :active_period) == false
      assert Map.has_key?(changeset.changes, :active_period_end) == false
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

  describe "close_if_end_is_past/1" do
    test "foo" do
      current_time = ~U[2024-06-05 00:00:00Z]
      insert(:alert, %{alert_id: "123", active_period_end: ~U[2024-06-04 00:00:00Z]})
      insert(:alert, %{alert_id: "234", active_period_end: ~U[2024-06-06 00:00:00Z]})
      insert(:alert, %{alert_id: "345"})
      result = Alerts.list_all_open() |> Alerts.close_if_end_is_past(current_time)
      [result1, result2, result3] = result |> Enum.sort_by(& &1.alert_id)
      assert result1.closed_timestamp == current_time
      assert result2.closed_timestamp == nil
      assert result3.closed_timestamp == nil
    end
  end

  describe "close_if_not_in_feed/2" do
    test "closes existing alerts that aren't in the feed" do
      insert(:alert, %{alert_id: "123"})
      insert(:alert, %{alert_id: "234"})
      insert(:alert, %{alert_id: "456"})

      alert_feed = [build(:alert_map, %{alert_id: "456"})]
      Alerts.close_if_not_in_feed(alert_feed, ~U[2023-10-14 00:01:00Z])
      result1 = Repo.get_by(Alert, alert_id: "123")
      result2 = Repo.get_by(Alert, alert_id: "234")
      result3 = Repo.get_by(Alert, alert_id: "456")

      assert result1.closed_timestamp == ~U[2023-10-14 00:01:00Z]
      assert result2.closed_timestamp == ~U[2023-10-14 00:01:00Z]
      assert result3.closed_timestamp == nil
    end

    test "do not update closed timestamp if exists" do
      insert(:alert, %{alert_id: "123", closed_timestamp: ~U[2023-10-01 00:01:00Z]})
      insert(:alert, %{alert_id: "234"})
      insert(:alert, %{alert_id: "456"})

      alert_feed = [build(:alert_map, %{alert_id: "456"}), build(:alert_map, %{alert_id: "234"})]
      Alerts.close_if_not_in_feed(alert_feed, ~U[2023-10-14 00:01:00Z])
      result1 = Repo.get_by(Alert, alert_id: "123")
      result2 = Repo.get_by(Alert, alert_id: "234")
      result3 = Repo.get_by(Alert, alert_id: "456")

      assert result1.closed_timestamp == ~U[2023-10-01 00:01:00Z]
      assert result2.closed_timestamp == nil
      assert result3.closed_timestamp == nil
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
      insert(:alert, %{alert_id: "012", active_period_start: nil})
      insert(:alert, %{alert_id: "123", active_period_start: ~U[2023-10-14 00:01:00Z]})
      insert(:alert, %{alert_id: "234", active_period_start: ~U[2023-10-16 00:01:00Z]})
      insert(:alert, %{alert_id: "345", active_period_start: ~U[2023-10-15 00:01:00Z]})

      {result, _meta} =
        Alerts.list_all_paginated(%Flop{
          order_by: [:active_period_start, :created_timestamp, :integer_alert_id],
          order_directions: [:asc, :desc, :desc]
        })

      assert result |> Enum.map(& &1.alert_id) == [123, 345, 234, 012]
    end

    test "filter by service type" do
      ie_1 = build(:informed_entity, %{route_type: 1, activities: [:BOARD]})
      ie_2 = build(:informed_entity, %{route_type: nil, activities: [:STORE_BIKE]})
      insert(:alert, %{alert_id: "123", informed_entity: [ie_1]})
      insert(:alert, %{alert_id: "234", informed_entity: [ie_2]})
      insert(:alert, %{alert_id: "345", informed_entity: [ie_1, ie_2]})

      {result_1, _meta} =
        Alerts.list_all_paginated(%{
          order_by: [:integer_alert_id],
          filters: [%{"field" => "service_type", "value" => "1"}]
        })

      assert result_1 |> Enum.map(& &1.alert_id) == [123, 345]

      {result_2, _meta} =
        Alerts.list_all_paginated(%{
          order_by: [:integer_alert_id],
          filters: [%{"field" => "service_type", "value" => "access"}]
        })

      assert result_2 |> Enum.map(& &1.alert_id) == [234, 345]

      {result_3, _meta} =
        Alerts.list_all_paginated(%{
          order_by: [:integer_alert_id],
          filters: [%{"field" => "service_type", "value" => ""}]
        })

      assert result_3 |> Enum.map(& &1.alert_id) == [123, 234, 345]
    end

    test "filter by timeline" do
      now = DateTime.utc_now()
      one_hour_from_now = DateTime.add(now, 1, :hour)
      one_hour_ago = DateTime.add(now, -1, :hour)

      insert(:alert, %{
        # start_nil_end_nil
        alert_id: "100",
        active_period_start: nil,
        active_period_end: nil
      })

      insert(:alert, %{
        # start_nil_end_future
        alert_id: "101",
        active_period_start: nil,
        active_period_end: one_hour_from_now
      })

      insert(:alert, %{
        # start_nil_end_past
        alert_id: "102",
        active_period_start: nil,
        active_period_end: one_hour_ago
      })

      insert(:alert, %{
        # start_future_end_nil
        alert_id: "103",
        active_period_start: one_hour_from_now,
        active_period_end: nil
      })

      insert(:alert, %{
        # start_past_end_nil
        alert_id: "104",
        active_period_start: one_hour_ago,
        active_period_end: nil
      })

      insert(:alert, %{
        # start_past_end_past
        alert_id: "105",
        active_period_start: one_hour_ago,
        active_period_end: one_hour_ago
      })

      insert(:alert, %{
        # start_past_end_future
        alert_id: "106",
        active_period_start: one_hour_ago,
        active_period_end: one_hour_from_now
      })

      insert(:alert, %{
        # start_future_end_future
        alert_id: "107",
        active_period_start: one_hour_from_now,
        active_period_end: one_hour_from_now
      })

      {current_results, _meta} =
        Alerts.list_all_paginated(%{
          order_by: [:integer_alert_id],
          filters: [%{"field" => "timeline", "value" => "current"}]
        })

      assert current_results |> Enum.map(& &1.alert_id) == [100, 101, 104, 106]

      {future_results, _meta} =
        Alerts.list_all_paginated(%{
          order_by: [:integer_alert_id],
          filters: [%{"field" => "timeline", "value" => "future"}]
        })

      assert future_results |> Enum.map(& &1.alert_id) == [103, 107]

      {past_results, _meta} =
        Alerts.list_all_paginated(%{
          order_by: [:integer_alert_id],
          filters: [%{"field" => "timeline", "value" => "past"}]
        })

      assert past_results |> Enum.map(& &1.alert_id) == [102, 105]
    end
  end

  describe "list_all_open/0" do
    test "lists all alerts" do
      insert(:alert, %{alert_id: "234", closed_timestamp: ~U[2023-10-14 00:01:00Z]})
      insert(:alert, %{alert_id: "456"})
      insert(:alert, %{alert_id: "123"})

      all_alerts = Alerts.list_all_open()

      assert Enum.find(all_alerts, &(&1.alert_id == "123"))
      assert Enum.find(all_alerts, &(&1.alert_id == "456"))
      refute Enum.find(all_alerts, &(&1.alert_id == "234"))
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
      uuid = Ecto.UUID.generate()
      expected_alert = insert(:alert, %{id: uuid, header_text: "this is the right alert"})
      insert(:alert, %{header_text: "wrong alert here"})
      assert Alerts.get_by_id(uuid).header_text == expected_alert.header_text
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
end
