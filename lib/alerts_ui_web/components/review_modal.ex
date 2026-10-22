defmodule AlertsUIWeb.ReviewModal do
  @moduledoc """
  Component for the review modal with alert details and delivery preview
  """
  use Phoenix.Component
  use AlertsUIWeb, :verified_routes

  import AlertsUIWeb.CoreComponents
  import AlertsUIWeb.SharedComponents

  import AlertsUIWeb.CreateAlertLive.Helpers.AlertDataHelpers,
    only: [humanize_effect_name: 2, display_alert_timing: 1]

  import AlertsUIWeb.CreateAlertLive.Helpers.Value,
    only: [blank?: 1]

  import PhoenixHTMLHelpers.Format, only: [text_to_html: 2]

  alias AlertsUI.ActiveStatus
  alias AlertsUI.Helpers.ReminderTimes
  alias AlertsUI.Models.{Alert, SeverityLevel}

  alias AlertsUIWeb.FormComponents.Helpers.{
    ContentFormatter
  }

  alias AlertsUIWeb.CreateAlertLive.Helpers.{RecurringDurationText, SelectFormatter, TimeRangeDurationText}

  alias AlertsUIWeb.FormComponents.Helpers.Helpers, as: FormHelpers
  alias AlertsUIWeb.UserHelpers

  alias Phoenix.LiveView.JS

  @doc """
  Renders the review modal. The fields passed as props are determined by its parent

  ## Examples
    <.review_modal
      cancel_event_name="cancel_review"
      accept_event_name="save"
      target_id="#submit_view"
    />
  """
  attr :alert_data, :map, default: %{}, doc: "The user selections that make up alert_data"
  attr :alert_id, :string, default: nil, doc: "If alert exists, this is the alert's string id"

  attr :send_all_clear?, :boolean,
    default: false,
    doc: "Whether the 'all clear' checkbox on the close modal is checked"

  attr :cancel_alert, :boolean,
    default: false,
    doc: "Whether the cancel alert button should be visible"

  attr :form_type, :atom,
    default: nil,
    doc: "Whether the alert is being created, edited, or duplicated"

  attr :target_id, :string,
    default: "",
    doc: "The target to send the events to (eg form component id)"

  attr :current_user, :map, default: %{}, doc: "Current user, for first and last name"
  attr :current_url, :string, default: "", doc: "Current url, to use as part of modal permalink"
  attr :rest, :global, include: ~w(cancel_event_name accept_event_name target_id)

  def review_modal(assigns) do
    route_names =
      assigns.alert_data
      |> Map.get(:original_route_selections, [])
      |> Alert.get_original_names()
      |> join_present(", ")

    direction_names =
      assigns.alert_data
      |> Map.get(:original_direction_selections, [])
      |> Alert.get_original_names()
      |> join_present(", ")

    stop_names =
      assigns.alert_data
      |> Map.get(:original_stop_selections, [])
      |> Alert.get_original_names()
      |> join_present(", ")

    trip_names =
      assigns.alert_data
      |> Map.get(:original_trip_selections, [])
      |> Alert.get_original_names()
      |> join_present(", ")

    trip_names =
      if trip_names == "" do
        assigns.alert_data
        |> Map.get(:selected_schedules, [])
        |> Kernel.||([])
        |> Enum.map(fn s ->
          SelectFormatter.name_for_option(s, assigns.alert_data.route_type)
        end)
        |> join_present(", ")
      else
        trip_names
      end

    reminder_times =
      assigns.alert_data
      |> Map.get(:reminder_times, [])

    facility_names =
      assigns.alert_data
      |> Map.get(:original_facility_selections, [])
      |> Alert.get_original_names()
      |> join_present(", ")

    modes = Map.get(assigns.alert_data, :service_types, %{}) || %{}

    mode_names =
      modes
      |> Enum.map(&ContentFormatter.service_type_string/1)
      |> join_present(", ")

    assigns =
      assign(assigns,
        now: DateTime.utc_now(),
        route_names: route_names,
        direction_names: direction_names,
        stop_names: stop_names,
        trip_names: trip_names,
        facility_names: facility_names,
        mode_names: mode_names,
        id: "review-modal",
        created_timestamp: Map.get(assigns.alert_data, :created_timestamp),
        created_by: Map.get(assigns.alert_data, :created_by),
        last_edited_at: Map.get(assigns.alert_data, :last_edited_at),
        last_edited_by: Map.get(assigns.alert_data, :last_edited_by),
        reminder_times: reminder_times,
        send_notifications: assigns.alert_data.notification_toggle
      )

    ~H"""
    <.modal
      id={@id}
      show={true}
      header_text="Create new alert"
      cancel_button_text="Keep editing"
      accept_button_text={if @send_notifications, do: submit_with_notifications(), else: "Submit"}
      accept_button_classes="whitespace-nowrap"
      cancel_button_classes="whitespace-nowrap"
      inner_class="!p-0"
      target_id={@target_id}
      footer_warning_text={
        if @send_notifications,
          do: "Warning: Notifications will be sent to alert subscribers.",
          else: nil
      }
      {@rest}
    >
      <:header>
        <div>
          <%= cond do %>
            <% @form_type == :creating -> %>
              <p class="md:text-lg/6">Create new alert</p>
            <% @form_type == :duplicating -> %>
              <p class="md:text-lg/6">Duplicate alert #{@alert_id}</p>
            <% @form_type == :editing -> %>
              <p class="md:text-lg/6">Edit alert #{@alert_id}</p>
            <% true -> %>
              <p class="md:text-lg/6">Alert #{@alert_id} ({format_alert_status_text(@alert_data)})</p>
          <% end %>
          <p class="md:text-lg/6 font-bold">
            {ContentFormatter.service_type_string(@alert_data.route_type, @alert_data.combination)} • {humanize_effect_name(
              @alert_data.route_type,
              @alert_data.effect_name
            )}
          </p>
        </div>
      </:header>
      <div class="grid-cols-review-modal md:grid text-sm/2">
        <%!-- Main lefthand content --%>
        <div class="p-4 md:grow">
          <%!-- Top section --%>
          <p class="font-bold">Main message</p>
          {text_to_html(@alert_data.header_text,
            attributes: [class: "pb-4 max-w-[28rem] break-words"]
          )}
          <div>
            <span class="block pb-4">
              <p class="font-bold">Supporting information</p>
              <%= if not blank?(@alert_data.description_text) do %>
                {text_to_html(@alert_data.description_text,
                  attributes: [class: "pb-4 last-of-type:pb-0"]
                )}
              <% else %>
                <p class="italic">None</p>
              <% end %>
            </span>

            <span :if={not blank?(@alert_data.url)} class="block pb-4 break-all">
              <p class="font-bold url_label">URL</p>
              <a
                target="_blank"
                rel="noopener noreferrer"
                href={@alert_data.url}
                class="text-primary hover:text-primary-hover hover:underline"
              >
                {@alert_data.url}
                <.icon name="hero-arrow-top-right-on-square" class="h-4 w-4" />
              </a>
            </span>

            <span :if={not blank?(Map.get(@alert_data, :banner_text))} class="block pb-4">
              <p class="font-bold">Web Banner Text</p>
              <p>{@alert_data.banner_text}</p>
            </span>
          </div>

          <p class="font-bold">Affected service</p>
          <div id="affected_service_selections" class="pb-4 grid grid-cols-[110px_auto] gap-x-2">
            <%= if @route_names && @route_names != "" do %>
              <p>Routes:</p>
              <p>{@route_names}</p>
            <% end %>
            <%= if @direction_names && @direction_names != "" do %>
              <p>Direction:</p>
              <p>{@direction_names}</p>
            <% end %>
            <%= if @stop_names && @stop_names != "" do %>
              <p>Stops:</p>
              <p>{@stop_names}</p>
            <% end %>
            <%= if @trip_names && @trip_names != "" do %>
              <p>Trips:</p>
              <p>{@trip_names}</p>
            <% end %>
            <%= if @facility_names && @facility_names != "" do %>
              <p>Facilities:</p>
              <p>{@facility_names}</p>
            <% end %>
            <%= if ContentFormatter.service_type_string(@alert_data.route_type, @alert_data.combination) == "Systemwide" do %>
              <p>Modes:</p>
              <p>{@mode_names}</p>
            <% end %>
          </div>

          <%!-- Image --%>
          <%= if not blank?(@alert_data.image_url) do %>
            <p class="font-bold">Image</p>
            <div class="pb-4 break-all">
              <a
                target="_blank"
                rel="noopener noreferrer"
                href={@alert_data.image_url}
                class="align-start text-primary hover:text-primary-hover hover:underline"
              >
                <img
                  id="alert-image"
                  phx-hook="MeasureImage"
                  src={@alert_data.image_url}
                  alt={@alert_data.image_alternative_text || "No alternative text provided"}
                  class="max-h-40 self-start pr-2 object-contain block"
                />
                {String.split(@alert_data.image_url, "/") |> List.last()}
                <.icon name="hero-arrow-top-right-on-square" class="h-4 w-4" />
              </a>
              <span :if={Map.get(@alert_data, :image_preview_size, nil)} class="text-text-secondary">
                ({@alert_data.image_preview_size["width"]} x {@alert_data.image_preview_size[
                  "height"
                ]})
              </span>
              <p class="text-text-secondary break-normal">
                Alt text: {@alert_data.image_alternative_text || "No alternative text provided"}
              </p>
            </div>
          <% end %>

          <%!-- Middle section --%>
          <div class="grid grid-cols-[110px_auto] gap-x-2">
            <p class="font-bold pb-1">Cause</p>
            <%= if @alert_data.cause_detail not in ["", nil] do %>
              <p class="pb-1">
                {@alert_data.cause_detail |> String.replace("_", " ") |> String.capitalize()}
              </p>
            <% else %>
              <p class="pb-1 italic">None</p>
            <% end %>

            <p class="font-bold pb-1">Severity</p>
            <p class="pb-1">
              {@alert_data.severity
              |> SeverityLevel.severity_description_by_severity()
              |> String.capitalize()}
              <span class="text-text-secondary">
                {SeverityLevel.severity_string_by_severity(@alert_data.severity)}
              </span>
            </p>

            <p class="font-bold pb-1">Timing</p>
            <p class="pb-1">
              {display_alert_timing(@alert_data.alert_timing)}
            </p>

            <p class="font-bold pb-1">Effect period</p>
            <.effect_range_text alert_data={@alert_data} />

            <p class="font-bold pb-1">Notification period</p>
            <%= if Map.get(@alert_data, :notification_specifier, :same_as_effect_period) === :same_as_effect_period do %>
              <p class="pb-1">Same as effect period</p>
            <% else %>
              <div class="pb-1">
                <p>
                  {start_text =
                    TimeRangeDurationText.get_start_text(@alert_data.notification_period_start)

                  start_text <> " until "}
                </p>
                <p>
                  {notification_period_end =
                    Map.get(@alert_data, :notification_period_end) || @alert_data.active_period_end

                  notification_period_end
                  |> end_is_in_past?()
                  |> TimeRangeDurationText.notification_period_end_text(notification_period_end)}
                </p>
              </div>
            <% end %>
            <p :if={!is_nil(@form_type)} class="font-bold pb-1">Send notifications</p>
            <p :if={!is_nil(@form_type)} class="pb-4">
              {if @send_notifications, do: "Yes", else: "No"}
            </p>
            <p class="font-bold pb-1">Reminders</p>
            <%= if @reminder_times != [] do %>
              <div class="pb-4">
                <%= for reminder <- reminder_times_iterator(@reminder_times) do %>
                  <p>
                    {Calendar.strftime(reminder_time(reminder), "%a %m/%d/%Y %-I:%M %p")}
                    <span
                      :if={ReminderTimes.sent?(reminder_time(reminder))}
                      class="text-text-secondary"
                    >
                      <.icon name="hero-check-circle-solid text-mbta-green" class="h-4 w-4" /> Sent
                    </span>

                    <span
                      :if={!ReminderTimes.sent?(reminder_time(reminder))}
                      class="text-text-secondary"
                    >
                      <.icon name="hero-clock" class="h-4 w-4" /> Scheduled
                    </span>
                  </p>
                <% end %>
              </div>
            <% else %>
              <p class="pb-4 italic">None</p>
            <% end %>
          </div>
        </div>
        <%!-- Sidebar --%>
        <div class="md:min-w-[222px] md:shrink-0 p-4 bg-bg-elevation-5">
          <p class="font-bold">Created</p>
          <%= if @form_type in [:creating, :duplicating] do %>
            <p class="pb-3 whitespace-nowrap">
              {Calendar.strftime(
                DateTime.shift_zone!(@now, "America/New_York"),
                "%a %m/%d/%Y"
              )}
            </p>
          <% else %>
            <p class="pb-3 whitespace-nowrap">
              {Calendar.strftime(
                DateTime.shift_zone!(@created_timestamp, "America/New_York"),
                "%a %m/%d/%Y, %-I:%M %p"
              )}
            </p>
          <% end %>

          <p class="font-bold">Created by</p>
          <%= if @form_type in  [:creating, :duplicating] && @current_user do %>
            <p class="pb-3 fs-mask">
              {Map.get(@current_user, :first_name, "")} {Map.get(@current_user, :last_name, "")}
            </p>
          <% else %>
            <p :if={@created_by} class="pb-3 fs-mask">
              {@created_by}
            </p>
          <% end %>

          <%= if @last_edited_at && @form_type not in [:creating, :duplicating] do %>
            <p class="font-bold">Last edited</p>
            <p :if={@form_type == :editing} class="pb-3 whitespace-nowrap">
              {Calendar.strftime(
                DateTime.shift_zone!(@now, "America/New_York"),
                "%a %m/%d/%Y"
              )}
            </p>
            <p :if={@form_type != :editing} class="pb-3 whitespace-nowrap">
              {Calendar.strftime(
                DateTime.shift_zone!(@last_edited_at, "America/New_York"),
                "%a %m/%d/%Y, %-I:%M %p"
              )}
            </p>

            <p class="font-bold">Last edited by</p>
            <p :if={@form_type == :editing && @current_user} class="pb-3 fs-mask">
              {Map.get(@current_user, :first_name, "")} {Map.get(@current_user, :last_name, "")}
            </p>
            <p :if={@form_type != :editing && @last_edited_by} class="pb-3 fs-mask">
              {@last_edited_by}
            </p>
          <% end %>
          <div>
            <button
              :if={@alert_id}
              class="text-primary hover:text-primary-hover hover:underline"
              phx-click={
                JS.dispatch("phx:copy", detail: %{text: @current_url <> "?alert_id=#{@alert_id}"})
              }
              aria-live="polite"
            >
              <span class="state-default">
                <.icon name="hero-link-solid" class="w-4 h-4" /> Copy link
              </span>
              <span class="state-copied hidden" aria-hidden="true">
                <.icon name="hero-check-solid" class="w-4 h-4" /> Copied
              </span>
            </button>
          </div>
          <.link
            :if={@alert_id}
            class="text-primary hover:text-primary-hover hover:underline"
            href={~p"/download_history/download?alert_id=#{@alert_id}"}
            target="_blank"
          >
            <.icon name="hero-document-arrow-down-solid" class="w-4 h-4" /> Download history
          </.link>
        </div>
      </div>
      <%!-- Only override footer if we're not creating/reviewing edits --%>
      <:footer :if={!@form_type}>
        <div class="flex flex-none flex-col justify-items-stretch md:flex-row md:justify-end px-4 py-4 gap-2">
          <%!-- food for thought: should type=button be here or in the component? --%>
          <%= if UserHelpers.author?(@current_user) do %>
            <.button_danger
              :if={ActiveStatus.get_alert_status(@alert_data) != :past}
              type="button"
              id="review-modal-close-alert"
              phx-remove={hide_modal(@id)}
              phx-click={
                demote_modal(@id)
                |> show_modal("close-alert-nested-modal-#{@alert_id}")
              }
            >
              {if ActiveStatus.get_alert_status(@alert_data) in [
                    :published_current,
                    :published_upcoming
                  ],
                  do: "Close alert",
                  else: "Cancel alert"}
            </.button_danger>
            <.button_secondary
              type="button"
              class="md:ml-auto"
              phx-remove={hide_modal(@id)}
              phx-click={
                JS.push("duplicate_alert", value: %{alert_id: @alert_id}, target: @target_id)
                |> JS.exec("phx-remove")
              }
            >
              Duplicate
            </.button_secondary>
            <%= if ActiveStatus.get_alert_status(@alert_data) == :past do %>
              <.button_primary
                type="button"
                phx-remove={hide_modal(@id)}
                phx-click={JS.push("close_details", target: @target_id) |> JS.exec("phx-remove")}
              >
                Done
              </.button_primary>
            <% else %>
              <.button_primary
                type="button"
                phx-remove={hide_modal(@id)}
                phx-click={
                  JS.push("edit_alert", value: %{alert_id: @alert_id}, target: @target_id)
                  |> JS.exec("phx-remove")
                }
              >
                Edit this alert
              </.button_primary>
            <% end %>
          <% end %>
        </div>
      </:footer>
      <AlertsUIWeb.ReviewModal.confirm_close_modal
        id="close-alert-nested-modal"
        alert_id={@alert_id}
        send_all_clear?={@send_all_clear?}
        on_accept={hide_modal(@id)}
      />
    </.modal>
    """
  end

  defp safe_datetime_compare(%NaiveDateTime{} = start_datetime, %NaiveDateTime{} = end_datetime) do
    NaiveDateTime.compare(start_datetime, end_datetime)
  end

  defp safe_datetime_compare(_, _), do: nil

  defp end_is_in_past?(end_datetime) do
    naive_now =
      DateTime.utc_now() |> DateTime.shift_zone!("America/New_York") |> DateTime.to_naive()

    safe_datetime_compare(naive_now, end_datetime) == :gt
  end

  defp join_present(list, separator) when is_list(list) do
    list
    |> Enum.filter(&(&1 != nil && String.trim(&1) != ""))
    |> Enum.join(separator)
  end

  defp format_alert_status_text(alert) do
    alert
    |> ActiveStatus.get_alert_status()
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" / ", &String.capitalize/1)
  end

  defp reminder_times_iterator(reminders) do
    reminders
    |> Enum.filter(&(!!reminder_time(&1)))
    |> Enum.sort_by(&reminder_time(&1), NaiveDateTime)
  end

  defp reminder_time(reminder) do
    Map.get(reminder, :time, Map.get(reminder, :reminder_time))
  end

  defp submit_with_notifications do
    assigns = %{}

    ~H"""
    <.icon name="hero-paper-airplane-solid" class="h-4 w-4 mr-1" />Submit and notify
    """
  end

  attr :alert_data, :map

  def effect_range_text(assigns) do
    closed_before_start? =
      safe_datetime_compare(
        assigns.alert_data.active_period_start,
        assigns.alert_data.active_period_end
      ) == :gt

    assigns = assign(assigns, :closed_before_start?, closed_before_start?)

    if assigns.alert_data.alert_timing == :"one-time" do
      ~H"""
      <div class="pb-1">
        <p>
          {TimeRangeDurationText.one_time_duration_start_phrase(%{
            "active_period_start" => @alert_data.active_period_start,
            "active_period_start_specifier" => @alert_data.active_period_start_specifier
          })}
        </p>
        <p>
          {TimeRangeDurationText.one_time_duration_end_phrase(%{
            "active_period_end" => @alert_data.active_period_end,
            "active_period_end_specifier" => @alert_data.active_period_end_specifier
          })}
        </p>
        <p :if={!@closed_before_start?}>
          {TimeRangeDurationText.one_time_duration_phrase(%{
            "active_period_start" => @alert_data.active_period_start,
            "active_period_end" => @alert_data.active_period_end,
            "active_period_end_specifier" => @alert_data.active_period_end_specifier
          })}
        </p>
        <p :if={@closed_before_start?}>(closed before effect start)</p>
      </div>
      """
    else
      ~H"""
      <div class="pb-1">
        <p>
          {RecurringDurationText.recurring_duration_date_range(%{
            "active_period_start_date" => @alert_data.active_period_start_date,
            "active_period_end_date" => @alert_data.active_period_end_date,
            "active_period_end_specifier" => @alert_data.active_period_end_specifier
          })}
        </p>
        <p>
          {RecurringDurationText.recurring_duration_recurrence_days(%{
            "recurrence_days" => @alert_data.recurrence_days
          })
          |> FormHelpers.upcase_first_letter()}
        </p>
        <p :if={!@closed_before_start?}>
          {RecurringDurationText.recurring_duration_time_range(
            assign(assigns,
              params: %{
                "active_period_start_time" => @alert_data.active_period_start_time,
                "active_period_end_time" => @alert_data.active_period_end_time
              }
            )
          )}
          {RecurringDurationText.recurring_duration_only(%{
            "active_period_start_time" => @alert_data.active_period_start_time,
            "active_period_end_time" => @alert_data.active_period_end_time
          })}
        </p>
        <p :if={@closed_before_start?}>(closed before effect start)</p>
      </div>
      """
    end
  end

  attr :id, :string,
    default: "close-alert-modal",
    doc: "The ID of the modal element. Will have the alert_id appended to it."

  attr :alert_id, :integer, required: true, doc: "The id of the alert we're dealing with"

  attr :send_all_clear?, :boolean,
    default: false,
    doc: "Whether the 'all clear' checkbox on the close modal is checked"

  attr :target_id, :string,
    default: "",
    doc: "The ID of the element that should receive this modal's events"

  attr :send_close_on_esc?, :boolean,
    default: true,
    doc: "if this is false the component should not send a close event on the user hitting escape"

  attr :rest, :global, include: ~w(on_cancel on_accept)

  def confirm_close_modal(assigns) do
    ~H"""
    <.modal
      id={"#{@id}-#{@alert_id}"}
      send_close_on_esc?={@send_close_on_esc?}
      header_text="Close alert"
      cancel_event_name="cancelled_close_modal"
      accept_event_name="close_alert"
      cancel_button_text="Keep Active"
      accept_button_text="Close now"
      target_id="#view_alerts_live_view"
      class="text-text-primary"
      inner_class="text-base font-light"
      cancel_button_classes="border-0 text-base"
      accept_button_classes="
              !text-white
              !bg-danger
              !border-danger
              hover:!bg-danger-hover
              hover:!border-danger-hover
              active:!bg-primary-active
              active:!border-primary-active
              focus:!border-primary-active
              text-base
              "
      value={@alert_id}
      {@rest}
    >
      <p class="leading-tight mt-2 mb-8 min-h-[1.3rem]">
        Are you sure you want to close alert #{@alert_id}?
      </p>
      <div class="flex row">
        <div class="mr-4">
          <input type="hidden" name="all-clear-checkbox" value="false" />
          <.checkbox
            id={"all-clear-checkbox-#{@id}-#{@alert_id}"}
            name="all-clear-checkbox"
            value="true"
            phx-click="all_clear_checkbox"
            checked={@send_all_clear?}
          />
        </div>
        <AlertsUIWeb.SharedComponents.label for="all-clear-checkbox">
          Send "all clear" message to alert subscribers
        </AlertsUIWeb.SharedComponents.label>
      </div>
    </.modal>
    """
  end
end
