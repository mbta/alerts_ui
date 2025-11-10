defmodule AlertsUI.Models.LatestIBIAlert do
  @moduledoc """
  A view representing the latest version of each alert.
  """

  use AlertsUI.Schema

  schema "latest_ibi_alerts" do
    Enum.each(AlertsUI.Models.IBIAlert.fields(), fn field_name -> field field_name, :string end)
    timestamps()
  end
end
