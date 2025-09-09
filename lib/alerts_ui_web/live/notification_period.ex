defmodule AlertsUIWeb.FormComponents.NotificationPeriod do
  @moduledoc """
    Live Component for notification period of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUI.Models.ActivePeriod

  alias AlertsUIWeb.FormComponents.Helpers.{
    DateTimeHelpers,
    ErrorFormatter,
    TimeRangeValidators
  }

  @notification_values [
    :same_as_effect_period,
    :now,
    :start_of_service,
    :custom
  ]

  @primary_key false
  embedded_schema do
    field :notification_specifier, Ecto.Enum,
      values: @notification_values,
      default: :same_as_effect_period

    field :notification_period_start, :naive_datetime
    field :notification_period_start_date, :date
  end

  @fields ~w[notification_period_start notification_specifier notification_period_start_date]a

  @impl true
  def mount(socket) do
    current_time = DateTimeHelpers.current_time()

    alert_data = %{
      notification_period_start_date: current_time |> naive_datetime_to_iso_date
    }

    form = changeset(%__MODULE__{}, alert_data) |> to_form

    socket =
      assign(socket, %{
        form: form,
        current_time: current_time,
        edited: false
      })

    {:ok, socket}
  end

  @impl true
  def update(%{editing: true, alert_data: alert_data} = assigns, socket) do
    assigns =
      if socket.assigns.edited === false do
        alert_data =
          alert_data
          |> Enum.filter(fn {_k, v} -> !is_nil(v) end)
          |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)

        Map.merge(socket.assigns.form.params, alert_data)

        Map.merge(assigns, %{edited: true, alert_data: alert_data})
      else
        assigns
      end
      |> Map.put(
        :time_range,
        Map.take(alert_data, [
          :active_period_start,
          :active_period_start_time,
          :active_period_start_date,
          :alert_timing
        ])
      )

    changeset =
      %__MODULE__{}
      |> changeset(alert_data)

    changeset
    |> apply_action(:validate)
    |> case do
      {:ok, changes} ->
        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changes})

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
    end

    form = changeset |> to_form

    {:ok, assign(socket, assigns |> Map.put(:form, form))}
  end

  @impl true
  def update(%{submitted: true}, socket) do
    current_time = DateTimeHelpers.current_time()

    changeset =
      %__MODULE__{}
      |> changeset(socket.assigns.form.params)
      |> TimeRangeValidators.validate_notification(
        socket.assigns.time_range,
        current_time,
        socket.assigns.editing
      )
      |> TimeRangeValidators.validate_required_notification_fields(socket.assigns.form.params)

    errors =
      case changeset |> apply_action(:validate) do
        {:ok, _changeset} -> []
        {:error, changeset} -> ErrorFormatter.parse_field_errors(changeset)
      end

    form =
      changeset
      |> to_form()
      |> Map.put(:action, :validate)
      |> Map.put(:errors, errors)

    socket = assign(socket, form: form, current_time: current_time)

    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data} = assigns, socket) do
    assigns =
      assigns
      |> Map.put(
        :time_range,
        Map.take(alert_data, [
          :active_period_start,
          :active_period_start_time,
          :active_period_start_date,
          :alert_timing
        ])
      )

    # we need to revalidate here so we can apply/clear new errors
    # based on validating against new timerange information
    changeset =
      changeset(%__MODULE__{}, socket.assigns.form.params)
      |> TimeRangeValidators.validate_notification(
        assigns.time_range,
        socket.assigns.current_time
      )

    changeset
    |> apply_action(:validate)
    |> case do
      {:ok, changes} ->
        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changes})

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
    end

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    socket = socket |> assign(assigns) |> assign(form: form)
    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"notification_period" => notification_period}, socket) do
    notification_period = Map.merge(socket.assigns.form.params, notification_period)

    notification_period_start = notification_period_start(notification_period, socket.assigns)

    notification_period =
      Map.put(notification_period, "notification_period_start", notification_period_start)

    changeset =
      changeset(%__MODULE__{}, notification_period)

    changeset =
      if changeset.valid? do
        changeset
        |> TimeRangeValidators.validate_notification(
          socket.assigns.time_range,
          socket.assigns.current_time
        )
        |> TimeRangeValidators.validate_required_notification_fields(notification_period)
      else
        changeset
      end

    changeset
    |> apply_action(:validate)
    |> case do
      {:ok, changes} ->
        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changes})

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
    end

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, %{form: form})}
  end

  def notification_period_start(notification_period, assigns) do
    previous_state = assigns.form.params["notification_specifier"]

    case notification_period["notification_specifier"] do
      "same_as_effect_period" ->
        nil

      "now" ->
        assigns.current_time

      "start_of_service" ->
        if notification_period["notification_period_start_date"] in ["", nil] do
          nil
        else
          NaiveDateTime.new!(
            notification_period["notification_period_start_date"] |> Date.from_iso8601!(),
            ActivePeriod.start_of_service_time()
          )
        end

      "custom" ->
        if previous_state in ["custom", :custom] do
          notification_period["notification_period_start"]
        else
          assigns.current_time
        end
    end
  end

  defp changeset(changeset, params) do
    custom_errors = [
      notification_period_start: "Enter a valid date and time"
    ]

    changeset
    |> cast(params, @fields, message: fn field, _meta -> custom_errors[field] end)
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        notification_values: @notification_values
      )

    ~H"""
    <div class="min-w-full flex flex-col mt-4" id="notification_period_view">
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class="form-control gap-4"
        id="notification_period_form"
      >
        <div id="scheduled-selector-div" class="flex flex-row gap-8 my-8">
          <.select
            label="Notification period"
            field={@form[:notification_specifier]}
            options={values_to_options(@notification_values)}
            class="min-w-[16rem] h-10"
            phx-debounce={120}
          />
          <.datetime
            :if={@form[:notification_specifier].value === :start_of_service}
            type="date"
            label=""
            field={@form[:notification_period_start_date]}
            min={@current_time |> naive_datetime_to_iso_date}
            max={
              [naive_datetime_to_iso_date(@form[:active_period_start].value), "9999-12-31"]
              |> Enum.max()
            }
            value={@form[:notification_period_start_date].value}
            class="min-w-[16rem] max-w-[16rem] h-10"
            phx-debounce={120}
          />
          <.datetime
            :if={@form[:notification_specifier].value === :custom}
            label=""
            field={@form[:notification_period_start]}
            min={@form[:active_period_start].value |> naive_datetime_to_iso8601}
            max={
              [naive_datetime_to_iso_date(@form[:active_period_end].value), "9999-12-31T23:59"]
              |> Enum.max()
            }
            value={@form[:notification_period_start].value |> naive_datetime_to_iso8601}
            class="min-w-[16rem] max-w-[16rem] h-10"
            phx-debounce={120}
          />
          <div
            :if={
              @form[:notification_specifier].value not in [
                :same_as_effect_period,
                "same_as_effect_period"
              ]
            }
            class="flex flex-row"
          >
            <p class="pt-[2rem] mr-[2rem]">
              to
            </p>
            <input
              disabled={true}
              type="text"
              id="closed-placeholder"
              value="When alert is closed"
              placeholder="When alert is closed"
              class="border border-bg-elevation-6 pl-2
                  rounded text-text-secondary
                  bg-bg-elevation-3 ring-0  ring-border-focus
                  mt-[1.75rem] h-10 min-w-[16rem]"
            />
          </div>
        </div>
      </.form>
      <hr class="mt-8" />
    </div>
    """
  end

  def naive_datetime_to_iso_date(%NaiveDateTime{} = datetime),
    do: datetime |> NaiveDateTime.to_date() |> Date.to_iso8601()

  def naive_datetime_to_iso_date(_), do: ""

  defp naive_datetime_to_iso8601(%NaiveDateTime{} = datetime),
    do:
      datetime
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.to_iso8601()
      |> String.slice(0..-4//1)

  defp naive_datetime_to_iso8601(_), do: ""

  defp values_to_options(values) do
    Enum.map(values, fn value ->
      name = value |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
      {name, value}
    end)
  end
end
