defmodule AlertsUI.FeatureFlags do
  @moduledoc """
  Manage and use Feature Flags (AlertsUI.Models.FeatureFlag)
  """
  use AlertsUI.Schema
  import Ecto.Query

  alias AlertsUI.Models.FeatureFlag
  alias AlertsUI.Repo

  @spec enabled?(String.t()) :: boolean()
  def enabled?(name) do
    flag = get(name)

    if is_nil(flag) do
      false
    else
      flag.enabled
    end
  end

  @spec enable(String.t()) :: boolean()
  def enable(name), do: set(name, true)

  @spec disable(String.t()) :: boolean()
  def disable(name), do: set(name, false)

  defp set(name, state) do
    flag = get(name)

    if is_nil(flag) do
      false
    else
      flag
      |> FeatureFlag.changeset(%{enabled: state})
      |> Repo.update()
      |> case do
        {:ok, _} -> true
        {:error, _} -> false
      end
    end
  end

  defp get(name), do: Repo.one(from ff in FeatureFlag, where: ff.name == ^name)
end
