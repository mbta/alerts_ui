defmodule AlertsUIWeb.CreateAlertLive.Title do
  use AlertsUIWeb, :html

  @cute_noise_map %{
    subway: "ding ding",
    bus: "beep beep",
    commuter_rail: "choo choo",
    ferry: "🐳"
  }

  def render(assigns) do
    icon_name =
      assigns.route_type_name
      |> String.downcase()
      |> String.replace(" ", "_")
      |> String.to_existing_atom()

    title = Map.get(@cute_noise_map, icon_name, assigns.route_type_name)
    assigns = Map.merge(assigns, %{title: title, icon_name: icon_name})

    ~H"""
    <.h1>
      <div class="flex flex-row justify-center items-center">
        <div class="mr-2 self-center">
          <.circle_icon type={@icon_name} size={35} title={@title} />
        </div>
        {@route_type_name} • {@effect_name}
      </div>
    </.h1>
    """
  end
end
