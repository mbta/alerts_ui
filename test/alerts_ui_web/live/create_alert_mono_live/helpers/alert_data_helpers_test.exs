defmodule AlertsUIWeb.CreateAlertLive.Helpers.AlertDataHelpersTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AlertsUI.Models.Alert
  alias AlertsUIWeb.CreateAlertLive.AlertData, as: AlertDataSchema
  alias AlertsUIWeb.CreateAlertLive.Helpers.AlertDataHelpers

  # AlertDataHelpers.alert_data_from_form/2 and humanize_route_type/1 read via
  # Ecto.Changeset.get_field on form.source, so the form must wrap a changeset
  # (not a plain map). Other form helpers only read .value, so they're happy
  # with a map-backed form via map_form/1.
  defp changeset_form(attrs) do
    %AlertDataSchema{}
    |> Ecto.Changeset.change(attrs)
    |> Phoenix.Component.to_form()
  end

  defp map_form(params) do
    Phoenix.Component.to_form(params, as: :alert_data)
  end

  describe "alert_data_from_form/2 for :route_type" do
    test "returns the route_type as an existing atom" do
      # AlertData's :route_type is an :integer, but the helper calls
      # String.to_existing_atom on the value. We bypass the schema's type
      # by stashing a string directly on the struct, then wrapping it in a
      # changeset so get_field returns that raw string.
      f =
        %AlertDataSchema{route_type: "bus"}
        |> Ecto.Changeset.change()
        |> Phoenix.Component.to_form()

      assert AlertDataHelpers.alert_data_from_form(f, :route_type) == :bus
    end

    test "returns nil when route_type is not set" do
      assert AlertDataHelpers.alert_data_from_form(changeset_form(%{}), :route_type) == nil
    end
  end

  describe "alert_data_from_form/2 for arbitrary keys" do
    test "returns the field value from the form's source" do
      f = changeset_form(%{effect_name: "delay"})

      assert AlertDataHelpers.alert_data_from_form(f, :effect_name) == "delay"
    end
  end

  describe "show_details?/2" do
    test "returns true when effect_name is set" do
      changing_effect? = false

      assert AlertDataHelpers.show_details?(
               map_form(%{"effect_name" => "delay"}),
               changing_effect?
             ) == true
    end

    test "returns false when effect_name is nil" do
      changing_effect? = false

      assert AlertDataHelpers.show_details?(
               map_form(%{}),
               changing_effect?
             ) == false
    end

    test "returns false when effect_name is set but we are changing the effect" do
      changing_effect? = true

      assert AlertDataHelpers.show_details?(
               map_form(%{"effect_name" => "delay"}),
               changing_effect?
             ) == false
    end

    test "returns false when effect_name is not set and flag is active" do
      changing_effect? = false

      assert AlertDataHelpers.show_details?(
               map_form(%{}),
               changing_effect?
             ) == false
    end
  end

  describe "get_route_type/1" do
    test "returns nil for nil" do
      assert AlertDataHelpers.get_route_type(nil) == nil
    end

    test "returns nil for 'access'" do
      assert AlertDataHelpers.get_route_type("access") == nil
    end

    test "returns nil for 'systemwide'" do
      assert AlertDataHelpers.get_route_type("systemwide") == nil
    end

    test "returns the integer when given a numeric string" do
      assert AlertDataHelpers.get_route_type("3") == 3
    end

    test "extracts primary_service_type from an Alert struct" do
      assert AlertDataHelpers.get_route_type(%Alert{primary_service_type: "1"}) == 1
    end

    test "returns nil for an Alert whose primary_service_type is 'access'" do
      assert AlertDataHelpers.get_route_type(%Alert{primary_service_type: "access"}) == nil
    end
  end

  describe "list_effect_path_names/1" do
    test "returns path names for a binary route type" do
      result = AlertDataHelpers.list_effect_path_names("bus")

      assert "detour" in result
      assert "delay" in result
      refute "summary" in result
    end

    test "returns path names for an atom route type" do
      result = AlertDataHelpers.list_effect_path_names(:bus)

      assert "detour" in result
      assert "delay" in result
    end

    test "filters out the Summary effect" do
      result = AlertDataHelpers.list_effect_path_names(:facility)

      refute "summary" in result
    end

    test "returns an empty list for an unknown route type" do
      assert AlertDataHelpers.list_effect_path_names(:nonexistent_route_type) == []
    end
  end

  describe "humanize_effect_name/1 (form arg)" do
    test "returns the effect display name when form has route_type and effect_name" do
      f = map_form(%{"route_type" => 3, "effect_name" => "detour"})

      assert AlertDataHelpers.humanize_effect_name(f) == "Detour"
    end

    test "returns nil when the effect_name is unknown for the route_type" do
      f = map_form(%{"route_type" => 3, "effect_name" => "nonexistent_effect"})

      assert AlertDataHelpers.humanize_effect_name(f) == nil
    end
  end

  describe "humanize_effect_name/2" do
    test "returns nil for any non-nil route_type and a nil effect_name" do
      assert AlertDataHelpers.humanize_effect_name("bus", nil) == nil
      assert AlertDataHelpers.humanize_effect_name(3, nil) == nil
    end

    test "returns nil when both arguments are nil" do
      assert AlertDataHelpers.humanize_effect_name(nil, nil) == nil
    end

    test "returns nil when only the route_type is nil" do
      assert AlertDataHelpers.humanize_effect_name(nil, "detour") == nil
    end

    test "resolves a binary route_type to its display name" do
      assert AlertDataHelpers.humanize_effect_name("bus", "detour") == "Detour"
    end

    test "resolves an integer route_type to its display name" do
      assert AlertDataHelpers.humanize_effect_name(3, "detour") == "Detour"
    end

    test "returns nil when the effect_name is not in the mapping" do
      assert AlertDataHelpers.humanize_effect_name(:bus, "nonexistent_effect") == nil
    end
  end

  describe "humanize_route_type/1" do
    test "returns the service type label for a route type" do
      f = map_form(%{"route_type" => 3, "combination" => :RDS})

      assert AlertDataHelpers.humanize_route_type(f) == "Bus"
    end

    test "returns 'Facility' for an ACCESS combination" do
      f = map_form(%{"route_type" => nil, "combination" => :ACCESS})

      assert AlertDataHelpers.humanize_route_type(f) == "Facility"
    end

    test "returns 'Systemwide' when route_type and combination are nil" do
      f = map_form(%{"route_type" => nil, "combination" => nil})

      assert AlertDataHelpers.humanize_route_type(f) == "Systemwide"
    end
  end

  describe "get_single_route_effect_names/0" do
    test "returns the configured single-route effect list" do
      assert AlertDataHelpers.get_single_route_effect_names() == [
               "Detour",
               "Snow Route",
               "Station Bypass",
               "Dock Bypass"
             ]
    end
  end

  describe "get_single_facility_effect_names/0" do
    test "returns the configured single-facility effect list" do
      assert AlertDataHelpers.get_single_facility_effect_names() == [
               "Elevator Closure",
               "Escalator Closure"
             ]
    end
  end

  describe "clear_my_errors/2" do
    test "removes only the errors whose keys are fields of the given struct" do
      # AlertData schema has :alert_id and :route_type fields. We add errors for
      # one schema field and one unrelated field; only the schema field's error
      # should be cleared.
      changeset =
        %AlertDataSchema{}
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:alert_id, "is bad")
        |> Ecto.Changeset.add_error(:nonexistent_key, "still here")

      result = AlertDataHelpers.clear_my_errors(changeset, AlertDataSchema)

      assert Keyword.has_key?(result.errors, :alert_id) == false
      assert result.errors[:nonexistent_key] == {"still here", []}
    end
  end

  describe "put_over_nil/3" do
    test "sets the value when the key is nil" do
      assert AlertDataHelpers.put_over_nil(%{a: nil}, :a, 1) == %{a: 1}
    end

    test "sets the value when the key is missing" do
      assert AlertDataHelpers.put_over_nil(%{}, :a, 1) == %{a: 1}
    end

    test "preserves the existing value when non-nil" do
      assert AlertDataHelpers.put_over_nil(%{a: 2}, :a, 1) == %{a: 2}
    end

    test "preserves a falsy non-nil value (e.g., false)" do
      assert AlertDataHelpers.put_over_nil(%{a: false}, :a, true) == %{a: false}
    end
  end

  describe "values_to_options/1" do
    test "converts atom values into capitalized label/value pairs" do
      assert AlertDataHelpers.values_to_options([:one_time, :recurring]) == [
               {"One time", :one_time},
               {"Recurring", :recurring}
             ]
    end

    test "converts binary values into capitalized label/value pairs" do
      assert AlertDataHelpers.values_to_options(["one_time", "recurring"]) == [
               {"One time", "one_time"},
               {"Recurring", "recurring"}
             ]
    end
  end

  describe "display_alert_timing/1" do
    test "capitalizes a string timing" do
      assert AlertDataHelpers.display_alert_timing("one-time") == "One-time"
    end

    test "converts an atom to a string and capitalizes it" do
      assert AlertDataHelpers.display_alert_timing(:recurring) == "Recurring"
    end
  end

  describe "filter_empty_list_fields/1" do
    test "removes keys whose values are empty lists" do
      input = %{a: [], b: [1], c: "x"}

      assert AlertDataHelpers.filter_empty_list_fields(input) == %{b: [1], c: "x"}
    end

    test "returns an empty map when every list field is empty" do
      assert AlertDataHelpers.filter_empty_list_fields(%{a: [], b: []}) == %{}
    end

    test "leaves non-list values alone" do
      assert AlertDataHelpers.filter_empty_list_fields(%{a: nil, b: 0, c: "x"}) == %{
               a: nil,
               b: 0,
               c: "x"
             }
    end
  end
end
