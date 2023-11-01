defmodule AlertsUI.Support.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: AlertsUI.Repo

  alias AlertsUI.Models.{
    ActivePeriod,
    Alert,
    ExtendedTime,
    InformedEntity,
    TripDescriptor
  }

  def extended_time_factory, do: %ExtendedTime{relative_day: 1, time: ~T[12:12:12]}

  def informed_entity_factory, do: %InformedEntity{route_id: "1"}

  def trip_descriptor_factory, do: %TripDescriptor{trip_id: "1"}

  def informed_entity_with_trip_factory do
    %InformedEntity{route_id: "1", trip: build(:trip_descriptor)}
  end

  @spec active_period_factory() :: AlertsUI.Models.ActivePeriod.t()
  def active_period_factory do
    %ActivePeriod{start: ~U[2023-10-12 00:01:00Z], end: ~U[2023-10-13 00:01:00Z]}
  end

  def alert_factory do
    %Alert{
      alert_id: "123",
      header_text: "a",
      description_text: "b",
      active_period: [
        build(:active_period)
      ],
      informed_entity: [build(:informed_entity_with_trip)]
    }
  end

  def alert_map_factory do
    %{
      alert_id: "123",
      header_text: "a",
      description_text: "b",
      active_period: [
        %{
          start: ~U[2023-10-20 16:15:00Z],
          end: ~U[2023-10-20 18:45:38Z]
        }
      ],
      informed_entity: [%{route_id: "1", trip: %{trip_id: "2"}}]
    }
  end
end
