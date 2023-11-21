defmodule AlertsUI.AlertsTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUI.Alerts
  alias AlertsUI.Models.Alert

  describe "create_or_modify_alert/1" do
    test "creates alert if new" do
      new_params =
        build(:alert_map, %{
          alert_id: "123",
          header_text: "new header text",
          description_text: "",
          last_modified_timestamp: ~U[2023-10-12 00:01:00Z]
        })

      Alerts.create_or_modify_alert(new_params)
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

      Alerts.create_or_modify_alert(new_params)
      updated_alert = Repo.get_by(Alert, id: existing_alert.id)
      assert updated_alert.alert_id == "123"
      assert updated_alert.header_text == "new header text"
      assert (updated_alert.active_period |> hd).end == ~U[2023-10-13 00:03:00Z]
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

      Alerts.create_or_modify_alert(new_params)
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

      Alerts.create_or_modify_alert(new_params)
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

      Alerts.create_or_modify_alert(alert)
      assert length(Alerts.list_all()) - before_alerts_length == 0
    end
  end

  describe "is_last_modified_time_more_recent?/1" do
    test "returns true if incoming alert is more recent than stored alert" do
      existing_alert =
        insert(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-13 00:01:00Z]})

      incoming_alert =
        build(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-14 00:01:00Z]})

      assert Alerts.is_last_modified_time_more_recent?(
               Map.get(incoming_alert, :last_modified_timestamp),
               Map.get(existing_alert, :last_modified_timestamp)
             ) == true
    end

    test "returns true if incoming alert has same time as stored alert" do
      existing_alert =
        insert(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-13 00:01:00Z]})

      incoming_alert =
        build(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-13 00:01:00Z]})

      assert Alerts.is_last_modified_time_more_recent?(
               Map.get(incoming_alert, :last_modified_timestamp),
               Map.get(existing_alert, :last_modified_timestamp)
             ) == true
    end

    test "returns false if incoming alert is not more recent than stored alert" do
      existing_alert =
        insert(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-14 00:01:00Z]})

      incoming_alert =
        build(:alert_map, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-13 00:01:00Z]})

      assert Alerts.is_last_modified_time_more_recent?(
               Map.get(incoming_alert, :last_modified_timestamp),
               Map.get(existing_alert, :last_modified_timestamp)
             ) == false
    end

    test "returns false if incoming alert has no timestamp" do
      existing_alert =
        insert(:alert, %{alert_id: "123", last_modified_timestamp: ~U[2023-10-14 00:01:00Z]})

      incoming_alert =
        build(:alert_map, %{alert_id: "123"})

      assert Alerts.is_last_modified_time_more_recent?(
               Map.get(incoming_alert, :last_modified_timestamp),
               Map.get(existing_alert, :last_modified_timestamp)
             ) == false
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

  describe "list_all_open/0" do
    test "lists all alerts" do
      insert(:alert, %{alert_id: "234", closed_timestamp: ~U[2023-10-14 00:01:00Z]})
      insert(:alert, %{alert_id: "456"})
      insert(:alert, %{alert_id: "123"})

      all_alerts = Alerts.list_all()

      assert Enum.find(all_alerts, &(&1.alert_id == "123"))
      assert Enum.find(all_alerts, &(&1.alert_id == "456"))
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
end
