defmodule AlertsUIWeb.ComponentsLive do
  @moduledoc """
  LiveView for presenting a style guide for our shared components.
  """
  use AlertsUIWeb, :live_view
  use AlertsUI.Schema

  import Ecto.Changeset
  import AlertsUIWeb.FilterForm

  @primary_key false
  embedded_schema do
    field :single_select, {:array, :integer}
    field :single_select_error, {:array, :integer}
    field :single_select_disabled, {:array, :integer}
    field :modal_filter, :string
    field :modal_filter_filter, :string
    field :filtered_select, {:array, :string}
    field :filtered_select_filter, :string
    field :filtered_select_filter_error, :string
    field :filtered_select_filter_disabled, :string
    field :filtered_select_error, {:array, :string}
    field :filtered_select_disabled, {:array, :string}
    field :text_input, :string
    field :text_input_disabled, :string
    field :text_input_error, :string
    field :textarea, :string
    field :textarea_disabled, :string
    field :textarea_error, :string
    field :textarea_counter, :string
    field :toggle_checkgroup, :string
    field :datetime, :string
    field :datetime_disabled, :string
    field :checkbox, :boolean
    field :checkbox_icon, :boolean
  end

  @fields ~w[single_select filtered_select text_input text_input_disabled textarea textarea_disabled textarea_counter single_select_error single_select_disabled datetime_disabled filtered_select_error filtered_select_disabled text_input_error textarea_error filtered_select_filter filtered_select_filter_error filtered_select_filter_disabled toggle_checkgroup datetime checkbox checkbox_icon modal_filter]a
  @errored_fields ~w[single_select_error filtered_select_error text_input_error textarea_error]a

  @impl true
  def mount(_params, _session, socket) do
    form =
      %__MODULE__{}
      |> changeset(%{modal_filter: "default"})
      |> Map.put(:action, :validate)
      |> to_form()

    current_time =
      DateTime.now!("America/New_York")
      |> DateTime.to_naive()
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.to_iso8601()

    {_alerts, meta} =
      AlertsUI.Alerts.list_all_paginated(%{
        order_by: [],
        filters: [
          %{"field" => "effects", "value" => ""},
          %{"field" => "routes", "value" => ""},
          %{"field" => "service_type", "value" => ""},
          %{"field" => "timeline", "value" => "current"},
          %{"field" => "multi_column_search", "value" => ""}
        ]
      })

    flop_form = Phoenix.Component.to_form(meta)

    {:ok,
     assign(socket, %{
       form: form,
       current_time: current_time,
       modal_filter_value: "default",
       flop_form: flop_form
     })}
  end

  @impl true
  def handle_event("create_bad_alerts", _, socket) do
    AlertsUI.Alerts.get_by_alert_id("1000535")
    |> AlertsUI.Models.Alert.changeset(%{
      original_route_selections: ["Orange Line|Orange", "Purple Line|Purple"],
      informed_entity: [
        %{
          route_id: "Orange",
          route_type: 1,
          activities: [
            :BOARD,
            :EXIT,
            :RIDE
          ],
          agency_id: "1"
        },
        %{
          route_id: "Purple",
          route_type: 1,
          activities: [
            :BOARD,
            :EXIT,
            :RIDE
          ],
          agency_id: "1"
        }
      ]
    })
    |> AlertsUI.Repo.update()

    AlertsUI.Alerts.get_by_alert_id("1000536")
    |> AlertsUI.Models.Alert.changeset(%{
      original_route_selections: ["Fairmount Line|CR-Fairmount", "Columbus Line|CR-Buckeyes"],
      informed_entity: [
        %{
          route_id: "Fairmount Line",
          route_type: 2,
          activities: [
            :BOARD,
            :EXIT,
            :RIDE
          ],
          agency_id: "1"
        },
        %{
          route_id: "CR-Buckeyes",
          route_type: 2,
          activities: [
            :BOARD,
            :EXIT,
            :RIDE
          ],
          agency_id: "1"
        }
      ]
    })
    |> AlertsUI.Repo.update()

    {:noreply, socket}
  end

  @impl true
  def handle_event("rerender", %{"components_live" => components_live}, socket) do
    form =
      %__MODULE__{}
      |> cast(components_live, @fields)
      |> to_form

    {:noreply, assign(socket, %{form: form})}
  end

  @impl true
  def handle_event("accepted_modal", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("accepted_filter_modal", _params, socket) do
    socket.assigns.form.params["modal_filter"]
    {:noreply, assign(socket, modal_filter_value: socket.assigns.form.params["modal_filter"])}
  end

  @impl true
  def handle_event("cancelled_modal", _params, socket) do
    {:noreply, socket}
  end

  @doc """
  Renders a color block with a label.

  ## Examples

      <.color_block name="mbta-bus" value="#ffc72c" />

  """
  attr :name, :string, required: true
  attr :class, :string, required: true

  def color_block(assigns) do
    ~H"""
    <div class="flex flex-col">
      <div class={"w-20 h-20 #{@class}"}></div>
      <div class="text-sm py-1">
        {@name}
      </div>
    </div>
    """
  end

  defp changeset(changeset, params) do
    changeset
    |> cast(params, @fields)
    |> add_errors()
  end

  defp add_errors(changeset) do
    Enum.reduce(@errored_fields, changeset, fn error_field, acc ->
      acc |> add_error(error_field, "Error in #{error_field} field!", on_purpose: :yes)
    end)
  end

  defp single_select_options do
    [
      One: "1",
      Two: "2",
      Three: "3",
      Four: "4",
      Five: "5",
      Six: "6",
      Seven: "7",
      Eight: "8",
      Nine: "9"
    ]
  end

  defp filtered_select_options(search_term, select_options) do
    select_options
    |> Enum.filter(fn {option, _value} ->
      option =
        if is_atom(option) do
          Atom.to_string(option)
        else
          option
        end

      option = String.downcase(option)

      case search_term do
        nil -> true
        "" -> true
        _ -> String.contains?(option, search_term)
      end
    end)
  end

  defp select_options do
    [
      {"Aardvark", "aardvark"},
      {"Agouti", "agouti"},
      {"Bilby", "bilby"},
      {"Binturong", "binturong"},
      {"Caracal", "caracal"},
      {"Coatimundi", "coatimundi"},
      {"Dhole", "dhole"},
      {"Duiker", "duiker"}
    ]
  end
end
