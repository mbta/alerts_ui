defmodule AlertsUIWeb.FormComponents.TimeRange do
  @moduledoc """
    Live Component for active period of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUI.Models.ActivePeriod
  alias AlertsUIWeb.FormComponents.Helpers.ErrorFormatter

  @alert_timing_dropdown_values [
    :"one-time",
    :scheduled
  ]

  @start_values [
    :now,
    :custom
  ]

  @end_values [
    :later_today,
    :end_of_service_today,
    :until_further_notice,
    :custom
  ]

  @primary_key false
  embedded_schema do
    field :alert_timing_dropdown, Ecto.Enum, values: @alert_timing_dropdown_values
    field :active_period_start, :naive_datetime
    field :active_period_start_specifier, Ecto.Enum, values: @start_values
    field :active_period_end_specifier, Ecto.Enum, values: @end_values
    field :active_period_end, :naive_datetime
    field :notification_period_start, :naive_datetime
  end

  @required_fields ~w[active_period_start]a
  @fields ~w[active_period_end active_period_end_specifier alert_timing_dropdown active_period_start_specifier notification_period_start]a ++
            @required_fields

  @impl true
  def mount(socket) do
    # set defaults

    alert_data = %{
      active_period_start:
        DateTime.now!("America/New_York") |> DateTime.to_naive() |> naive_datetime_to_iso8601(),
      active_period_end: end_of_service_datetime(),
      notification_period_start: ""
    }

    changeset = changeset(%__MODULE__{}, alert_data)

    changes =
      changeset
      |> apply_action!(:validate)

    send(self(), {:section_completed, changes})

    form = changeset |> to_form

    socket =
      assign(socket, %{
        form: form,
        current_time: current_time(),
        edited: false
      })

    {:ok, socket}
  end

  @impl true
  def update(%{editing: true, alert_data: alert_data} = assigns, socket) do
    assigns =
      if socket.assigns.edited === false do
        alert_data =
          if Map.get(alert_data, :notification_period_start) in [nil, ""] do
            alert_data
          else
            Map.put(alert_data, :alert_timing_dropdown, "scheduled")
          end
          |> Map.put(:active_period_start_specifier, "custom")
          |> Enum.filter(fn {_k, v} -> !is_nil(v) end)
          |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)

        changeset = changeset(%__MODULE__{}, Map.merge(socket.assigns.form.params, alert_data))

        changes =
          changeset
          |> apply_action!(:validate)

        send(self(), {:section_completed, changes})

        form = changeset |> to_form

        Map.merge(assigns, %{form: form, edited: true})
      else
        assigns
      end

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event(
        "validate",
        %{"time_range" => time_range},
        %{assigns: %{current_time: current_time, form: form}} = socket
      ) do
    # change end datetime based on dropdown selection or user entry
    end_datetime =
      case time_range["active_period_end_specifier"] do
        "later_today" ->
          end_of_service_datetime()

        "end_of_service_today" ->
          end_of_service_datetime()

        "until_further_notice" ->
          ""

        "custom" ->
          Map.get(time_range, "active_period_end", current_time_plus_2_hours(current_time))

        nil ->
          form.params["active_period_end"]
      end

    start_datetime = Map.get(time_range, "active_period_start", current_time)

    time_range =
      Map.merge(time_range, %{
        "active_period_start" => start_datetime,
        "active_period_end" => end_datetime
      })

    changeset =
      changeset(%__MODULE__{}, time_range)

    changeset =
      if changeset.valid? do
        validate_relationship(changeset, time_range, current_time)
      else
        changeset
      end

    changeset
    |> apply_action(:validate)
    |> case do
      {:ok, changeset} ->
        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changeset})

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
        send(self(), {:section_completed, changeset})
    end

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, %{form: form})}
  end

  def handle_event("alert_timing_dropdown_change", %{"time_range" => time_range}, socket) do
    time_range =
      if time_range["alert_timing_dropdown"] !== "scheduled" do
        Map.put(time_range, "notification_period_start", "")
      else
        time_range
      end

    time_range = Map.merge(socket.assigns.form.params, time_range)

    form =
      changeset(%__MODULE__{}, time_range)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, %{form: form})}
  end

  defp changeset(changeset, params) do
    custom_errors = [
      active_period_start: "Enter a valid datetime",
      active_period_end: "Enter a valid datetime",
      notification_period_start: "Enter a valid datetime"
    ]

    changeset
    |> cast(params, @fields,
      # empty_values: [""],
      message: fn field, _meta -> custom_errors[field] end
    )
    |> validate_required(@required_fields, message: "Enter a valid datetime")
  end

  @spec validate_relationship(Ecto.Changeset.t(), map(), DateTime.t()) :: Ecto.Changeset.t()
  def validate_relationship(changeset, time_range, current_time) do
    changeset
    |> validate_change(:active_period_start, fn :active_period_start, active_period_start ->
      validate_active_period_start(
        active_period_start,
        time_range["active_period_end"],
        current_time
      )
    end)
    |> validate_change(:active_period_end, fn :active_period_end, active_period_end ->
      validate_active_period_end(active_period_end, time_range["active_period_start"])
    end)
    |> validate_change(:notification_period_start, fn :notification_period_start,
                                                      notification_period_start ->
      validate_notification_period_start(
        notification_period_start,
        time_range["active_period_start"],
        time_range["active_period_end"]
      )
    end)
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        start_values: @start_values,
        end_values: @end_values,
        alert_timing_dropdown_values: @alert_timing_dropdown_values
      )

    ~H"""
    <div
      class={unless @progress.name == "details", do: "hidden", else: "min-w-full flex flex-col mt-4"}
      id="time_range_view"
    >
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Timeframe
      </.h5>
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class="form-control gap-4"
        id="time_range_form"
      >
        <fieldset class="">
          <.select
            label="Alert timing"
            field={@form[:alert_timing_dropdown]}
            options={values_to_options(@alert_timing_dropdown_values)}
            class="min-w-[16rem] max-w-[16rem]"
            phx-debounce={120}
            phx-change="alert_timing_dropdown_change"
            phx-target={@myself}
          />
          <div id="start-selector-div" class="flex flex-row gap-8 my-8">
            <.select
              label="Effect start"
              field={@form[:active_period_start_specifier]}
              options={values_to_options(@start_values)}
              class="min-w-[16rem] max-w-[16rem]"
              phx-debounce={120}
            />
            <.datetime
              field={@form[:active_period_start]}
              min={@current_time}
              max={@form[:active_period_end].value}
              value={@form[:active_period_start].value}
              label="Start time"
              class="min-w-[16rem] h-10"
              disabled={@form.params["active_period_start_specifier"] !== "custom"}
              phx-debounce={120}
            />
          </div>

          <div id="end-selector-div" class="flex flex-row gap-8 mb-8">
            <.select
              label="Effect end"
              field={@form[:active_period_end_specifier]}
              options={values_to_options(@end_values)}
              class="min-w-[16rem] max-w-[16rem]"
              phx-debounce={120}
            />
            <.datetime
              field={@form[:active_period_end]}
              min={@form[:active_period_start].value}
              value={@form[:active_period_end].value}
              label="End time"
              class="min-w-[16rem] h-10"
              disabled={@form.params["active_period_end_specifier"] !== "custom"}
              phx-debounce={120}
            />
          </div>
          <div
            :if={@form[:alert_timing_dropdown].value === :scheduled}
            id="scheduled-selector-div"
            class="flex flex-row gap-8 mb-8"
          >
            <.datetime
              label="Schedule alert for date and time"
              field={@form[:notification_period_start]}
              min={@form[:active_period_start].value}
              max={@form[:active_period_end].value}
              value={@form[:notification_period_start].value}
              class="min-w-[16rem] h-10"
              phx-debounce={120}
            />
          </div>
        </fieldset>
      </.form>
      <hr class="mt-8" />
    </div>
    """
  end

  defp validate_active_period_start(active_period_start, active_period_end, current_time) do
    {end_validity, end_time} = NaiveDateTime.from_iso8601(active_period_end)

    cond do
      NaiveDateTime.compare(
        active_period_start,
        NaiveDateTime.from_iso8601!(current_time)
      ) in [:lt] ->
        [
          active_period_start: {"Effect can't start in the past", []}
        ]

      end_validity === :ok &&
          NaiveDateTime.compare(
            active_period_start,
            end_time
          ) in [:gt] ->
        [
          active_period_start: {"Effect must start before #{formatted_datetime(end_time)}", []}
        ]

      true ->
        []
    end
  end

  defp validate_active_period_end(active_period_end, active_period_start) do
    start_time = NaiveDateTime.from_iso8601!(active_period_start)

    if NaiveDateTime.compare(
         active_period_end,
         start_time
       ) in [:lt] do
      [
        active_period_end: {"Effect must end after #{formatted_datetime(start_time)}", []}
      ]
    else
      []
    end
  end

  defp validate_notification_period_start(
         notification_period_start,
         active_period_start,
         active_period_end
       ) do
    start_time = NaiveDateTime.from_iso8601!(active_period_start)

    {end_validity, end_time} =
      NaiveDateTime.from_iso8601(active_period_end)

    cond do
      NaiveDateTime.compare(
        notification_period_start,
        start_time
      ) in [:lt] ->
        [
          notification_period_start:
            {"Effect must start after #{formatted_datetime(start_time)}", []}
        ]

      end_validity === :ok &&
          NaiveDateTime.compare(
            notification_period_start,
            end_time
          ) in [:gt] ->
        [
          notification_period_start:
            {"Effect must end before #{formatted_datetime(end_time)}", []}
        ]

      true ->
        []
    end
  end

  defp current_time,
    do: DateTime.now!("America/New_York") |> DateTime.to_naive() |> naive_datetime_to_iso8601()

  defp end_of_service_datetime do
    ActivePeriod.end_of_service_date(DateTime.now!("America/New_York"))
    |> NaiveDateTime.new!(ActivePeriod.end_of_service_time())
    |> naive_datetime_to_iso8601()
  end

  defp naive_datetime_to_iso8601(datetime),
    do: datetime |> NaiveDateTime.truncate(:second) |> NaiveDateTime.to_iso8601()

  defp values_to_options(values) do
    Enum.map(values, fn value ->
      name = value |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
      {name, value}
    end)
  end

  defp current_time_plus_2_hours(current_time) do
    NaiveDateTime.add(NaiveDateTime.from_iso8601!(current_time), 2, :hour)
    |> naive_datetime_to_iso8601()
  end

  defp formatted_datetime(datetime, format_string \\ "{0M}/{0D}/{YYYY}, {0h12}:{0m}:{0s} {AM}"),
    do: Timex.format!(datetime, format_string)
end
