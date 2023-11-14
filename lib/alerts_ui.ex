defmodule AlertsUI do
  @moduledoc """
  AlertsUI keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def config(key) do
    Application.fetch_env!(:alerts_ui, key)
  end
end
