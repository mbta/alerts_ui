defmodule AlertsUIWeb.FeatureFlagsLive do
  @moduledoc """
  LiveView for toggling feature flags
  """

  use AlertsUIWeb, :live_view
  alias AlertsUI.Models.FeatureFlag
  alias AlertsUI.Repo

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, flags: get_flags())}
  end

  @impl true
  def handle_event("toggle", %{"flag_id" => flag_id}, socket) do
    flag_id
    |> get_flag()
    |> FeatureFlag.toggle()
    |> Repo.update!()

    {:noreply, assign(socket, flags: get_flags())}
  end

  defp get_flags do
    Repo.all(from ff in FeatureFlag, order_by: ff.name)
  end

  defp get_flag(id) do
    Repo.one(from ff in FeatureFlag, where: ff.id == ^id)
  end
end
