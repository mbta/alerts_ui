defmodule AlertsUIWeb.Tickets.AutoRefreshRepopulatesAfterClearTest do
  @moduledoc """
  Regression test for Asana ticket 1213454845351518 —
  "🐛 Auto refresh should work even if all text has been deleted"
  https://app.asana.com/0/1167196461144361/1213454845351518

  Bug: after a user deleted all text from the Main message textarea, clicking
  "Auto refresh" did not repopulate the field. The toggle was unchecked (false)
  after the deletion, but re-checking it failed to regenerate auto-text.

  The fix ensures that when `header_sync_toggle` is re-checked (target =
  "header_sync_toggle") and its submitted value is `true`, the `transform/4`
  function honours the new toggle state and regenerates auto-text even when
  `header_text` is currently empty.

  This test pins the behaviour at the `AlertDetailsSlice.Slice.transform/4`
  level:

    Step 1 — delete all text (target = "header_text"):
      header_sync_toggle collapses to `false`, header_text stays "".

    Step 2 — re-check Auto refresh (target = "header_sync_toggle", value = true):
      header_sync_toggle must become `true`, and header_text must be
      non-empty (regenerated auto-text for commuter_rail + delay context).
  """
  use ExUnit.Case, async: true

  import Ecto.Changeset

  alias AlertsUIWeb.CreateAlertMonoLive.AlertData
  alias AlertsUIWeb.CreateAlertMonoLive.Slice
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.AffectedServiceSlice
  alias AlertsUIWeb.CreateAlertMonoLive.Slices.AlertDetailsSlice

  # Minimal socket stub — AlertDetailsSlice.transform/4 needs:
  #   assigns.submitted?  (to decide whether to recalculate autotext on submit)
  #   assigns.selections  (for selected routes/stops; empty here = unspecified alert)
  defp stub_socket(opts \\ []) do
    %{
      assigns: %{
        submitted?: Keyword.get(opts, :submitted?, false),
        selections:
          Keyword.get(
            opts,
            :selections,
            %AffectedServiceSlice.Selections{available_routes: [], available_stops: []}
          )
      }
    }
  end

  # Build a changeset representing the AlertData state after auto-text was
  # seeded on page load (toggle on, header_text populated with commuter rail delay text).
  defp seeded_changeset do
    # The autotext engine builds "operating about 10 minutes behind schedule."
    # for commuter_rail + delay; we use a representative string to stand in for
    # whatever the engine generates — what matters is that it is non-empty.
    initial_header = "operating about 10 minutes behind schedule."

    cast(
      %AlertData{
        effect_name: "delay",
        route_type: 2,
        header_text: initial_header,
        header_sync_toggle: true
      },
      %{
        "effect_name" => "delay",
        "route_type" => 2,
        "header_text" => initial_header,
        "header_sync_toggle" => "true"
      },
      [:effect_name, :route_type, :header_text, :header_sync_toggle]
    )
  end

  describe "AlertDetailsSlice.transform/4 (ticket 1213454845351518)" do
    test "Step 1: deleting all text turns the sync toggle off and clears header_text" do
      # Start: seeded state with toggle on and text in place.
      changeset = seeded_changeset()
      socket = stub_socket()

      # Simulate phx-change with target = ["alert_data", "header_text"], value = "".
      # This is what fires when the user deletes all content and the textarea debounce fires.
      after_clear_changeset =
        changeset
        |> cast(%{"header_text" => "", "header_sync_toggle" => "false"}, [
          :header_text,
          :header_sync_toggle
        ])

      result =
        Slice.transform(
          %AlertDetailsSlice{
            effect_name: "delay",
            route_type: 2,
            header_text: "",
            header_sync_toggle: false
          },
          after_clear_changeset,
          %{"_target" => ["alert_data", "header_text"], "alert_data" => %{"header_text" => ""}},
          socket
        )

      assert get_field(result, :header_sync_toggle) == false,
             "editing header_text when toggle was on must turn it off"

      assert get_field(result, :header_text) == "",
             "cleared header_text must stay empty"
    end

    test "Step 2: re-checking Auto refresh on an empty field regenerates auto-text" do
      # Precondition: we are in the post-clear state (toggle=false, header_text="").
      cleared_changeset =
        cast(
          %AlertData{
            effect_name: "delay",
            route_type: 2,
            header_text: "",
            header_sync_toggle: false
          },
          %{
            "effect_name" => "delay",
            "route_type" => 2,
            "header_text" => "",
            "header_sync_toggle" => "false"
          },
          [:effect_name, :route_type, :header_text, :header_sync_toggle]
        )

      socket = stub_socket()

      # Simulate phx-change with target = ["alert_data", "header_sync_toggle"], value = "true".
      # This fires when the user clicks the "Auto refresh" label/checkbox.
      result =
        Slice.transform(
          %AlertDetailsSlice{
            effect_name: "delay",
            route_type: 2,
            header_text: "",
            # the cast value after checkbox is checked
            header_sync_toggle: true
          },
          cast(cleared_changeset, %{"header_sync_toggle" => "true"}, [:header_sync_toggle]),
          %{
            "_target" => ["alert_data", "header_sync_toggle"],
            "alert_data" => %{"header_sync_toggle" => "true"}
          },
          socket
        )

      assert get_field(result, :header_sync_toggle) == true,
             "re-checking Auto refresh must set the toggle to true"

      header = get_field(result, :header_text)

      refute is_nil(header),
             "header_text must be non-nil after re-checking Auto refresh"

      refute String.trim(header) == "",
             "header_text must be non-empty (auto-text regenerated) after re-checking Auto refresh; got: #{inspect(header)}"
    end

    test "the full sequence: seed → clear → re-check Auto refresh repopulates" do
      socket = stub_socket()

      # Phase A: page load — toggle true, header_text seeded via auto-text
      seed_params = %{
        "_target" => [nil, nil],
        "alert_data" => %{"effect_name" => "delay", "route_type" => "2"}
      }

      seed_result =
        Slice.transform(
          %AlertDetailsSlice{
            effect_name: "delay",
            route_type: 2,
            header_text: "",
            header_sync_toggle: true
          },
          cast(
            %AlertData{effect_name: "delay", route_type: 2, header_sync_toggle: true},
            %{"header_sync_toggle" => "true"},
            [:header_sync_toggle]
          ),
          seed_params,
          socket
        )

      seeded_text = get_field(seed_result, :header_text)

      assert seeded_text not in [nil, ""],
             "auto-text should be seeded on load; got: #{inspect(seeded_text)}"

      # Phase B: user deletes all text — phx-change fires with target=header_text, value=""
      after_delete_slice = %AlertDetailsSlice{
        effect_name: "delay",
        route_type: 2,
        header_text: "",
        header_sync_toggle: false
      }

      after_delete_changeset =
        cast(
          %AlertData{effect_name: "delay", route_type: 2, header_sync_toggle: false},
          %{"header_text" => "", "header_sync_toggle" => "false"},
          [:header_text, :header_sync_toggle]
        )

      delete_result =
        Slice.transform(
          after_delete_slice,
          after_delete_changeset,
          %{
            "_target" => ["alert_data", "header_text"],
            "alert_data" => %{"header_text" => ""}
          },
          socket
        )

      assert get_field(delete_result, :header_sync_toggle) == false,
             "toggle must be off after deletion"

      assert get_field(delete_result, :header_text) == "",
             "header_text must be empty after deletion"

      # Phase C: user clicks "Auto refresh" — phx-change fires with target=header_sync_toggle, value="true"
      retoggle_slice = %AlertDetailsSlice{
        effect_name: "delay",
        route_type: 2,
        header_text: "",
        # the new value after checkbox is checked
        header_sync_toggle: true
      }

      retoggle_changeset =
        cast(
          %AlertData{effect_name: "delay", route_type: 2, header_sync_toggle: true},
          %{"header_sync_toggle" => "true", "header_text" => ""},
          [:header_sync_toggle, :header_text]
        )

      retoggle_result =
        Slice.transform(
          retoggle_slice,
          retoggle_changeset,
          %{
            "_target" => ["alert_data", "header_sync_toggle"],
            "alert_data" => %{"header_sync_toggle" => "true"}
          },
          socket
        )

      assert get_field(retoggle_result, :header_sync_toggle) == true,
             "toggle must be on after re-checking Auto refresh"

      final_text = get_field(retoggle_result, :header_text)

      refute final_text in [nil, ""],
             "header_text must be repopulated after re-checking Auto refresh on an empty field; got: #{inspect(final_text)}"
    end
  end
end
