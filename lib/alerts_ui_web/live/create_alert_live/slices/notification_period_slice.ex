defmodule AlertsUIWeb.CreateAlertLive.Slices.NotificationPeriodSlice do
  @moduledoc """
    Live Component for notification period of form
  """

  alias AlertsUI.Models.ActivePeriod
  alias AlertsUIWeb.CreateAlertLive.Slice
  alias AlertsUIWeb.FormComponents.Helpers.DateTimeHelpers
  alias Phoenix.HTML.Form

  use AlertsUIWeb, :html

  import Ecto.Changeset

  import AlertsUIWeb.CreateAlertLive.Helpers.AlertDataHelpers,
    only: [put_over_nil: 3, values_to_options: 1]

  @notification_values [
    :same_as_effect_period,
    :now,
    :start_of_service,
    :custom
  ]

  defstruct [
    :form_type,
    :active_period_end,
    :notification_period_start,
    :notification_period_start_date,
    notification_specifier: :now
  ]

  defimpl Slice, for: __MODULE__ do
    alias AlertsUIWeb.CreateAlertLive.AlertData
    alias AlertsUIWeb.CreateAlertLive.Helpers.TimeRangeValidators
    alias AlertsUIWeb.CreateAlertLive.Slices.NotificationPeriodSlice

    def mount(_slice, socket, _params) do
      assign(socket, :current_time, DateTimeHelpers.current_time())
    end

    def extract(slice, %AlertData{} = _alert, _params) do
      now = DateTimeHelpers.current_time()

      slice
      |> put_over_nil(:notification_specifier, :now)
      |> put_over_nil(:notification_period_start, now)
      |> put_over_nil(:notification_period_start_date, NaiveDateTime.to_date(now))
      |> update_times_if_duplicating(slice.form_type, now)
    end

    def transform(_slice, changeset, _params, socket) do
      current_time = socket.assigns.current_time

      changeset
      |> NotificationPeriodSlice.ensure_notification_start(current_time)
      |> NotificationPeriodSlice.extract_notification_end(current_time)
    end

    def validate(_slice, changeset, params, socket) do
      changeset
      |> TimeRangeValidators.validate_cast_notification_datetimes(params)
      |> TimeRangeValidators.validate_notification_time(
        socket.assigns.current_time,
        socket.assigns.form_type
      )
      |> TimeRangeValidators.validate_required_notification_fields()
    end

    def assigns(_slice, socket, _params) do
      socket
    end

    def update_times_if_duplicating(slice, :duplicating, now) do
      active_period_end = slice.active_period_end || now

      if NaiveDateTime.compare(now, active_period_end) in [:eq, :gt] do
        Map.merge(slice, %{
          notification_specifier: :now,
          notification_period_start: now,
          notification_period_start_date: NaiveDateTime.to_date(now)
        })
      else
        slice
      end
    end

    def update_times_if_duplicating(slice, _, _), do: slice
  end

  def ensure_notification_start(changeset, current_time) do
    specifier = get_field(changeset, :notification_specifier)
    start_dt = get_field(changeset, :notification_period_start, :unspecified)
    start_d = get_field(changeset, :notification_period_start_date, :unspecified)

    changeset
    |> ensure_notification_start_for_specifier(specifier, start_dt, start_d, current_time)
  end

  def ensure_notification_start_for_specifier(changeset, :same_as_effect_period, _, _, _) do
    active_period_start = get_field(changeset, :active_period_start)
    active_period_start_date = get_field(changeset, :active_period_start_date)

    changeset
    |> force_change(:notification_period_start, active_period_start)
    |> force_change(:notification_period_start_date, active_period_start_date)
  end

  def ensure_notification_start_for_specifier(changeset, :now, _, _, current_time) do
    now = current_time

    changeset
    |> force_change(:notification_period_start, now)
    |> force_change(:notification_period_start_date, now |> NaiveDateTime.to_date())
  end

  def ensure_notification_start_for_specifier(changeset, :start_of_service, _, d, _) do
    datetime = NaiveDateTime.new!(d, ActivePeriod.start_of_service_time())

    changeset
    |> force_change(:notification_period_start, datetime)
    |> force_change(:notification_period_start_date, d)
  end

  def ensure_notification_start_for_specifier(changeset, :custom, nil, d, current_time) do
    ensure_notification_start_for_specifier(
      changeset,
      :custom,
      current_time,
      d,
      current_time
    )
  end

  def ensure_notification_start_for_specifier(changeset, :custom, dt, _, _) do
    changeset
    |> force_change(:notification_period_start, dt)
    |> force_change(:notification_period_start_date, NaiveDateTime.to_date(dt))
  end

  def ensure_notification_start_for_specifier(changeset, _, _, _, _), do: changeset

  def extract_notification_end(changeset, current_time) do
    specifier = get_field(changeset, :active_period_end_specifier)
    end_dt = get_field(changeset, :active_period_end) || :unspecified
    end_d = get_field(changeset, :active_period_end_date) || :unspecified

    changeset
    |> extract_notification_end_for_specifier(specifier, end_dt, end_d, current_time)
  end

  def extract_notification_end_for_specifier(changeset, :later_today, _, _, current_time) do
    notification_end = ActivePeriod.end_of_service_datetime_naive(current_time)

    changeset
    |> force_change(:notification_period_end, notification_end)
    |> force_change(:notification_period_end_date, notification_end |> NaiveDateTime.to_date())
  end

  def extract_notification_end_for_specifier(
        changeset,
        :end_of_service,
        _,
        :unspecified,
        current_time
      ) do
    current_date = NaiveDateTime.to_date(current_time)

    extract_notification_end_for_specifier(
      changeset,
      :end_of_service,
      :ignored,
      current_date,
      current_time
    )
  end

  def extract_notification_end_for_specifier(changeset, :end_of_service, _, date, _) do
    datetime =
      date
      |> NaiveDateTime.new!(~T[12:00:00])
      |> ActivePeriod.end_of_service_datetime_naive()

    changeset
    |> force_change(:notification_period_end, datetime)
    |> force_change(:notification_period_end_date, datetime |> NaiveDateTime.to_date())
  end

  def extract_notification_end_for_specifier(changeset, :until_further_notice, _, _, _) do
    changeset
    |> force_change(:notification_period_end, nil)
    |> force_change(:notification_period_end_date, nil)
  end

  def extract_notification_end_for_specifier(changeset, :custom, :unspecified, _, current_time) do
    now = current_time
    extract_notification_end_for_specifier(changeset, :custom, now, :ignored, now)
  end

  def extract_notification_end_for_specifier(changeset, :custom, dt, _, _) do
    changeset
    |> force_change(:notification_period_end, dt)
    |> force_change(:notification_period_end_date, dt |> NaiveDateTime.to_date())
  end

  def extract_notification_end_for_specifier(changeset, _, _, _, _) do
    changeset
  end

  def notification_values, do: @notification_values

  attr :form, Form
  attr :form_type, Atom
  attr :current_time, NaiveDateTime

  def render(assigns) do
    alert_data = Map.merge(assigns.form.source.data, assigns.form.source.changes)

    minimum_time =
      if assigns.form_type == :editing do
        nil
      else
        assigns.current_time
      end

    # Mirror the notification-start validation bound: the effect start on create,
    # the notification period end when editing (nil ⇒ no max).
    maximum_time =
      if assigns.form_type == :editing do
        alert_data.notification_period_end
      else
        alert_data.active_period_start
      end

    assigns = assign(assigns, [{:minimum_time, minimum_time}, {:maximum_time, maximum_time}])

    ~H"""
    <div class="min-w-full flex flex-col" id="notification_period_view">
      <div id="scheduled-selector-div" class="flex flex-col md:flex-row md:flex-wrap gap-8 my-4">
        <.select
          label="Notification period"
          field={@form[:notification_specifier]}
          options={values_to_options(notification_values())}
          class="md:w-[16rem] h-10"
        />
        <.datetime
          :if={@form[:notification_specifier].value in [:start_of_service, "start_of_service"]}
          type="date"
          label=""
          field={@form[:notification_period_start_date]}
          min={naive_datetime_to_iso_date(@minimum_time)}
          max={naive_datetime_to_iso_date(@maximum_time)}
          value={@form[:notification_period_start_date].value}
          class="md:min-w-64 md:max-w-64 h-10"
        />
        <.datetime
          :if={@form[:notification_specifier].value in [:custom, "custom"]}
          label=""
          field={@form[:notification_period_start]}
          min={naive_datetime_to_iso8601(@minimum_time)}
          max={naive_datetime_to_iso8601(@maximum_time)}
          value={@form[:notification_period_start].value |> naive_datetime_to_iso8601}
          class="md:min-w-64 md:max-w-64 h-10"
        />
        <div
          :if={
            @form[:notification_specifier].value not in [
              :same_as_effect_period,
              "same_as_effect_period"
            ]
          }
          class="flex flex-col md:flex-row"
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
end
