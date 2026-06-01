defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.NotificationPeriodSlice do
  @moduledoc """
    Live Component for notification period of form
  """

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertData,
    only: [put_over_nil: 3, values_to_options: 1]

  alias AlertsUIWeb.CreateAlertMonoLive.Slice

  alias Phoenix.HTML.Form

  import Ecto.Changeset

  use AlertsUIWeb, :html

  import AlertsUIWeb.CreateAlertMonoLive.Helpers.AlertData,
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
    alias AlertsUIWeb.CreateAlertMonoLive.AlertData
    alias AlertsUIWeb.CreateAlertMonoLive.Helpers.TimeRangeValidators
    alias AlertsUIWeb.CreateAlertMonoLive.Slices.NotificationPeriodSlice

    def mount(_slice, socket, _params) do
      socket
    end

    def extract(slice, %AlertData{} = _alert, _params) do
      now = NaiveDateTime.local_now()

      slice
      |> update_times_if_duplicating(slice.form_type, now)
      |> put_over_nil(:notification_specifier, :now)
      |> put_over_nil(:notification_period_start, now)
      |> put_over_nil(:notification_period_start_date, NaiveDateTime.to_date(now))
    end

    def transform(_slice, changeset, _params, _socket) do
      changeset
      |> NotificationPeriodSlice.ensure_notification_start()
    end

    def validate(_slice, changeset, _params, _socket) do
      changeset
      |> TimeRangeValidators.validate_notification()
      |> TimeRangeValidators.validate_required_notification_fields()
    end

    def assigns(_slice, socket, _params) do
      socket
    end

    def update_times_if_duplicating(%{active_period_end: nil} = slice, :duplicating, _now) do
      slice
    end

    def update_times_if_duplicating(
          %{active_period_end: active_period_end} = slice,
          :duplicating,
          now
        ) do
      if NaiveDateTime.compare(now, active_period_end) == :gt do
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

  def ensure_notification_start(changeset) do
    specifier = get_field(changeset, :notification_specifier)
    start_dt = get_field(changeset, :notification_period_start, :unspecified)
    start_d = get_field(changeset, :notification_period_start_date, :unspecified)

    changeset
    |> ensure_notification_start_for_specifier(specifier, start_dt, start_d)
  end

  def ensure_notification_start_for_specifier(changeset, :same_as_effect_period, _, _) do
    change(changeset, %{
      notification_period_start: nil,
      notification_period_start_date: nil
    })
  end

  def ensure_notification_start_for_specifier(changeset, :now, _, _) do
    now = NaiveDateTime.local_now()

    change(changeset, %{
      notification_period_start: now,
      notification_period_start_date: now |> NaiveDateTime.to_date()
    })
  end

  def ensure_notification_start_for_specifier(changeset, :start_of_service, _, _) do
    now = NaiveDateTime.local_now()

    change(changeset, %{
      notification_period_start: now,
      notification_period_start_date: now |> NaiveDateTime.to_date()
    })
  end

  def ensure_notification_start_for_specifier(changeset, :custom, _, _), do: changeset

  def ensure_notification_start_for_specifier(changeset, _, _, _), do: changeset

  def notification_values, do: @notification_values

  attr :form, Form

  def render(assigns) do
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
          :if={@form[:notification_specifier].value === :start_of_service}
          type="date"
          label=""
          field={@form[:notification_period_start_date]}
          min={NaiveDateTime.local_now() |> naive_datetime_to_iso_date}
          max={
            [naive_datetime_to_iso_date(@form[:active_period_start].value), "9999-12-31"]
            |> Enum.max()
          }
          value={@form[:notification_period_start_date].value}
          class="md:min-w-64 md:max-w-64 h-10"
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
