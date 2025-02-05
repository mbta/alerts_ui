defmodule AlertsUI.Routes do
  @moduledoc """
  Context for working with Routes.
  """

  alias MBTAV3API.Routes.Route

  @green_line_branch_ids ["Green-E", "Green-D", "Green-C", "Green-B"]

  @doc """
  Takes a list of route IDs and expands the virtual Green line route to turn it
  into all of the green line branches. Returns only unique route IDs.

  ## Examples

      iex> Routes.expanding_green_line(["39", "Green", "Red", "Green-C"])
      ["39", "Green-B", "Green-C", "Green-D", "Green-E", "Red"]
  """
  @spec expanding_green_line([Route.t()]) :: [Route.t()]
  def expanding_green_line(route_ids) do
    route_ids
    |> Enum.flat_map(fn route_id ->
      if route_id == "Green" do
        @green_line_branch_ids
      else
        [route_id]
      end
    end)
    |> Enum.uniq()
  end

  @spec green_line_branch_ids :: [Route.id_t()]
  def green_line_branch_ids, do: @green_line_branch_ids

  @doc """
  Provide the Agency ID for the given route or route ID.

  ## Examples

      iex> Routes.agency_id(%Route{id: "Red"})
      "1"
      iex> Routes.agency_id(%Route{id: "CapeFlyer"})
      "3"
      iex> Routes.agency_id("Red")
      "1"
      iex> Routes.agency_id("CapeFlyer")
      "3"
  """
  @spec agency_id(Route.t() | Route.id_t()) :: String.t()
  def agency_id(%Route{id: route_id}), do: agency_id(route_id)
  def agency_id("CapeFlyer"), do: "3"
  def agency_id(_), do: "1"
end
