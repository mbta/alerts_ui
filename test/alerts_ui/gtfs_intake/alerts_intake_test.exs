defmodule AlertsUI.GTFSIntake.AlertsIntakeTest do
  @moduledoc false
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUI.Alerts
  alias AlertsUI.GTFSIntake.AlertsIntake
  alias AlertsUI.Models.Alert
  alias Req.Response

  describe "run" do
    test "returns :ok" do
      opts = [
        get_fn: fn _ ->
          body = %{"entity" => []}
          Response.new(status: 200, body: body)
        end
      ]

      assert AlertsIntake.run(opts) == :ok
    end

    test "creates alerts if there's no previous versions" do
      alert_entity_data_1 =
        :alert_entity_data
        |> build(%{"id" => "123"})
        |> last_modified(1_697_741_138)

      alert_entity_data_2 =
        :alert_entity_data
        |> build(%{"id" => "234"})
        |> last_modified(1_697_827_538)

      opts = [
        get_fn: fn _ ->
          body =
            %{
              "entity" => [
                alert_entity_data_1,
                alert_entity_data_2
              ]
            }

          Response.new(status: 200, body: body)
        end
      ]

      before_alerts_length = Alerts.list_all() |> length

      AlertsIntake.run(opts)

      assert length(Alerts.list_all()) - before_alerts_length == 2
    end

    test "updates alert if incoming version is most recent" do
      alert_entity_data_1 =
        :alert_entity_data
        |> build(%{"id" => "123"})
        |> last_modified(1_697_913_938)
        |> with_header_text("new")

      alert_entity_data_2 =
        :alert_entity_data
        |> build(%{"id" => "234"})
        |> last_modified(1_697_827_538)

      opts = [
        get_fn: fn _ ->
          body =
            %{
              "entity" => [
                alert_entity_data_1,
                alert_entity_data_2
              ]
            }

          Response.new(status: 200, body: body)
        end
      ]

      insert(:alert,
        alert_id: "123",
        last_modified_timestamp: ~U[2023-10-19 18:45:38Z],
        header_text: "old"
      )

      before_alerts_length = Alerts.list_all() |> length()

      AlertsIntake.run(opts)

      all_alerts = Alerts.list_all()
      assert length(all_alerts) - before_alerts_length == 1

      assert result_1 = Enum.find(all_alerts, &(&1.alert_id == "123"))
      assert result_1.last_modified_timestamp == ~U[2023-10-21 18:45:38Z]
      assert result_1.header_text == "new"
      assert Enum.find(all_alerts, &(&1.alert_id == "234"))
    end

    test "does nothing if incoming version is not more recent" do
      alert_entity_data_1 =
        :alert_entity_data
        |> build(%{"id" => "123"})
        |> last_modified(1_697_741_138)
        |> with_header_text("incoming")

      alert_entity_data_2 =
        :alert_entity_data
        |> build(%{"id" => "234"})
        |> last_modified(1_697_827_538)

      opts = [
        get_fn: fn _ ->
          body =
            %{
              "entity" => [
                alert_entity_data_1,
                alert_entity_data_2
              ]
            }

          Response.new(status: 200, body: body)
        end
      ]

      insert(:alert,
        alert_id: "123",
        last_modified_timestamp: ~U[2023-10-21 18:45:38Z],
        header_text: "original"
      )

      before_alerts_length = Alerts.list_all() |> length()

      AlertsIntake.run(opts)

      all_alerts = Alerts.list_all()

      assert length(all_alerts) - before_alerts_length == 1
      assert result_1 = Enum.find(all_alerts, &(&1.alert_id == "123"))
      assert result_1.last_modified_timestamp == ~U[2023-10-21 18:45:38Z]
      assert result_1.header_text == "original"
      assert Enum.find(all_alerts, &(&1.alert_id == "234"))
    end

    test "closes alerts that aren't in the feed" do
      alert_entity_data_1 = build(:alert_entity_data, %{"id" => "123"})

      alert_entity_data_2 = build(:alert_entity_data, %{"id" => "234"})

      opts = [
        get_fn: fn _ ->
          body =
            %{
              "entity" => [
                alert_entity_data_1,
                alert_entity_data_2
              ]
            }

          Response.new(status: 200, body: body)
        end
      ]

      insert(:alert, alert_id: "456")

      AlertsIntake.run(opts)

      updated_alert = Repo.get_by(Alert, alert_id: "456")
      assert !is_nil(updated_alert.closed_timestamp)
    end
  end
end
