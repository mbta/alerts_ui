defmodule AlertsUIWeb.ReviewModal do
  @moduledoc """
  Component for the review modal with alert details and delivery preview
  """
  use Phoenix.Component

  import AlertsUIWeb.CoreComponents
  import AlertsUIWeb.SharedComponents

  alias AlertsUI.ActivePeriodBuilder
  alias AlertsUI.Models.SeverityLevel
  alias AlertsUIWeb.FormComponents.Helpers.{RecurringDurationText, TimeRangeDurationText}

  @doc """
  Renders the review modal. The fields passed as props are determined by its 
  parent com

  ## Examples
    <.review_modal
      cancel_event_name="cancel_review"
      accept_event_name="save"
      target_id="#submit_view"
    />
  """
  attr :alert_data, :map, default: %{}, doc: "The user selections that make up alert_data"
  attr :rest, :global, include: ~w(cancel_event_name accept_event_name target_id)

  def review_modal(assigns) do
    assigns = assign(assigns, now: DateTime.utc_now())

    ~H"""
    <.modal
      id="review-modal"
      show={true}
      header_text="Create new alert"
      cancel_button_text="Keep editing"
      accept_button_text="Submit"
      class="w-[800px]"
      inner_class="!p-0"
      {@rest}
    >
      <:header>
        <div>
          <p class="text-lg/6">Create new alert</p>
          <p class="text-text-secondary text-base/6 font-bold">
            [Service Type] • {@alert_data.effect_name}
          </p>
        </div>
      </:header>
      <div class="flex text-sm/2">
        <%!-- Main lefthand content --%>
        <div class="p-4">
          <%!-- Top section --%>
          <p class="font-bold">Main message</p>
          <p class="pb-4">{@alert_data.header_text}</p>

          <div class="pb-4">
            <p class="font-bold">Supporting information</p>
            <%= if @alert_data.description_text do %>
              <p>{@alert_data.description_text}</p>
            <% else %>
              <p class="italic">None</p>
            <% end %>

            <span :if={@alert_data.url} class="text-text-secondary">
              URL: {@alert_data.url}
            </span>
          </div>

          <p class="font-bold">Affected service</p>
          <div class="pb-4 grid grid-cols-[100px_auto]">
            <%= if Map.get(@alert_data, :route_ids, []) != [] do %>
              <p>Routes:</p>
              <p :if={@alert_data.route_ids != []}>
                {Enum.join(@alert_data.route_ids, ", ")}
              </p>
            <% end %>
            <%= if Map.get(@alert_data, :direction, "default") != "default" do %>
              <p>Direction:</p>
              <p>{String.capitalize(@alert_data.direction)}</p>
            <% end %>
            <%= if Map.get(@alert_data, :stop_ids, []) != [] do %>
              <p>Stops:</p>
              <p>{Enum.join(@alert_data.stop_ids, ", ")}</p>
            <% end %>
            <%= if Map.get(@alert_data, :trip_ids, []) != [] do %>
              <p>Trips:</p>
              <p>{Enum.join(@alert_data.trip_ids, ", ")}</p>
            <% end %>
            <%= if Map.get(@alert_data, :facility_id, nil) do %>
              <p>Facility:</p>
              <p>{@alert_data.facility_id}</p>
            <% end %>
          </div>

          <%!-- Image --%>
          <%!-- Next PR --%>

          <%!-- Middle section --%>
          <div class="grid grid-cols-[110px_auto] gap-x-2">
            <p class="font-bold pb-1">Cause</p>
            <%= if @alert_data.cause_detail != "" do %>
              <p class="pb-1">{String.capitalize(@alert_data.cause_detail)}</p>
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
              <p class="pb-1">
                {TimeRangeDurationText.one_time_duration_text(%{
                  "active_period_start" => @alert_data.active_period_start,
                  "active_period_end" => @alert_data.active_period_end,
                  "active_period_start_specifier" => @alert_data.active_period_start_specifier,
                  "active_period_end_specifier" => @alert_data.active_period_end_specifier
                })}
              </p>
            <% else %>
              <p class="pb-1">
                {RecurringDurationText.recurring_duration_text(
                  assign(assigns,
                    form: %{
                      params: %{
                        "active_period_start_time" => @alert_data.active_period_start_time,
                        "active_period_end_time" => @alert_data.active_period_end_time,
                        "active_period_start_date" => @alert_data.active_period_start_date,
                        "active_period_end_date" => @alert_data.active_period_end_date,
                        "recurrence_days" => @alert_data.recurrence_days,
                        "active_period_end_specifier" => @alert_data.active_period_end_specifier
                      }
                    }
                  )
                )}
              </p>
            <% end %>

            <p class="font-bold pb-1">Notification period</p>
            <%= if Map.get(@alert_data, :notification_specifier, :same_as_effect_period) === :same_as_effect_period do %>
              <p class="pb-1">Same as effect period</p>
            <% else %>
              <p class="pb-1">
                {TimeRangeDurationText.one_time_duration_text(%{
                  "active_period_start" => @alert_data.notification_period_start,
                  "active_period_end" => nil,
                  "active_period_start_specifier" => @alert_data.notification_specifier,
                  "active_period_end_specifier" => :until_further_notice
                })}
              </p>
            <% end %>

            <p class="font-bold pb-1">Reminders</p>
            <%= if @alert_data.reminder_times != [] do %>
              <div class="pb-4">
                <%= for reminder <- Enum.sort(@alert_data.reminder_times) do %>
                  <p>
                    {Calendar.strftime(reminder, "%a %m/%d/%Y %I:%M %p")}
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

          <%!-- Bottom section --%>
          <hr class="border-border-primary pb-4" />
          <details>
            <summary class="font-bold pb-4">Preview subheader TBD</summary>
            <div class="ps-4">
              <p class="font-bold">Web Banner</p>
              <%= if @alert_data.view_banner do %>
                <p class="pb-6">{@alert_data.banner_text}</p>
              <% else %>
                <p class="pb-6 italic">Not selected</p>
              <% end %>

              <p class="font-bold">SMS</p>
              <%= if @alert_data.notification_toggle do %>
                <p class="pb-6">To be populated when we build this out later</p>
              <% else %>
                <p class="pb-6 italic">Not selected</p>
              <% end %>

              <p class="font-bold">Email</p>
              <%= if @alert_data.notification_toggle do %>
                <p class="pb-6">To be populated when we build this out later</p>
              <% else %>
                <p class="pb-6">To be populated when we build this out later</p>
              <% end %>
            </div>
          </details>
        </div>
        <%!-- Sidebar --%>
        <div class="w-[222px] shrink-0 p-4 bg-bg-elevation-5">
          <p class="font-bold">Created</p>
          <p class="pb-3">
            {Calendar.strftime(DateTime.shift_zone!(@now, "America/New_York"), "%Y-%m-%d")}
          </p>
          <p class="font-bold">Created by</p>
          <p class="pb-3">TO BE DONE</p>
          <%!-- 
            The edited items need to be wrapped in a conditional, but let's do that once
            we have a value to match on in the alert_data
          --%>
          <p class="font-bold">Last edited</p>
          <p class="pb-3">TO BE DONE</p>
          <p class="font-bold">Last edited by</p>
          <p class="pb-3">TO BE DONE</p>
        </div>
      </div>
    </.modal>
    """
  end

  defp sent?(reminder_time, now \\ DateTime.utc_now()) do
    reminder_time = ActivePeriodBuilder.naive_eastern_datetime_to_utc(reminder_time)
    DateTime.compare(now, reminder_time) in [:eq, :gt]
  end
end
