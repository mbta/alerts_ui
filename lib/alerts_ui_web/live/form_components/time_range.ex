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
    :start_of_service,
    :custom
  ]

  @end_values [
    :later_today,
    :end_of_service,
    :until_further_notice,
    :custom
  ]

  @primary_key false
  embedded_schema do
    field :alert_timing_dropdown, Ecto.Enum, values: @alert_timing_dropdown_values
    field :active_period_start, :naive_datetime
    field :active_period_start_date, :date
    field :active_period_start_specifier, Ecto.Enum, values: @start_values, default: :now
    field :active_period_end_specifier, Ecto.Enum, values: @end_values, default: :later_today
    field :active_period_end, :naive_datetime
    field :active_period_end_date, :date
    field :notification_period_start, :naive_datetime
  end

  @fields ~w[active_period_end active_period_end_specifier alert_timing_dropdown active_period_start_specifier notification_period_start active_period_start active_period_start_date active_period_end_date]a

  @impl true
  def mount(socket) do
    current_time = current_time()

    alert_data = %{
      notification_period_start: "",
      active_period_start: current_time |> naive_datetime_to_iso8601(),
      active_period_start_date: current_time |> NaiveDateTime.to_date(),
      active_period_end:
        ActivePeriod.end_of_service_datetime(current_time)
        |> DateTime.to_naive()
        |> naive_datetime_to_iso8601,
      active_period_end_date: ActivePeriod.end_of_service_date(current_time)
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
  def update(%{editing: editing, alert_data: alert_data} = assigns, socket) do
    alert_data =
      if socket.assigns.edited === false and editing === true do
        if Map.get(alert_data, :notification_period_start) in [nil, ""] do
          alert_data
        else
          Map.put(alert_data, :alert_timing_dropdown, "scheduled")
        end
        |> Enum.filter(fn {_k, v} -> !is_nil(v) end)
      else
        alert_data
      end
      |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)

    changeset = changeset(%__MODULE__{}, Map.merge(socket.assigns.form.params, alert_data))

    changes =
      changeset
      |> apply_action!(:validate)

    send(self(), {:section_completed, changes})
    form = changeset |> to_form

    assigns = Map.merge(assigns, %{form: form, edited: true})
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def update(%{submitted: submitted}, socket) do
    socket =
      if submitted do
        form_params = socket.assigns.form.params

        changeset =
          %__MODULE__{}
          |> changeset(form_params)
          |> validate_required_fields(form_params)
          |> validate_relationship(form_params)
          |> validate_start_is_after_now(socket.assigns.current_time)

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

        assign(socket, form: form)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "validate",
        %{"time_range" => time_range},
        socket
      ) do
    start_datetime = set_start_datetime(time_range, socket.assigns.current_time)
    end_datetime = set_end_datetime(time_range, socket.assigns.current_time)

    time_range =
      Map.merge(time_range, %{
        "active_period_start" => start_datetime,
        "active_period_end" => end_datetime
      })

    changeset =
      changeset(%__MODULE__{}, time_range)

    changeset =
      if changeset.valid? do
        changeset
        |> validate_relationship(time_range)
      else
        changeset
      end

    changeset
    |> validate_required_fields(time_range)
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

  defp set_start_datetime(time_range, current_time) do
    case time_range["active_period_start_specifier"] do
      "now" ->
        current_time |> naive_datetime_to_iso8601()

      "start_of_service" ->
        if time_range["active_period_start_date"] in [nil, ""] do
          current_time
        else
          time_range["active_period_start_date"]
          |> Date.from_iso8601!()
          |> NaiveDateTime.new!(ActivePeriod.start_of_service_time())
        end
        |> naive_datetime_to_iso8601()

      "custom" ->
        time_range["active_period_start"] |> String.pad_trailing(19, ":00")
    end
  end

  defp set_end_datetime(time_range, current_time) do
    case time_range["active_period_end_specifier"] do
      "later_today" ->
        if time_range["active_period_end_date"] in [nil, ""] do
          current_time
          |> ActivePeriod.end_of_service_datetime()
          |> DateTime.to_naive()
        else
          time_range["active_period_end_date"]
          |> Date.from_iso8601!()
          |> Date.add(1)
          |> NaiveDateTime.new!(ActivePeriod.end_of_service_time())
        end
        |> naive_datetime_to_iso8601()

      "end_of_service" ->
        if time_range["active_period_end_date"] in ["", nil] do
          current_time
          |> ActivePeriod.end_of_service_datetime()
          |> DateTime.to_naive()
        else
          time_range["active_period_end_date"]
          |> Date.from_iso8601!()
          |> Date.add(1)
          |> NaiveDateTime.new!(ActivePeriod.end_of_service_time())
        end
        |> naive_datetime_to_iso8601()

      "until_further_notice" ->
        ""

      "custom" ->
        time_range["active_period_end"]
    end
  end

  defp changeset(changeset, params) do
    custom_errors = [
      active_period_start: "Enter a valid datetime",
      active_period_end: "Enter a valid datetime",
      active_period_start_date: "Enter a valid date",
      active_period_end_date: "Enter a valid date",
      notification_period_start: "Enter a valid datetime"
    ]

    changeset
    |> cast(params, @fields, message: fn field, _meta -> custom_errors[field] end)
  end

  @spec validate_relationship(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def validate_relationship(changeset, time_range) do
    changeset
    |> validate_change(:active_period_start, fn :active_period_start, active_period_start ->
      validate_active_period_start(
        active_period_start,
        time_range["active_period_end"]
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

  @spec validate_required_fields(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  defp validate_required_fields(changeset, params) do
    changeset
    |> validate_required(
      required_start_field_by_specifier(params["active_period_start_specifier"]),
      message: "Enter a valid time range start"
    )
    |> validate_required(
      required_end_field_by_specifier(params["active_period_end_specifier"]),
      message: "Enter a valid time range end"
    )
    |> validate_required(
      required_notification_field_by_specifier(params["alert_timing_dropdown"]),
      message: "Enter a valid scheduled alert start"
    )
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
              min={@current_time |> naive_datetime_to_iso8601()}
              max={@form[:active_period_end].value}
              value={@form[:active_period_start].value}
              label="Start datetime"
              class={"min-w-[16rem] h-10 " <> (if @form[:active_period_start_specifier].value === :custom, do: "", else: "hidden")}
              phx-debounce={120}
            />
            <.datetime
              type="date"
              field={@form[:active_period_start_date]}
              min={next_start_of_service_date(@current_time)}
              max={@form[:active_period_end].value |> naive_datetime_to_iso_date}
              value={@form[:active_period_start_date].value}
              label="Start date"
              class={"min-w-[16rem] h-10 " <> (if @form[:active_period_start_specifier].value === :start_of_service, do: "", else: "hidden")}
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
              label="End datetime"
              class={"min-w-[16rem] h-10 " <> (if @form[:active_period_end_specifier].value === :custom, do: "", else: "hidden")}
              phx-debounce={120}
            />
            <.datetime
              type="date"
              field={@form[:active_period_end_date]}
              min={@form[:active_period_start].value |> naive_datetime_to_iso_date}
              value={@form[:active_period_end_date].value}
              label="End date"
              class={"min-w-[16rem] h-10 " <> (if @form[:active_period_end_specifier].value === :end_of_service, do: "", else: "hidden")}
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

  defp validate_active_period_start(active_period_start, %NaiveDateTime{} = active_period_end) do
    if NaiveDateTime.compare(
         active_period_start,
         active_period_end
       ) in [:gt] do
      [
        active_period_start: "Effect must start before #{formatted_datetime(active_period_end)}",
        active_period_start_date:
          "Effect must start before #{formatted_datetime(active_period_end, "{0M}/{0D}/{YYYY}")}"
      ]
    else
      []
    end
  end

  defp validate_active_period_start(active_period_start, active_period_end) do
    {end_validity, end_time} = NaiveDateTime.from_iso8601(active_period_end)

    if end_validity === :ok do
      validate_active_period_start(active_period_start, end_time)
    else
      []
    end
  end

  defp validate_start_is_after_now(changeset, current_time) do
    validate_change(changeset, :active_period_start, fn :active_period_start,
                                                        active_period_start ->
      if NaiveDateTime.compare(
           active_period_start,
           current_time |> NaiveDateTime.truncate(:second)
         ) in [:lt] do
        [
          active_period_start: "Effect can't start in the past",
          active_period_start_date: "Effect can't start in the past"
        ]
      else
        []
      end
    end)
  end

  defp validate_active_period_end(active_period_end, %NaiveDateTime{} = active_period_start) do
    if NaiveDateTime.compare(
         active_period_end,
         active_period_start
       ) in [:lt] do
      [
        active_period_end: "Effect must end after #{formatted_datetime(active_period_start)}",
        active_period_end_date:
          "Effect must end after #{formatted_datetime(active_period_start, "{0M}/{0D}/{YYYY}")}"
      ]
    else
      []
    end
  end

  defp validate_active_period_end(active_period_end, active_period_start) do
    {start_validity, start_time} = NaiveDateTime.from_iso8601(active_period_start)

    if start_validity === :ok do
      validate_active_period_end(active_period_end, start_time)
    else
      []
    end
  end

  defp validate_notification_period_start(
         notification_period_start,
         active_period_start,
         active_period_end
       ) do
    {start_validity, start_time} = NaiveDateTime.from_iso8601(active_period_start)

    {end_validity, end_time} =
      NaiveDateTime.from_iso8601(active_period_end)

    cond do
      start_validity === :ok &&
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

  defp required_start_field_by_specifier(specifier) do
    case specifier do
      "custom" -> [:active_period_start]
      "start_of_service" -> [:active_period_start_date]
      _ -> []
    end
  end

  defp required_end_field_by_specifier(specifier) do
    case specifier do
      "custom" -> [:active_period_end]
      "end_of_service" -> [:active_period_end_date]
      _ -> []
    end
  end

  defp required_notification_field_by_specifier(specifier),
    do: if(specifier === "scheduled", do: [:notification_period_start], else: [])

  defp current_time,
    do:
      DateTime.now!("America/New_York") |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)

  defp next_start_of_service_date(current_time) do
    ActivePeriod.next_start_of_service_date(current_time)
    |> Date.to_iso8601()
  end

  def naive_datetime_to_iso_date(%NaiveDateTime{} = datetime),
    do: datetime |> NaiveDateTime.to_date() |> Date.to_iso8601()

  def naive_datetime_to_iso_date(_), do: ""

  defp naive_datetime_to_iso8601(%NaiveDateTime{} = datetime),
    do:
      datetime
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.to_iso8601()

  defp naive_datetime_to_iso8601(_), do: ""

  defp values_to_options(values) do
    Enum.map(values, fn value ->
      name = value |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
      {name, value}
    end)
  end

  defp formatted_datetime(datetime, format_string \\ "{0M}/{0D}/{YYYY}, {0h12}:{0m} {AM}"),
    do: Timex.format!(datetime, format_string)
end
