defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.Params do
  @moduledoc """
  Utilities for dealing with incoming parameters.
  """

  def with_atomized_keys(params) do
    Enum.map(params, fn {original_key, original_value} ->
      key = String.to_existing_atom(original_key)

      value =
        if is_map(original_value) do
          with_atomized_keys(original_value)
        else
          original_value
        end

      {key, value}
    end)
    |> Enum.into(%{})
  end
end
