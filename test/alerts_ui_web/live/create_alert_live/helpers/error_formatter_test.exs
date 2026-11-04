defmodule AlertsUIWeb.CreateAlertLive.Helpers.ErrorFormatterTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUI.Models.Alert
  alias AlertsUIWeb.CreateAlertLive.Helpers.ErrorFormatter

  describe "parse_field_errors/1" do
    test "puts errors for fields in correct format from list" do
      error_list = [facility_ids: {"can't be blank", [validation: :required]}]
      result = ErrorFormatter.parse_field_errors(error_list)

      assert result == [facility_ids: {"Select facility", [validation: :required]}]
    end

    test "puts errors for fields in correct format from changeset" do
      changeset =
        Alert.changeset(%Alert{}, %{
          user: %{email: "a", first_name: "b", last_name: "c", roles: [:viewer]},
          active_period_start: DateTime.utc_now(),
          informed_entity: [%{route_id: "1"}]
        })

      result = ErrorFormatter.parse_field_errors(changeset)

      assert result == [header_text: {"Enter message text", []}]
    end

    test "puts errors for fields in correct format from error map" do
      errors = %{
        header_text: ["is required", "error_2"],
        informed_entity: ["should have at least 1 item(s)", "can't be blank"],
        other_field: ["error_1", "error_2"]
      }

      result = ErrorFormatter.parse_field_errors(errors, :RDTS) |> Enum.sort()

      assert result == [
               {:direction, {"Select direction", []}},
               {:header_text, {"Enter message text", []}},
               {:other_field, {"error_1, error_2", []}},
               {:route_ids, {"Select route(s)", []}},
               {:stop_ids, {"Select stop(s)", []}},
               {:trip_ids, {"Select trip(s)", []}}
             ]
    end

    test "handles multiple errors on the same field" do
      changeset =
        Alert.changeset(%Alert{}, %{
          user: %{email: "a", first_name: "b", last_name: "c", roles: [:viewer]},
          active_period_start: DateTime.utc_now(),
          informed_entity: [%{route_id: "1"}]
        })

      errors = [
        active_period_start_date: {"error_1", []},
        active_period_start_date: {"error_2", []}
      ]

      result = ErrorFormatter.parse_field_errors(%{changeset | errors: errors}) |> Enum.sort()

      assert result == [
               {:active_period_start_date, {"error_1", []}},
               {:active_period_start_date, {"error_2", []}}
             ]
    end
  end
end
