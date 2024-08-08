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
    field :active_period_start_specifier, Ecto.Enum, values: @start_values
    field :active_period_end_specifier, Ecto.Enum, values: @end_values
    field :active_period_end, :naive_datetime
  end

  @fields ~w[active_period_start active_period_end active_period_end_specifier active_period_start_specifier]a

  @impl true
  def mount(socket) do
    form = %__MODULE__{} |> changeset() |> to_form()

    socket =
      assign(socket, %{
        form: form,
        current_time: current_time()
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
        nil -> "now"
        result -> Atom.to_string(result)
      end

    default_alert_data =
      %{
        active_period_start: active_period_start,
        active_period_end: active_period_end,
        active_period_end_specifier: active_period_end_specifier,
        active_period_start_specifier: active_period_start_specifier
      }

    changeset = changeset(%__MODULE__{}, default_alert_data)

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
      |> validate_validity(time_range)
      |> validate_relationship(time_range, current_time)
      |> Map.put(:action, :validate)

    changeset
    |> apply_action(:insert)
    |> case do
      {:ok, changeset} ->
        send(self(), {:section_completed, changeset})
        changeset

      {:error, changeset} ->
        changeset
    end

    {:noreply, assign(socket, %{form: to_form(changeset)})}
  end

  defp changeset(changeset, params \\ %{}) do
    cast(changeset, params, @fields)
  end

  @spec validate_validity(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def validate_validity(changeset, time_range) do
    changeset
    |> then(fn changeset ->
      case NaiveDateTime.from_iso8601(time_range["active_period_start"]) do
        {:ok, _} -> changeset
        {:error, _} -> add_error(changeset, :active_period_start, "Enter a valid datetime")
      end
    end)
    |> then(fn changeset ->
      cond do
        time_range["active_period_end"] == "" ->
          changeset

        NaiveDateTime.from_iso8601(time_range["active_period_end"]) == {:error, :invalid_format} ->
          add_error(changeset, :active_period_end, "Enter a valid datetime")

        true ->
          changeset
      end
    end)
  end

  @spec validate_relationship(Ecto.Changeset.t(), map(), DateTime.t()) :: Ecto.Changeset.t()
  def validate_relationship(changeset, time_range, current_time) do
    changeset
    |> validate_change(:active_period_start, fn :active_period_start, active_period_start ->
      {end_time_validity, end_time} = NaiveDateTime.from_iso8601(time_range["active_period_end"])

      cond do
        NaiveDateTime.compare(
          active_period_start,
          NaiveDateTime.from_iso8601!(current_time)
        ) in [:lt] ->
          [
            active_period_start: {"Effect can't start in the past", []}
          ]

        end_time_validity == :ok and
            NaiveDateTime.compare(
              active_period_start,
              end_time
            ) in [:gt] ->
          [
            active_period_start:
              {"Effect must start before #{formatted_datetime(end_time, "{0M}/{0D}/{YYYY}, {0h12}:{0m}:{0s} {AM}")}",
               []}
          ]

        true ->
          []
      end
    end)
    |> validate_change(:active_period_end, fn :active_period_end, active_period_end ->
      {start_time_validity, start_time} =
        NaiveDateTime.from_iso8601(time_range["active_period_start"])

      if start_time_validity == :ok and
           NaiveDateTime.compare(
             active_period_end,
             start_time
           ) in [:lt] do
        [
          active_period_end:
            {"Effect must end after #{formatted_datetime(start_time, "{0M}/{0D}/{YYYY}, {0h12}:{0m}:{0s} {AM}")}",
             []}
        ]
      else
        []
      end
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
              field={@form[:active_period_start]}
              min={@current_time}
              max={@active_period_end}
              value={@active_period_start}
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
              min={@active_period_start}
              value={@active_period_end}
              label="End time"
              class="min-w-[16rem] h-10"
              disabled={@form.params["active_period_end_specifier"] !== "custom"}
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

  defp current_time_plus_2_hours(current_time) do
    NaiveDateTime.add(NaiveDateTime.from_iso8601!(current_time), 2, :hour)
    |> naive_datetime_to_iso8601()
  end

  defp formatted_datetime(datetime, format_string), do: Timex.format!(datetime, format_string)
end
