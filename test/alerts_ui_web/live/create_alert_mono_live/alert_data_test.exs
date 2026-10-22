defmodule AlertsUIWeb.CreateAlertLive.AlertDataTest do
  use ExUnit.Case, async: false
  use AlertsUIWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AlertsUIWeb.CreateAlertLive.AlertData
  alias AlertsUIWeb.FormComponents.Helpers.TimeRangeDurationText

  describe "slices/1" do
    test "AC-1: slices/1 returns non-empty list when form is nil" do
      # Build a minimal socket-like map with no :form key (simulates socket
      # before the first AlertData.init call, when :form is not yet assigned)
      bare_socket = %{assigns: %{}}

      slices = AlertData.slices(bare_socket)

      refute Enum.empty?(slices), "slices/1 should return a non-empty list when form is nil"
      assert is_list(slices)
      refute Enum.empty?(slices)
    end
  end

  describe "init/4 and mount for :new action" do
    @tag :logged_in_user
    test "AC-2: active_period_start is a non-nil NaiveDateTime after mount", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      socket = :sys.get_state(view.pid).socket

      start = socket.assigns.form[:active_period_start].value

      assert %NaiveDateTime{} = start,
             "active_period_start should be a NaiveDateTime after mount, got: #{inspect(start)}"
    end

    @tag :logged_in_user
    test "active_period_end is a non-nil NaiveDateTime at ~T[03:00:00] after mount", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/alerts/new")
      socket = :sys.get_state(view.pid).socket

      end_dt = socket.assigns.form[:active_period_end].value

      assert %NaiveDateTime{} = end_dt,
             "active_period_end should be a NaiveDateTime after mount, got: #{inspect(end_dt)}"

      assert end_dt.hour == 03
      assert end_dt.minute == 00
      assert end_dt.second == 00
    end

    @tag :logged_in_user
    test "AC-4: Effect duration start text is non-empty on first load", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      socket = :sys.get_state(view.pid).socket
      form = socket.assigns.form

      # paramify_form mirrors what the TimeRangeSlice render function does
      params = %{
        "active_period_start" => form[:active_period_start].value,
        "active_period_end" => form[:active_period_end].value,
        "active_period_end_specifier" => form[:active_period_end_specifier].value
      }

      # When active_period_start is nil, get_start_text returns "". When non-nil, it
      # returns a formatted date string like "Thu May 15, 2026 @ 11:34 AM". We test
      # that the start phrase is not the empty sentinel (which indicates nil start).
      start_text = TimeRangeDurationText.get_start_text(params["active_period_start"])

      refute start_text == "",
             "Effect duration start text should be non-empty when datetimes are populated, got: #{inspect(start_text)}"
    end

    @tag :logged_in_user
    test "AC-5: sync/4 after init preserves non-nil datetimes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/alerts/new")
      socket = :sys.get_state(view.pid).socket

      # Simulate sync with empty URL params (no alert_data key), as handle_params calls
      changeset = socket.assigns.form.source

      {:ok, synced_socket} =
        AlertData.sync(changeset, socket, %{})
        |> case do
          {:ok, s} -> {:ok, s}
          {:error, s} -> {:ok, s}
        end

      start_after_sync = synced_socket.assigns.form[:active_period_start].value
      end_after_sync = synced_socket.assigns.form[:active_period_end].value

      assert %NaiveDateTime{} = start_after_sync,
             "active_period_start should remain non-nil after sync, got: #{inspect(start_after_sync)}"

      assert %NaiveDateTime{} = end_after_sync,
             "active_period_end should remain non-nil after sync, got: #{inspect(end_after_sync)}"
    end
  end
end
