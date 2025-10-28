defmodule AlertsUIWeb.ReviewModal do
  @moduledoc """
  Component for the review modal with alert details and delivery preview
  """
  use Phoenix.Component
  use AlertsUIWeb, :verified_routes

  import AlertsUIWeb.CoreComponents
  import AlertsUIWeb.SharedComponents

  alias AlertsUI.{ActivePeriodBuilder, ActiveStatus}
  alias AlertsUI.Models.SeverityLevel
  alias AlertsUIWeb.CreateAlertLive

  alias AlertsUIWeb.FormComponents.Helpers.{
    ContentFormatter,
    Helpers,
    RecurringDurationText,
    SelectFormatter,
    TimeRangeDurationText
  }

  alias MBTAV3API.Facilities.Repo, as: FacilitiesRepo
  alias MBTAV3API.Routes.Repo, as: RoutesRepo
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
  attr :rest, :global, include: ~w(cancel_event_name accept_event_name target_id)

  def review_modal(assigns) do
    # Refactor: Selected_routes will soon be in the assigns and keep us from having to make this API call

    route_type = assigns.alert_data.route_type

    routes =
      if Map.get(assigns.alert_data, :route_ids) do
        Enum.map(assigns.alert_data.route_ids, fn id -> RoutesRepo.get(id) end)
      end

    direction_name =
      if routes && Map.get(assigns.alert_data, :direction) not in [nil, "default"] do
        routes
        |> List.first()
        |> Map.get(:direction_names)
        |> Map.get(String.to_integer(assigns.alert_data.direction))
      end

    stop_names = get_stop_names(assigns.alert_data)

    # Only ferry trips need the route_type to be passed to formatter
    trip_names =
      if Map.get(assigns.alert_data, :selected_schedules) do
        Enum.map(
          assigns.alert_data.selected_schedules,
          &SelectFormatter.name_for_option(&1, route_type)
        )
      end

    facility_name =
      if Map.get(assigns.alert_data, :facility_id) do
        assigns.alert_data.facility_id
        |> FacilitiesRepo.get()
        |> SelectFormatter.name_for_option()
      end

    assigns =
      assign(assigns,
        now: DateTime.utc_now(),
        routes: routes,
        direction_name: direction_name,
        stop_names: stop_names,
        trip_names: trip_names,
        facility_name: facility_name,
        id: "review-modal",
        created_at: Map.get(assigns.alert_data, :created_at),
        created_by: Map.get(assigns.alert_data, :created_by),
        last_edited_at: Map.get(assigns.alert_data, :last_edited_at),
        last_edited_by: Map.get(assigns.alert_data, :last_edited_by)
      )

    ~H"""
    <.modal
      id={@id}
      show={true}
      header_text="Create new alert"
      cancel_button_text="Keep editing"
      accept_button_text="Submit"
      class="flex flex-col h-full justify-center w-[800px]"
      outer_class="!h-full"
      inner_class="!p-0 shrink grow overflow-auto"
      target_id={@target_id}
      {@rest}
    >
      <:header>
        <div>
          <%= cond do %>
            <% @form_type == :creating -> %>
              <p class="text-lg/6">Create new alert</p>
            <% @form_type == :duplicating -> %>
              <p class="text-lg/6">Duplicate alert #{@alert_id}</p>
            <% @form_type == :editing -> %>
              <p class="text-lg/6">Edit alert #{@alert_id}</p>
            <% true -> %>
              <p class="text-lg/6">Alert #{@alert_id} ({format_alert_status_text(@alert_data)})</p>
          <% end %>
          <p class="text-lg/6 font-bold">
            {ContentFormatter.service_type_string(@alert_data.route_type, @alert_data.combination)} • {@alert_data.effect_name}
          </p>
        </div>
      </:header>
      <div class="flex text-sm/2">
        <%!-- Main lefthand content --%>
        <div class="p-4 grow">
          <%!-- Top section --%>
          <p class="font-bold">Main message</p>
          <p class="pb-4 max-w-[28rem] whitespace-pre-line break-words">{@alert_data.header_text}</p>

          <div>
            <span class="block pb-4">
              <p class="font-bold">Supporting information</p>
              <%= if @alert_data.description_text do %>
                <p class="whitespace-pre-line">{@alert_data.description_text}</p>
              <% else %>
                <p class="italic">None</p>
              <% end %>
            </span>

            <span :if={@alert_data.url} class="block pb-4">
              <p class="font-bold">URL</p>
              <p>
                <a
                  target="_blank"
                  rel="noopener noreferrer"
                  href={@alert_data.url}
                  class="inline-flex flex-row items-center text-primary hover:text-primary-hover hover:underline"
                >
                  {@alert_data.url}
                  <.icon name="hero-arrow-top-right-on-square" class="h-3 w-3 mx-[0.25rem]" />
                </a>
              </p>
            </span>

            <span :if={Map.get(@alert_data, :banner_text)} class="block pb-4">
              <p class="font-bold">Web Banner Text</p>
              <p>{@alert_data.banner_text}</p>
            </span>
          </div>

          <p class="font-bold">Affected service</p>
          <div id="affected_service_selections" class="pb-4 grid grid-cols-[110px_auto] gap-x-2">
            <%= if @routes && @routes != [] do %>
              <p>Routes:</p>
              <p>{@routes |> Enum.map(&SelectFormatter.name_for_option(&1)) |> Enum.join(", ")}</p>
            <% end %>
            <%= if @direction_name do %>
              <p>Direction:</p>
              <p>{@direction_name}</p>
            <% end %>
            <%= if @stop_names do %>
              <p>Stops:</p>
              <p>{Enum.join(@stop_names, ", ")}</p>
            <% end %>
            <%= if @trip_names do %>
              <p>Trips:</p>
              <p>{Enum.join(@trip_names, ", ")}</p>
            <% end %>
            <%= if @facility_name do %>
              <p>Facility:</p>
              <p>{@facility_name}</p>
            <% end %>
            <%= if ContentFormatter.service_type_string(@alert_data.route_type, @alert_data.combination) == "Systemwide" do %>
              <p>Modes:</p>
              <p>
                {@alert_data.service_types
                |> Enum.map(&ContentFormatter.service_type_string/1)
                |> Enum.join(", ")}
              </p>
            <% end %>
          </div>

          <%!-- Image --%>
          <%= if @alert_data.image_url do %>
            <p class="font-bold">Image</p>
            <div class="pb-4">
              <a
                target="_blank"
                rel="noopener noreferrer"
                href={@alert_data.image_url}
                class="align-top text-primary hover:text-primary-hover hover:underline"
              >
                <img
                  id="alert-image"
                  phx-hook="MeasureImage"
                  src={@alert_data.image_url}
                  alt={@alert_data.image_alternative_text || "No alternative text provided"}
                  class="h-16 pr-2"
                />
                <p>
                  {String.split(@alert_data.image_url, "/") |> List.last()}
                  <span :if={Map.get(@alert_data, :image_preview_size, nil)}>
                    ({@alert_data.image_preview_size["width"]} x {@alert_data.image_preview_size[
                      "height"
                    ]})
                  </span>
                  <.icon name="hero-arrow-top-right-on-square" class="h-3 w-3" />
                </p>
              </a>
              <p class="">
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
              {@alert_data.alert_timing |> Atom.to_string() |> String.capitalize()}
            </p>

            <p class="font-bold pb-1">Effect period</p>
            <%= if @alert_data.alert_timing == :"one-time" do %>
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
                <p>
                  {TimeRangeDurationText.one_time_duration_phrase(%{
                    "active_period_start" => @alert_data.active_period_start,
                    "active_period_end" => @alert_data.active_period_end,
                    "active_period_end_specifier" => @alert_data.active_period_end_specifier
                  })}
                </p>
              </div>
            <% else %>
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
                  |> Helpers.upcase_first_letter()}
                </p>
                <p>
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
              </div>
            <% end %>

            <p class="font-bold pb-1">Notification period</p>
            <%= if Map.get(@alert_data, :notification_specifier, :same_as_effect_period) === :same_as_effect_period do %>
              <p class="pb-1">Same as effect period</p>
            <% else %>
              <p class="pb-1">
                {TimeRangeDurationText.get_start_text(
                  @alert_data.notification_specifier,
                  @alert_data.notification_period_start
                ) <> " until alert is closed"}
              </p>
            <% end %>

            <p class="font-bold pb-1">Reminders</p>
            <%= if @alert_data.reminder_times != [] do %>
              <div class="pb-4">
                <%= for reminder <- Enum.sort(@alert_data.reminder_times) do %>
                  <p>
                    {Calendar.strftime(reminder, "%a %m/%d/%Y %-I:%M %p")}
                    <span :if={sent?(reminder)} class="text-text-secondary">
                      <.icon name="hero-check-circle-solid text-mbta-green" class="h-4 w-4" /> Sent
                    </span>

                    <span :if={!sent?(reminder)} class="text-text-secondary">
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
        <div class="min-w-[222px] shrink-0 p-4 bg-bg-elevation-5">
          <p class="font-bold">Created</p>
          <%= if @form_type == :creating do %>
            <p class="pb-3 whitespace-nowrap">
              {Calendar.strftime(
                DateTime.shift_zone!(@now, "America/New_York"),
                "%a %m/%d/%Y"
              )}
            </p>
          <% else %>
            <p class="pb-3 whitespace-nowrap">
              {Calendar.strftime(
                DateTime.shift_zone!(@created_at, "America/New_York"),
                "%a %m/%d/%Y, %-I:%M %p"
              )}
            </p>
          <% end %>

          <p class="font-bold">Created by</p>
          <%= if @form_type ==  :creating && @current_user do %>
            <p class="pb-3">
              {Map.get(@current_user, :first_name, "")} {Map.get(@current_user, :last_name, "")}
            </p>
          <% else %>
            <p :if={@created_by} class="pb-3">
              {@created_by}
            </p>
          <% end %>

          <%= if @last_edited_at || @form_type == :editing do %>
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
            <p :if={@form_type == :editing && @current_user} class="pb-3">
              {Map.get(@current_user, :first_name, "")} {Map.get(@current_user, :last_name, "")}
            </p>
            <p :if={@form_type != :editing && @last_edited_by} class="pb-3">
              {@last_edited_by}
            </p>
          <% end %>

          <.link
            :if={@alert_id}
            class="text-primary hover:text-primary-hover"
            href={~p"/download_history?alert_id=#{@alert_id}"}
            target="_blank"
          >
            <.icon name="hero-document-arrow-down-solid" class="w-4 h-4" /> Download history
          </.link>
        </div>
      </div>
      <%!-- Only override footer if we're not creating/reviewing edits --%>
      <:footer :if={!@form_type}>
        <div class="flex flex-row justify-end px-4 py-4 gap-2">
          <%!-- food for thought: should type=button be here or in the component? --%>
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
            class="ml-auto"
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
        </div>
      </:footer>
      <AlertsUIWeb.ReviewModal.confirm_close_modal
        id="close-alert-nested-modal"
        alert_id={@alert_id}
        on_accept={hide_modal(@id)}
      />
    </.modal>
    """
  end

  defp format_alert_status_text(alert) do
    alert
    |> ActiveStatus.get_alert_status()
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" / ", &String.capitalize/1)
  end

  defp sent?(reminder_time, now \\ DateTime.utc_now()) do
    reminder_time = ActivePeriodBuilder.naive_eastern_datetime_to_utc(reminder_time)
    DateTime.compare(now, reminder_time) in [:eq, :gt]
  end

  defp get_stop_names(%{stop_names: [_ | _] = stop_names}) do
    stop_names
  end

  defp get_stop_names(%{stop_ids: [_ | _] = stop_ids} = alert_data) do
    CreateAlertLive.get_stops(
      alert_data.route_ids,
      alert_data.route_type,
      Map.get(alert_data, :direction)
    )
    |> Enum.filter(fn stop -> stop.id in stop_ids end)
    |> Enum.map(fn stop -> SelectFormatter.name_for_option(stop) end)
    |> Enum.uniq()
  end

  defp get_stop_names(_alert_data), do: nil

  attr :id, :string,
    default: "close-alert-modal",
    doc: "The ID of the modal element. Will have the alert_id appended to it."

  attr :alert_id, :integer, required: true, doc: "The id of the alert we're dealing with"

  attr :target_id, :string,
    default: "",
    doc: "The ID of the element that should receive this modal's events"

  attr :rest, :global, include: ~w(on_cancel on_accept)

  def confirm_close_modal(assigns) do
    ~H"""
    <.modal
      id={"#{@id}-#{@alert_id}"}
      header_text="Close alert"
      cancel_event_name="cancelled_close_modal"
      accept_event_name="close_alert"
      cancel_button_text="Keep Active"
      accept_button_text="Close now"
      target_id="#view_alerts_live_view"
      class="text-text-primary min-w-[26rem]"
      inner_class="text-base font-light min-h-[72px]"
      cancel_button_classes="border-0 text-base"
      accept_button_classes="
              !text-white
              !bg-danger
              !border-danger
              hover:!bg-primary-hover
              hover:!border-primary-border-hover
              active:!bg-primary-active
              active:!border-primary-active
              focus:!border-primary-active
              text-base
              "
      value={@alert_id}
      {@rest}
    >
      Are you sure you want to close alert #{@alert_id}?
    </.modal>
    """
  end
end
