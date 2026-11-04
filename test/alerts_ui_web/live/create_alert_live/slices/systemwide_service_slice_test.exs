defmodule AlertsUIWeb.CreateAlertLive.Slices.SystemwideServiceSliceTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase
  import AlertsUI.Support.Factory
  import Ecto.Changeset
  import Phoenix.LiveViewTest
  import Test.Support.Helpers

  alias AlertsUI.Alerts
  alias AlertsUIWeb.CreateAlertLive.AlertData
  alias AlertsUIWeb.CreateAlertLive.Slice
  alias AlertsUIWeb.CreateAlertLive.Slices.SystemwideServiceSlice

  describe "component" do
    @tag :logged_in_user
    test "renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Systemwide", "Notice")

      assert render(view) =~ ~s(id="systemwide_service_view")
      assert render(view) =~ "Service types"
    end

    @tag :logged_in_user
    test "shows an error if no service type selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Systemwide", "Notice")

      view |> element("button#review", "Review and submit") |> render_click()

      assert render(view) =~ "Please fix the following errors:"
      assert render(view) =~ "Select a service type"
    end

    @tag :logged_in_user
    test "no error when service type is selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Systemwide", "Notice")

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"service_types" => ["3"]}})

      view |> element("button#review", "Review and submit") |> render_click()

      refute render(view) =~ "Select a service type"
    end

    @tag :logged_in_user
    test "renders correctly while editing", %{conn: conn} do
      alert_params =
        build(:alert_map, %{
          alert_id: "test-systemwide-edit",
          effect: :OTHER_EFFECT,
          effect_detail: "NOTICE",
          primary_service_type: "systemwide",
          service_types: [1]
        })

      {:ok, _} = Alerts.create_or_update_alert(alert_params, build(:user))
      {:ok, view, _html} = live(conn, "/alerts/edit/test-systemwide-edit")

      assert render(view) =~ ~s(value="1")
    end

    @tag :logged_in_user
    test "service type checkbox is shown as checked after selecting it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Systemwide", "Notice")

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"service_types" => ["1"]}})

      {:ok, document} = view |> render() |> Floki.parse_document()

      assert document_has_element?(document, "input#service-type-subway[checked]")
    end

    @tag :logged_in_user
    test "invalid service type string is rejected on submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Systemwide", "Notice")

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"service_types" => ["a"]}})

      view |> element("button#review", "Review and submit") |> render_click()

      assert render(view) =~ "Select a service type"
    end

    @tag :logged_in_user
    test "string service type values are cast to integers and shown as checked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      view = get_to_submission_page(conn, view, "Systemwide", "Notice")

      view
      |> element("form")
      |> render_change(%{"alert_data" => %{"service_types" => ["1"]}})

      {:ok, document} = view |> render() |> Floki.parse_document()

      assert document_has_element?(document, "input#service-type-subway[checked]")
    end
  end

  describe "Slice.transform/4" do
    test "is a pass-through (conversion handled by Ecto cast)" do
      changeset = change(%AlertData{}, service_types: [3])

      result =
        Slice.transform(
          %SystemwideServiceSlice{service_types: [3]},
          changeset,
          %{},
          %Phoenix.LiveView.Socket{}
        )

      assert result == changeset
    end
  end
end
