defmodule AlertsUIWeb.Layouts do
  @moduledoc """
  Render page layouts.
  """

  use AlertsUIWeb, :html

  import AlertsUIWeb.ApplicationHeader

  embed_templates "layouts/*"
end
