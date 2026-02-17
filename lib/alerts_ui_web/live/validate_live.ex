defmodule AlertsUIWeb.ValidateLive do
  @moduledoc """
  LiveView for validating our alert feed compared with the previous version.
  """
  use AlertsUIWeb, :live_view

  alias AlertsUI.FeedOutput.CompareFeed
  alias AlertsUI.FeedReader

  def mount(_params, _session, socket) do
    {:ok, ibi_json} = FeedReader.ibi_json()
    {:ok, ibi_data} = Jason.decode(ibi_json)

    {:ok, alerts_manager_json} = FeedReader.alerts_manager_json()
    {:ok, dev_orange_data} = Jason.decode(alerts_manager_json)

    {:ok,
     assign(socket,
       page_title: "Validate Feeds",
       ibi_json: ibi_json,
       ibi_data: ibi_data,
       ibi_alert_data: nil,
       ibi_alert_id: "",
       alerts_manager_json: alerts_manager_json,
       dev_orange_data: dev_orange_data,
       dev_orange_alert_data: nil,
       dev_orange_alert_id: "",
       comparison: nil
     )}
  end

  def handle_event("search", %{"ibi_alert_id" => ibi_alert_id}, socket) do
    ibi_alert_data = find_alert(socket.assigns.ibi_data, ibi_alert_id)

    comparison =
      compare_alert_informed_entities(ibi_alert_data, socket.assigns.dev_orange_alert_data)

    {:noreply,
     assign(socket,
       ibi_alert_id: ibi_alert_id,
       ibi_alert_data: ibi_alert_data,
       comparison: comparison
     )}
  end

  def handle_event("search", %{"dev_orange_alert_id" => dev_orange_alert_id}, socket) do
    dev_orange_alert_data = find_alert(socket.assigns.dev_orange_data, dev_orange_alert_id)

    comparison =
      compare_alert_informed_entities(socket.assigns.ibi_alert_data, dev_orange_alert_data)

    {:noreply,
     assign(socket,
       dev_orange_alert_id: dev_orange_alert_id,
       dev_orange_alert_data: dev_orange_alert_data,
       comparison: comparison
     )}
  end

  def pretty_print(obj), do: inspect(obj, pretty: true)

  defp find_alert(json, id) do
    json
    |> alerts()
    |> Enum.find(:not_found, &matches_id?(&1, id))
  end

  defp alerts(json), do: Map.get(json, "entity")

  defp matches_id?(%{"id" => alert_id}, id), do: alert_id == id

  defp compare_alert_informed_entities(nil, _dev_orange_alert_data), do: nil
  defp compare_alert_informed_entities(_ibi_alert_data, nil), do: nil
  defp compare_alert_informed_entities(:not_found, _dev_orange_alert_data), do: nil
  defp compare_alert_informed_entities(_ibi_alert_data, :not_found), do: nil

  defp compare_alert_informed_entities(ibi_alert_data, dev_orange_alert_data) do
    CompareFeed.compare_informed_entities(
      informed_entities(ibi_alert_data),
      informed_entities(dev_orange_alert_data),
      ibi_alert_data["id"]
    )
  end

  defp informed_entities(alert_data), do: get_in(alert_data, ["alert", "informed_entity"])
end
