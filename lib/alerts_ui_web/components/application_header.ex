defmodule AlertsUIWeb.ApplicationHeader do
  @moduledoc """
  Component for the application header.
  """

  use Phoenix.Component
  use AlertsUIWeb, :verified_routes

  import AlertsUIWeb.CoreComponents
  import AlertsUIWeb.SharedComponents

  @doc """
  Renders the application header.
  """

  attr :environment, :string
  attr :show_alerts_table, :boolean, default: false
  attr :show_components_page, :boolean, default: false
  attr :show_validate_page, :boolean, default: false
  attr :current_user, :map, default: nil

  def application_header(assigns) do

    header_variants = %{
      "local" => "bg-mbta-the-ride/25 before:bg-mbta-the-ride",
      "dev-green" => "bg-mbta-green/25 before:bg-mbta-green",
      "dev-orange" => "bg-mbta-orange/25 before:bg-mbta-orange",
      "staging" => "bg-mbta-commuter-rail/25 before:bg-mbta-commuter-rail"
    }

    assigns = assign(assigns, header_variants: header_variants)

    ~H"""
    <header class="bg-secondary">
      <div class={"flex items-center justify-between py-4 text-sm before:absolute before:top-0 before:left-0 before:right-0 before:h-3 #{@header_variants[@environment]}"}>
        <div class="flex items-center gap-4 mx-4">
          <a href="/"><img class="h-12" src={"/images/logos/logo-#{@environment}.svg"} /></a>
          <.h1 class="!mb-0"><a href="/">Alerts Manager </a></.h1>
          <div
            :if={@environment != "prod"}
            class={"text-center font-bold py-1 px-4 rounded-md bg-#{%{
              "local" => "mbta-the-ride",
              "dev-green" => "mbta-green",
              "dev-orange" => "mbta-orange",
              "staging" => "mbta-commuter-rail"
            }[@environment]}"}
          >
            {@environment}
          </div>
        </div>
        <div class="flex items-center gap-4 leading-6 mx-4">
          <a
            :if={@show_alerts_table}
            href="/db"
            class="text-primary hover:underline active:text-primary-hover"
          >
            Alerts DB Table
          </a>
          <a
            :if={@show_components_page}
            href="/components"
            class="text-primary hover:underline active:text-primary-hover"
          >
            Components
          </a>
          <a
            :if={@show_validate_page}
            href="/validate"
            class="text-primary hover:underline active:text-primary-hover"
          >
            Validate Feeds
          </a>
          <div :if={@current_user} class="whitespace-nowrap hidden lg:block">
            <.icon name="hero-user-solid" />
            {@current_user.email}
          </div>
          <.link
            href={~p"/help"}
            class="text-sm leading-6 text-primary hover:underline hover:text-primary-hover whitespace-nowrap"
          >
            <.icon name="hero-question-mark-circle" class="mx-1" />Help
          </.link>
          <.link
            :if={@current_user}
            href={~p"/auth/keycloak/logout"}
            method="delete"
            class="text-sm leading-6 text-primary hover:underline hover:text-primary-hover whitespace-nowrap"
          >
            <.icon name="hero-arrow-right-on-rectangle" class="mx-1" />Logout
          </.link>
          <.link
            :if={!@current_user}
            href={~p"/auth/keycloak"}
            class="text-sm leading-6 text-primary hover:underline hover:text-primary-hover whitespace-nowrap"
          >
            <.icon name="hero-arrow-left-on-rectangle" class="mx-1" />Login
          </.link>
        </div>
      </div>
    </header>
    """
  end
end
