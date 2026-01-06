defmodule AlertsUIWeb.FilterForm do
  @moduledoc """
  Components for the filtering on the View Alerts page.
  Originally, these were in SharedComponents in the hopes of reusability,
  but the components ended up pretty tied to the Flop table, so now
  they embrace being speciialized.
  """
  use Phoenix.Component
  use AlertsUIWeb, :verified_routes

  import AlertsUIWeb.CoreComponents
  import AlertsUIWeb.SharedComponents

  alias AlertsUI.Alerts
  alias AlertsUI.Models.Effect
  alias AlertsUIWeb.FormComponents.Helpers.SelectFormatter
  alias Phoenix.HTML.{Form, FormField}
  alias Phoenix.LiveView.JS

  @spec filter_form(map()) :: Phoenix.LiveView.Rendered.t()
  @doc """
  Renders the View Alerts page Filter form, including the button for filter modal,
  the timeline radio buttons, and the reset button.

  ##Examples
    <.filter_form form={@form} filter_count={@filter_count} />
  """

  attr :form, Form, required: true
  attr :filter_count, :integer, required: true

  def filter_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="alert-filter-form"
      phx-submit="apply_filter"
      phx-change="edit_filter"
      class="ml-auto"
    >
      <div class="mb-4 ml-2 flex flex-row gap-2 items-center">
        <.filter_modal form={@form} filter_count={@filter_count} />
        <.radio_switch
          name="timeline"
          class="!mx-0"
          selected={@form[:timeline].value}
          default="current"
          values={timeline_options()}
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

  @doc """
  Show the alerts filter modal

  ##Examples
    <.filter_modal form={@form} filter_count={@filter_count} />
  """

  attr :button_label, :string, default: "Filters"
  attr :filter_count, :integer, required: true
  attr :form, Form, required: true
  attr :header_text, :string, default: "Filters"

  # In this PR https://github.com/mbta/alerts_ui/pull/281 it was decided
  # that the filtering in filtered_select shouldn't happen in the filtered_select
  # but in the parent component.
  #
  # I think I disagree? It's misleading that the component that does the filtering
  # actually expects its parent to do the filtering.
  #
  # Or is this because it's really hard to refilter with values_to_keep?
  # So when the selections are edited, the options *should* be recalculated?
  #
  # In the meantime, I'm going to use that logic when populating the options of all
  # this filter_modal_group because refactoring the filtered_select would
  # touch too much code right now

  def filter_modal(assigns) do
    ~H"""
    <fieldset id={"filter-modal-#{@header_text}"}>
      <.modal
        id="alerts-filter-modal"
        header_text={@header_text}
        cancel_event_name="cancel_filter_modal"
        button_type="submit"
      >
        <.filter_modal_group
          field={@form[:service_type]}
          filter_field={@form[:service_type_search_term]}
          label="Service Types"
          options={
            SelectFormatter.formatted_select_options(%SelectFormatter{
              options: format_service_type_options(),
              search_term: assigns.form[:service_type_search_term].value,
              values_to_keep: List.wrap(assigns.form[:service_type].value)
            })
          }
        />
        <.filter_modal_group
          field={@form[:routes]}
          filter_field={@form[:routes_search_term]}
          label="Routes"
          options={
            SelectFormatter.formatted_select_options(%SelectFormatter{
              options: format_routes_options(),
              search_term: assigns.form[:routes_search_term].value,
              values_to_keep: List.wrap(assigns.form[:routes].value)
            })
          }
        />
        <.filter_modal_group
          field={@form[:effects]}
          filter_field={@form[:effects_search_term]}
          label="Effects"
          options={
            SelectFormatter.formatted_select_options(%SelectFormatter{
              options: format_effect_options(),
              search_term: assigns.form[:effects_search_term].value,
              values_to_keep: List.wrap(assigns.form[:effects].value)
            })
          }
        />
        <:footer>
          <div class="flex flex-row justify-end px-4 py-4 gap-2">
            <.button_secondary type="button" class="ml-auto" phx-click={JS.push("reset_filter")}>
              Reset
            </.button_secondary>
            <.button_primary
              type="submit"
              phx-remove={hide_modal("alerts-filter-modal")}
              phx-click={
                JS.push("apply_filter")
                |> JS.exec("phx-remove")
              }
            >
              Apply
            </.button_primary>
          </div>
        </:footer>
      </.modal>
      <button
        phx-click={show_modal("alerts-filter-modal")}
        class="flex items-center leading-tight min-h-[1.3rem] text-right text-primary hover:underline hover:text-primary-hover"
        type="button"
      >
        <span class={[
          "hero-funnel-mini w-4 h-4 mr-1"
        ]} />
        {@button_label <> " (" <> Integer.to_string(@filter_count) <> ")"}
      </button>
    </fieldset>
    """
  end

  @doc """
  A collapsible group of Filter Options for the Modal

  ##Examples
    <.filter_modal_group
      field={@form[:service_type]}
      filter_field={@form[:service_type_search_term]}
      label="Service Types"
      options={
        SelectFormatter.formatted_select_options(
          %SelectFormatter{
            options: format_service_type_options(),
            search_term: assigns.form[:service_type_search_term].value,
            values_to_keep: List.wrap(assigns.form[:service_type].value)
          }
        )
      }
    />
    <.filter_modal_group
      field={@form[:routes]}
      filter_field={@form[:routes_search_term]}
      label="Routes"
      options={
        SelectFormatter.formatted_select_options(
          %SelectFormatter{
            options: format_routes_options(),
            search_term: assigns.form[:routes_search_term].value,
            values_to_keep: List.wrap(assigns.form[:routes].value)
          }
        )
      }
    />
    <.filter_modal_group
      field={@form[:effects]}
      filter_field={@form[:effects_search_term]}
      label="Effects"
      options={
        SelectFormatter.formatted_select_options(
          %SelectFormatter{
            options: format_effect_options(),
            search_term: assigns.form[:effects_search_term].value,
            values_to_keep: List.wrap(assigns.form[:effects].value)
          }
        )
      }
    />
  """
  attr :field, FormField, required: true
  attr :label, :string, required: true
  attr :name, :string, default: "my-accordion"
  attr :open, :boolean, default: false
  attr :rest, :global, include: ~w(filter_field options)

  def filter_modal_group(assigns) do
    assigns = assign(assigns, field_string: assigns.field.field |> to_string())

    ~H"""
    <div class="collapse rounded-none border-bg-elevation-6 border-b-[1px] first:border-t-0 last:border-b-0 has-[.trigger:checked]:border-b-0">
      <input
        id={@field_string <> "_filter"}
        type="radio"
        class="trigger absolute hidden"
        name={"#{@name}-section"}
        checked={@open}
        phx-update="ignore"
      />
      <label
        for={@field_string <> "_filter"}
        class="collapse-label min-h-0 flex flex-row items-center p-2 leading-[20px]"
      >
        <h3 class="font-medium mr-auto">{@label}</h3>
        <span
          :if={@field.value && @field.value != ["default"]}
          id={@field_string <> "-clear-filter-button"}
          phx-click="reset_filter"
          phx-value-filter-id={@field_string}
          class="hero-x-circle-mini w-4 h-4 bg-primary mr-3 cursor-pointer"
        />
        <.icon
          name="hero-chevron-right"
          class="text-primary h-4 w-4 group-has-[.trigger:checked]:rotate-90"
        />
      </label>
      <div class="collapse-content text-base !p-0">
        <.filtered_select
          class="h-[20rem]"
          field={@field}
          hook="SelectAllAdjuster"
          prompt="All"
          {@rest}
        />
      </div>
    </div>
    """
  end

  def format_effect_options do
    Effect.effects_tuples()
    |> Enum.map(fn {name, _, _} -> {name, name} end)
  end

  def format_routes_options do
    grouped_routes = Alerts.get_routes_grouped_by_mode()

    # Properly organizing by mode: Bus, Subway, CR, Ferry
    [
      Map.get(grouped_routes, 3, []),
      Map.get(grouped_routes, 1, []),
      Map.get(grouped_routes, 2, []),
      Map.get(grouped_routes, 4, [])
    ]
    # Within each group, sort alphanumerically
    |> Enum.map(fn route_sub_list ->
      route_sub_list
      |> Enum.map(fn route -> parse_route_name(route) end)
      |> Enum.sort(&comparator/2)
      |> Enum.map(&build_route_option/1)
    end)
    |> List.flatten()
  end

  defp comparator({a, _}, {b, _}) when is_integer(a) and is_integer(b), do: a <= b
  defp comparator({a, _}, _) when is_integer(a), do: false
  defp comparator(_, {b, _}) when is_integer(b), do: true
  defp comparator({a, _}, {b, _}), do: a <= b

  # Turns strings into sortable integers, if relevant
  defp parse_route_name({route_name, _route_type, route_id}) do
    case Integer.parse(route_name) do
      :error -> {route_name, route_id}
      {result, _rest} -> {result, route_id}
    end
  end

  # Stringify the route again, so the SelectFormatter works properly
  defp build_route_option({route_name, route_id}) when is_integer(route_name),
    do: {Integer.to_string(route_name), route_id}

  defp build_route_option(route), do: route

  def format_service_type_options do
    [
      {"Bus", 3},
      {"Subway", :subway},
      {"Commuter Rail", 2},
      {"Ferry", 4},
      {"Facility", :access},
      {"Systemwide", :systemwide}
    ]
  end

  def timeline_options, do: ["current", "future", "past", "all"]
end
