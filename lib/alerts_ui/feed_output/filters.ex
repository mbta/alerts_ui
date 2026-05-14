defmodule AlertsUI.FeedOutput.Filters do
  @moduledoc """
  If Feeds need any specical filtering, it should go here.
  """

  alias AlertsUI.Models.Alert

  @doc """
  Keolis/SITA needs special filtering to remove stops and activities
  so the alerts can affect the whole Line.
  """
  @spec filter_sita_alerts([Alert.t()]) :: [Alert.t()]
  def filter_sita_alerts(alerts),
    do: alerts |> Enum.map(&filter_sita_alert/1)

  @spec filter_sita_alert(Alert.t()) :: Alert.t()
  def filter_sita_alert(alert) do
    if effect_matches?(alert) && commuter_rail?(alert) do
      alert
      |> filter_informed_entities()
    else
      alert
    end
  end

  defp effect_matches?(%{alert: %{effect_detail: %{translation: [%{text: effect_detail}]}}}) do
    effect_detail in ["SHUTTLE", "SUSPENSION", "STATION_CLOSURE"]
  end

  defp effect_matches?(%{
         "alert" => %{"effect_detail" => %{"translation" => [%{"text" => effect_detail}]}}
       }) do
    effect_detail in ["SHUTTLE", "SUSPENSION", "STATION_CLOSURE"]
  end

  defp effect_matches?(_), do: false

  defp commuter_rail?(%{alert: %{informed_entity: [%{route_type: 2} | _]}}) do
    true
  end

  defp commuter_rail?(%{"alert" => %{"informed_entity" => [%{"route_type" => 2} | _]}}) do
    true
  end

  defp commuter_rail?(_), do: false

  defp filter_informed_entities(%{alert: %{informed_entity: ie}} = alert) do
    Map.put(
      alert,
      :alert,
      Map.put(alert.alert, :informed_entity, ie |> remove_stop_and_activities())
    )
  end

  defp filter_informed_entities(%{"alert" => %{"informed_entity" => ie}} = alert) do
    Map.put(
      alert,
      "alert",
      Map.put(alert["alert"], "informed_entity", ie |> remove_stop_and_activities())
    )
  end

  defp remove_stop_and_activities(informed_entities),
    do:
      informed_entities
      |> Enum.map(fn entity ->
        entity
        |> Map.delete(:stop_id)
        |> Map.delete(:activities)
        |> Map.delete("stop_id")
        |> Map.delete("activities")
      end)
      |> Enum.uniq()
end
