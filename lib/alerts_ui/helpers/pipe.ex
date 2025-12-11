defmodule AlertsUI.Helpers.Pipe do
  @moduledoc """
  Helpers to assist with pipes
  """

  @spec default_to(any(), any()) :: any()
  def default_to(value, default) do
    value || default
  end
end
