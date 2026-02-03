defmodule AlertsUIWeb.DBPageLiveTest do
  use AlertsUIWeb.ConnCase

  import AlertsUI.Support.Factory
  import Phoenix.LiveViewTest

  describe "role based access" do
    setup do
      insert(:alert, %{
        alert_id: "123",
        active_period: [
          build(:active_period, %{start: ~U[2023-10-12 00:01:00Z]}),
          build(:active_period, %{start: ~U[2023-10-13 00:01:00Z]})
        ],
        active_period_start: ~U[2023-10-12 00:01:00Z],
        duration_certainty: :UNKNOWN,
        header_text: "this is the first alert",
        effect_detail: "DETOUR",
        original_route_selections: ["1", "2"],
        closed_timestamp: ~U[2024-10-12 00:01:00Z]
      })

      :ok
    end

    @tag :logged_in_user
    test "author-developers can delete alerts", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/db")
      assert view |> has_element?("button", "Delete")
    end

    @tag :logged_in_developer
    test "non-authors cannot delete alerts", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/db")
      refute view |> has_element?("button", "Delete")
    end
  end
end
