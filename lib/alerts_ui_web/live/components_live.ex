defmodule AlertsUIWeb.ComponentsLive do
  @moduledoc """
  LiveView for presenting a style guide for our shared components.
  """
  use AlertsUIWeb, :live_view
  use AlertsUI.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :single_select, {:array, :integer}
    field :single_select_error, {:array, :integer}
    field :single_select_disabled, {:array, :integer}
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

  @fields ~w[single_select filtered_select text_input text_input_disabled textarea textarea_disabled textarea_counter single_select_error single_select_disabled datetime_disabled filtered_select_error filtered_select_disabled text_input_error textarea_error filtered_select_filter filtered_select_filter_error filtered_select_filter_disabled toggle_checkgroup  datetime checkbox checkbox_icon]a
  @errored_fields ~w[single_select_error filtered_select_error text_input_error textarea_error]a

  @impl true
  def mount(_params, _session, socket) do
    form =
      %__MODULE__{}
      |> changeset(%{})
      |> Map.put(:action, :validate)
      |> to_form()

    current_time =
      DateTime.now!("America/New_York")
      |> DateTime.to_naive()
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.to_iso8601()

    {:ok, assign(socket, %{form: form, current_time: current_time})}
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
  def handle_event("cancelled_modal", _params, socket) do
    {:noreply, socket}
  end

  @doc """
  Renders a color block with a label.

  ## Examples

      <.color_block name="mbta-bus" value="#ffc72c" />

  """
  attr :name, :string, required: true
  attr :value, :string, required: true

  def color_block(assigns) do
    ~H"""
    <div class="flex flex-col">
      <div class="w-20 h-20" style={"background-color: #{@value}"}></div>
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

  defp filtered_select_options(filter_value) do
    select_options()
    |> Enum.filter(fn {option, _value} ->
      option = String.downcase(option || "")

      case filter_value do
        nil -> true
        "" -> true
        _ -> String.contains?(option, filter_value)
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
