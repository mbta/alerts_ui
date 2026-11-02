defmodule AlertsUI.ActiveStatus do
  @moduledoc """
    Current / Future / Past state of an Alert
  """

  alias AlertsUI.Models.Alert
  alias AlertsUIWeb.Helpers.DateTimeHelpers, as: DTHelpers

  @type status :: :published_current | :published_upcoming | :future | :past

  @spec get_alert_status(Alert.t()) :: status()
  def get_alert_status(alert) do
    nps = Map.get(alert, :notification_period_start)
    npe = Map.get(alert, :notification_period_end)
    aps = Map.get(alert, :active_period_start)
    ape = Map.get(alert, :active_period_end)
    closed_timestamp = Map.get(alert, :closed_timestamp)

    cond do
      # If there's a closed time at all, alert is past
      !is_nil(closed_timestamp) ->
        :past

      # If end of notification period is over, alert is past
      DTHelpers.time_is_past?(npe) ->
        :past

      # If end of active period is over, alert is past
      DTHelpers.time_is_past?(ape) ->
        :past

      # If effect start has already begun (but alert isn't closed), alert is happening
      DTHelpers.time_is_past?(aps) ->
        :published_current

      # If notification period has started but active period hasn't, alert is published / upcoming
      DTHelpers.time_is_past?(nps) && DTHelpers.time_is_in_future?(aps) ->
        :published_upcoming

      true ->
        :future
    end
  end
end
