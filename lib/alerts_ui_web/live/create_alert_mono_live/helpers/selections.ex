defmodule AlertsUIWeb.CreateAlertMonoLive.Helpers.Selections do
  @moduledoc """
  Helpers for working with async selections assigns in the mono alert form.
  Provides `assign_unwrapped_selections/2` to safely unwrap an `AsyncResult`
  into its resolved value (or a default) for use in LiveView templates.
  """

  require Logger

  use AlertsUIWeb, :html

  def selections_loading?(%{loading: true}), do: true
  def selections_loading?(_), do: false
end
