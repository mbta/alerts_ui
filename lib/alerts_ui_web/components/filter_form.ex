defmodule AlertsUIWeb.FilterForm do
  @moduledoc """
  Component for the filtering on the View Alerts page
  """
  use Phoenix.Component
  use AlertsUIWeb, :verified_routes

  import AlertsUIWeb.CoreComponents
  import AlertsUIWeb.SharedComponents

  # todo: need to remove "any"
  attr :form, :any, required: true
  attr :filter_count, :integer, required: true

  def filter_form(assigns) do
    ~H"""
    <.form for={@form} id="alert-filter-form" phx-submit="apply_filter" phx-change="edit_filter">
      <div class="mb-4 ml-2 flex flex-row gap-2 items-center">
        <.filter_modal form={@form} filter_count={@filter_count} />
        <.radio_switch
          name="timeline"
          class="!mx-0"
          selected={@form[:timeline]}
          default="current"
          values={AlertsUIWeb.ViewAlertsLive.timeline_options()}
          on_change="update_timeline_filter"
        />
        <.text_input
          field={@form[:multi_column_search]}
          phx-debounce={750}
          placeholder="Search alerts"
          icon="hero-magnifying-glass-mini"
          class="h-[2.375rem]"
          phx-change="apply_filter"
        />
        <.button_secondary class="btn-outline" name="reset">
          Reset
        </.button_secondary>
      </div>
    </.form>
    """
  end
end
