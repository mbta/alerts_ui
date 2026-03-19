defmodule AlertsUI.FeatureFlags do
  @moduledoc """
  Manage and use Feature Flags (AlertsUI.Models.FeatureFlag)
  """
  use AlertsUI.Schema
  import Ecto.Query

  alias AlertsUI.Models.FeatureFlag
  alias AlertsUI.Repo

  @spec enabled?(String.t()) :: boolean()
  def enabled?(name), do: get_or_create(name).enabled

  @spec enable(String.t()) :: boolean()
  def enable(name), do: set(name, true)

  @spec disable(String.t()) :: boolean()
  def disable(name), do: set(name, false)

  defp set(name, state) do
    get_or_create(name)
    |> FeatureFlag.changeset(%{enabled: state})
    |> Repo.update()
    |> case do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp get_or_create(name) do
    case get(name) do
      nil ->
        FeatureFlag.build(name)
        |> Repo.insert_or_update!()

      feature_flag ->
        feature_flag
    end
  end

  defp get(name), do: Repo.one(from ff in FeatureFlag, where: ff.name == ^name)
end
