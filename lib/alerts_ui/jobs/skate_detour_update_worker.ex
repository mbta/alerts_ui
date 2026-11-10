defmodule AlertsUI.Jobs.SkateDetourUpdateWorker do
  @moduledoc """
  Oban worker that checks the skate detours file in S3 and closes any
  open alerts with skate detour ids that do not appear in that list
  """
  use Oban.Worker

  require Logger
  alias AlertsUI.AlertBuilder
  alias AlertsUI.Alerts
  alias AlertsUI.Models.{Alert, Cause}
  alias AlertsUI.SkateDetours.GetDetours
  alias AlertsUIWeb.CreateAlertLive.Helpers.AutoText.AlertDataToAutoText
  alias AlertsUIWeb.CreateAlertLive.Helpers.AutoText.Templates
  alias MBTAV3API.Routes.Route
  alias MBTAV3API.Stops.Repo, as: StopsRepo

  @impl Oban.Worker
  def perform(_job) do
    skate_detours = GetDetours.get_detours()
    ids_from_skate = Enum.map(skate_detours, & &1.id)

    {alerts_to_be_modified, alerts_closed_in_skate} =
      Alerts.get_open_skate_alerts() |> Enum.split_with(&(&1.skate_detour_id in ids_from_skate))

    modify_skate_alerts(alerts_to_be_modified, skate_detours)
    close_skate_detour_alerts(alerts_closed_in_skate)

    :ok
  end

  defp modify_skate_alerts([], _), do: :ok

  defp modify_skate_alerts(alerts_to_be_modified, skate_detours) do
    {modified_alerts, errored_alerts} =
      alerts_to_be_modified
      |> Enum.map(fn alert ->
        {alert, Enum.find(skate_detours, &(&1.id == alert.skate_detour_id))}
      end)
      |> Enum.filter(fn {existing_alert, detour} ->
        DateTime.compare(detour.updated_at, existing_alert.last_modified_timestamp) == :lt
      end)
      |> Enum.map(&modify_alert/1)
      |> Enum.split_with(fn {result, _alert} -> result == :ok end)

    Phoenix.PubSub.broadcast(
      AlertsUI.PubSub,
      "alerts",
      {:alerts_updated}
    )

    unless Enum.empty?(modified_alerts) do
      Logger.info(
        "Automatically updated the following Skate alerts: #{alert_ids_from_versions(modified_alerts)}"
      )
    end

    unless Enum.empty?(errored_alerts) do
      Logger.info(
        "There were errors updating the following Skate alerts: #{alert_ids_from_versions(errored_alerts)}"
      )
    end
  end

  defp alert_ids_from_versions(alerts),
    do: Enum.map_join(alerts, ", ", fn {:ok, alert} -> alert.model.alert_id end)

  defp modify_alert({existing_alert, detour}) do
    new_cause_detail =
      (Map.get(detour, :reason) || "") |> String.upcase() |> String.replace(" ", "_")

    new_cause = Cause.get_by_mode_and_detail(3, new_cause_detail)

    # the route and direction cannot change in a detour
    # therefore we can get these from existing alert data.
    [{direction_name, direction_id}] =
      Alert.get_original_names_and_ids(existing_alert.original_direction_selections)

    [{route_name, route_id}] =
      Alert.get_original_names_and_ids(existing_alert.original_route_selections)

    route = %Route{id: route_id, name: route_name, type: 3}

    new_stops = StopsRepo.all(["filter[id]": Enum.join(detour.missed_stops, ",")], [])
    new_connection_points = get_connection_points(detour)

    autotext_data =
      AlertDataToAutoText.build_autotext_data(%{
        route_type: 3,
        routes: [route],
        effect_name: "Detour",
        cause_detail: new_cause_detail,
        connection_points: new_connection_points,
        stops:
          Enum.map(
            new_stops,
            &Map.put(&1, :name, &1.name <> " (#{String.downcase(direction_name)})")
          ),
        service_types: [3],
        missed_stops: detour.missed_stops,
        direction: [String.to_integer(direction_id)]
      })

    new_header_text = Templates.build_auto_text(autotext_data, :header_template)
    new_description_text = Templates.build_auto_text(autotext_data, :description_template)
    new_service_effect_text = Templates.build_auto_text(autotext_data, :service_effect_template)

    stops_with_context =
      AlertBuilder.stops_with_context(
        [route],
        direction_id,
        detour.missed_stops
      )

    informed_entities =
      AlertBuilder.build_informed_entities(
        :RDS,
        %{
          stops_with_context: stops_with_context,
          route_types_by_id: %{route.id => 3},
          route_type: 3
        },
        "Detour"
      )

    new_alert_params = %{
      cause: new_cause,
      cause_detail: new_cause_detail,
      original_stop_selections: Enum.map(new_stops, &"#{&1.name}|#{&1.id}"),
      informed_entity: informed_entities,
      header_text: new_header_text,
      description_text: new_description_text,
      service_effect_text: new_service_effect_text,
      last_modified_timestamp: DateTime.now!("Etc/UTC")
    }

    existing_alert
    |> Alert.changeset(new_alert_params)
    |> PaperTrail.insert_or_update(user: nil, origin: "(updated automatically via Skate)")
  end

  defp close_skate_detour_alerts([]), do: :ok

  defp close_skate_detour_alerts(alerts_closed_in_skate) do
    closed_alert_ids =
      alerts_closed_in_skate
      |> Enum.map(
        &Alerts.close(
          &1,
          "(Closed automatically via Skate)",
          true,
          DateTime.now!("America/New_York") |> DateTime.truncate(:second)
        )
      )
      |> Enum.map_join(", ", & &1.alert_id)

    Logger.info("Automatically closed the following Skate alerts: #{closed_alert_ids}")
  end

  defp get_connection_points(%{connection_points: [_ | _] = connection_points}) do
    StopsRepo.all(["filter[id]": Enum.join(connection_points, ",")], []) |> Enum.map(& &1.name)
  end

  defp get_connection_points(%{connection_points: []}), do: []

  defp get_connection_points(_), do: nil
end
