defmodule AlertsUIWeb.FormComponents.TimeRange do
  @moduledoc """
    Live Component for active period of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  alias AlertsUI.Models.ActivePeriod

  @start_values [
    :now,
    :custom
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
    field :active_period_start, :naive_datetime
    field :start_time, :time
    field :start_date, :date
    field :active_period_start_specifier, Ecto.Enum, values: @start_values
    field :active_period_end_specifier, Ecto.Enum, values: @end_values
    field :end_time, :time
    field :end_date, :date
    field :active_period_end, :naive_datetime
  end

  @fields ~w[active_period_start active_period_end active_period_end_specifier active_period_start_specifier start_time start_date end_time end_date]a

  @impl true
  def mount(socket) do
    form = %__MODULE__{} |> changeset() |> to_form()

    socket =
      assign(socket, %{
        form: form,
        current_time: Map.get(socket.assigns, :current_time) || current_time()
      })

    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data} = assigns, socket) do
    # set defaults if no values provided from editing data
    active_period_start =
      Map.get(
        alert_data,
        :active_period_start,
        DateTime.now!("America/New_York") |> DateTime.to_naive()
      )
      |> naive_datetime_to_iso8601()

    active_period_end_specifier =
      Map.get(alert_data, :active_period_end_specifier, :later_today) |> Atom.to_string()

    active_period_end =
      case Map.get(alert_data, :active_period_end) do
        nil ->
          if active_period_end_specifier in ["later_today", "end_of_service_today"] do
            end_of_service_datetime()
          else
            ""
          end

        result ->
          result |> naive_datetime_to_iso8601()
      end

    active_period_start_specifier =
      case Map.get(alert_data, :active_period_start_specifier) do
        nil -> nil
        result -> Atom.to_string(result)
      end

    default_alert_data =
      %{
        active_period_start: active_period_start,
        active_period_end: active_period_end,
        active_period_end_specifier: active_period_end_specifier,
        active_period_start_specifier: active_period_start_specifier
      }

    changeset =
      %__MODULE__{}
      |> changeset(default_alert_data)

    send(self(), {:section_completed, changeset})
    form = to_form(changeset)

    assigns =
      default_alert_data
      |> Map.merge(%{form: form})
      |> Map.merge(assigns)

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
          if time_range["end_date"] && time_range["end_time"] do
            "#{time_range["end_date"]}T#{time_range["end_time"]}:00"
          else
            current_time_plus_2_hours(current_time)
          end

        nil ->
          form.params["active_period_end"]
      end

    # change start datetime based on user entry
    start_datetime =
      if time_range["start_date"] && time_range["start_time"] do
        "#{time_range["start_date"]}T#{time_range["start_time"]}:00"
      else
        current_time
      end

    time_range =
      Map.merge(time_range, %{
        "active_period_start" => start_datetime,
        "active_period_end" => end_datetime
      })

    changeset =
      %__MODULE__{}
      |> changeset(time_range)
      |> validate_and_add_errors(time_range, current_time)

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

  defp changeset(changeset, params \\ %{}) do
    cast(changeset, params, @fields)
  end

  def validate_and_add_errors(changeset, time_range, current_time) do
    changeset
    |> validate_change(:active_period_start, fn :active_period_start, active_period_start ->
      with {:ok, _} <- NaiveDateTime.from_iso8601(time_range["active_period_start"]),
           true <-
             NaiveDateTime.compare(
               active_period_start,
               NaiveDateTime.from_iso8601!(current_time)
             ) in [:eq, :gt] do
        []
      else
        {:error, _} ->
          []

        false ->
          [
            start_time: {"time must be in future", []},
            start_date: {"date must be in future", []}
          ]
      end
    end)
    |> validate_change(:active_period_end, fn :active_period_end, active_period_end ->
      with {:ok, _} <- NaiveDateTime.from_iso8601(time_range["active_period_end"]),
           {:ok, _} <- NaiveDateTime.from_iso8601(time_range["active_period_start"]),
           true <-
             NaiveDateTime.compare(
               active_period_end,
               NaiveDateTime.from_iso8601!(time_range["active_period_start"])
             ) in [:eq, :gt] do
        []
      else
        {:error, _} ->
          []

        false ->
          [
            end_time: {"time must be after start", []},
            end_date: {"date must be after start", []}
          ]
      end
    end)
    |> then(fn changeset ->
      Enum.reduce(
        [
          {:active_period_start, :start_date, :start_time},
          {:active_period_end, :end_date, :end_time}
        ],
        changeset,
        fn {datetime_field, date_field, time_field}, acc ->
          with true <- Keyword.has_key?(changeset.errors, datetime_field),
               {"is invalid", _} <- Keyword.get(changeset.errors, datetime_field) do
            acc
            |> add_error(time_field, "Please enter valid time", on_purpose: :yes)
            |> add_error(date_field, "Please enter valid date", on_purpose: :yes)
          else
            _ -> acc
          end
        end
      )
    end)
  end

  @impl true
  def render(assigns) do
    start_datetime =
      if assigns.form.params["active_period_start"] in [nil, ""] do
        assigns.current_time
      else
        assigns.form.params["active_period_start"]
      end

    end_datetime =
      if assigns.form.params["active_period_end"] in [nil] do
        assigns.current_time
      else
        assigns.form.params["active_period_end"]
      end

    assigns =
      assign(assigns,
        start_values: @start_values,
        end_values: @end_values,
        start_datetime: start_datetime,
        end_datetime: end_datetime
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
          <div id="start-selector-div" class="flex flex-row gap-8 mb-8">
            <.select
              label="Effect start"
              field={@form[:active_period_start_specifier]}
              options={values_to_options(@start_values)}
              class="min-w-[16rem] max-w-[16rem]"
              phx-debounce={120}
            />
            <.datetime
              field={@form[:start_date]}
              min={date_from_iso(@current_time)}
              value={date_from_iso(@start_datetime)}
              label="Start date"
              class="min-w-[16rem]"
              disabled={@form.params["active_period_start_specifier"] !== "custom"}
              type="date"
              phx-debounce={120}
            />
            <.datetime
              field={@form[:start_time]}
              value={time_from_iso(@start_datetime)}
              label="Start time"
              class="min-w-[16rem]"
              disabled={@form.params["active_period_start_specifier"] !== "custom"}
              type="time"
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
              field={@form[:end_date]}
              min={date_from_iso(@current_time)}
              value={date_from_iso(@end_datetime)}
              label="End date"
              class="min-w-[16rem]"
              disabled={@form.params["active_period_end_specifier"] !== "custom"}
              type="date"
              phx-debounce={120}
            />
            <.datetime
              field={@form[:end_time]}
              value={time_from_iso(@end_datetime)}
              label="End time"
              class="min-w-[16rem]"
              disabled={@form.params["active_period_end_specifier"] !== "custom"}
              type="time"
              phx-debounce={120}
            />
          </div>
        </fieldset>
      </.form>
      <hr class="mt-8" />
    </div>
    """
  end

  defp current_time,
    do: DateTime.now!("America/New_York") |> DateTime.to_naive() |> naive_datetime_to_iso8601()

  defp end_of_service_datetime do
    ActivePeriod.end_of_service_date(DateTime.now!("America/New_York"))
    |> NaiveDateTime.new!(ActivePeriod.end_of_service_time())
    |> naive_datetime_to_iso8601()
  end

  defp naive_datetime_to_iso8601(nil), do: ""

  defp naive_datetime_to_iso8601(datetime),
    do: datetime |> NaiveDateTime.truncate(:second) |> NaiveDateTime.to_iso8601()

  defp values_to_options(values) do
    Enum.map(values, fn value ->
      name = value |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
      {name, value}
    end)
  end

  defp time_from_iso(iso), do: String.slice(iso, 11..-4//1)
  defp date_from_iso(iso), do: String.slice(iso, 0..-10//1)

  defp current_time_plus_2_hours(current_time) do
    NaiveDateTime.add(NaiveDateTime.from_iso8601!(current_time), 2, :hour)
    |> naive_datetime_to_iso8601()
  end
end
