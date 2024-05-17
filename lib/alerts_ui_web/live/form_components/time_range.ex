defmodule AlertsUIWeb.FormComponents.TimeRange do
  @moduledoc """
    Live Component for active period of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  AlertsUI.Models.ActivePeriod

  @end_values [
    :later_today,
    :end_of_service_today,
    :further_notice,
    :pick_a_date_and_time
  ]

  @primary_key false
  embedded_schema do
    field :active_period_start, :naive_datetime
    field :active_period_end_specifier, Ecto.Enum, values: @end_values
    field :active_period_end, :naive_datetime
  end

  @fields ~w[active_period_start active_period_end active_period_end_specifier]a

  @impl true
  def mount(socket) do
    form = %__MODULE__{} |> changeset() |> to_form()
    socket = assign(socket, %{form: form})
    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data} = assigns, socket) do
    assigns =
      if assigns.editing == false do
        assigns
      else
        active_period_end_specifier =
          case Map.get(alert_data, :active_period_end_specifier) do
            nil -> nil
            result -> Atom.to_string(result)
          end

        edit_alert_data =
          %{
            active_period_end: Map.get(alert_data, :active_period_end),
            active_period_start: Map.get(alert_data, :active_period_start),
            active_period_end_specifier: active_period_end_specifier
          }

        changeset =
          %__MODULE__{}
          |> changeset(edit_alert_data)

        form = to_form(changeset)
        edit_alert_data |> Map.put(:form, form) |> Map.merge(assigns)
      end

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("validate", %{"time_range" => time_range}, socket) do
    changeset =
      %__MODULE__{}
      |> changeset(time_range)

    changeset
    |> apply_action(:insert)
    |> case do
      {:ok, changeset} ->
        send(self(), {:section_completed, changeset})
        changeset

      {:error, changeset} ->
        changeset
    end

    {:noreply, assign(socket, %{form: to_form(changeset |> Map.put(:action, :validate))})}
  end

  def changeset(changeset, params \\ %{}) do
    cast(changeset, params, @fields)
  end

  @impl true
  def render(assigns) do
    current_time =
      NaiveDateTime.local_now() |> NaiveDateTime.truncate(:second) |> NaiveDateTime.to_iso8601()

    assigns = Map.put(assigns, :current_time, current_time)

    ~H"""
    <div
      class={unless @progress.name == "details", do: "hidden", else: "min-w-full flex flex-col mt-4"}
      id="time_range_view"
    >
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class="form-control gap-4"
        id="time_range_form"
      >
        <fieldset class="flex flex-row gap-12">
          <.input
            type="datetime-local"
            field={@form[:active_period_start]}
            min={@current_time}
            label="Start"
            class="min-w-[16rem]"
          />

          <.select
            label="End"
            field={@form[:active_period_end_specifier]}
            options={[
              {"later today", :later_today},
              {"end of service today", :end_of_service_today},
              {"futher notice", :further_notice},
              {"pick a date and time", :pick_a_date_and_time}
            ]}
            class="min-w-[16rem]"
          />
          <div
            id="end-selector-div"
            class={
              unless @form.params["active_period_end_specifier"] == "pick_a_date_and_time",
                do: "hidden"
            }
          >
            <.input
              id="end-selector"
              type="datetime-local"
              field={@form[:active_period_end]}
              min={@current_time}
              label="Select Ending"
              class="min-w-[16rem]"
            />
          </div>
        </fieldset>
      </.form>
    </div>
    """
  end
end
