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
  alias AlertsUIWeb.CreateAlertLive.Helpers.SelectFormatter
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
      class="md:ml-auto"
    >
      <div class="flex flex-col gap-4 mb-4 md:flex-row md:items-center md:justify-evenly">
        <.filter_modal form={@form} filter_count={@filter_count} />
        <.radio_switch
          name="timeline"
          class="!mx-0"
          selected={@form[:timeline].value}
          default="current"
          values={timeline_options()}
          on_change={JS.push("paginate_start") |> JS.push("update_timeline_filter")}
        />
        <.text_input
          field={@form[:multi_column_search]}
          phx-debounce={750}
          placeholder="Search alerts"
          icon="hero-magnifying-glass-mini"
          class="h-[2.375rem] w-full"
          phx-change={JS.push("paginate_start") |> JS.push("apply_filter")}
          action_icon="hero-x-circle-solid"
          action_event={JS.push("paginate_start") |> JS.push("reset_text_filter")}
          action_name="Clear"
        />
      </div>
    </.form>
    """
  end

  @doc """
  Show the alerts filter modal

  ##Examples
    <.filter_modal form={@form} filter_count={@filter_count} />
  """

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
    button_classes = "
      !h-[38px]
      !min-h-0
      active:bg-secondary-active
      align-center
      bg-bg-elevation-3
      border
      border-bg-elevation-6
      disabled:border-secondary-disabled
      disabled:text-secondary-disabled
      flex
      flex-row
      focus:border-secondary-focus-border
      focus:shadow-secondary-focus-shadow
      hover:bg-bg-elevation-5
      hover:border-secondary-hover-border
      active:text-text-invert
      items-center
      join-item
      leading-tight
      min-h-[1.3rem]
      px-3
      rounded
      text-primary
      text-right
      transition-none
      cursor-pointer
    "

    active_button_classes =
      if assigns.filter_count > 0 do
        "!bg-secondary-active
        border-0
        hover:!bg-primary-hover
        !text-text-invert"
      else
        ""
      end

    button_label =
      if assigns.filter_count == 0 do
        "Filter"
      else
        "Filters: #{assigns.filter_count}"
      end

    assigns =
      assign(assigns, %{
        button_label: button_label,
        button_classes: button_classes,
        active_button_classes: active_button_classes
      })

    ~H"""
    <fieldset
      id={"filter-modal-#{@header_text}"}
      class="flex items-center leading-tight min-h-[1.3rem] text-right text-primary hover:text-primary-hover"
    >
      <.modal
        id="alerts-filter-modal"
        header_text={@header_text}
        cancel_event_name="cancel_filter_modal"
        button_type="submit"
        container_class="!w-[25rem]"
      >
        <.filter_modal_group
          field={@form[:service_type]}
          filter_field={@form[:service_type_search_term]}
          label="Service Types"
          options={
            SelectFormatter.formatted_select_options(%SelectFormatter{
              options: format_service_type_options(),
              search_term: assigns.form[:service_type_search_term].value,
              values_to_keep: List.wrap(assigns.form[:service_type].value),
              option_prefix: "service-type-filter"
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
              values_to_keep: List.wrap(assigns.form[:routes].value),
              option_prefix: "route-filter"
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
              values_to_keep: List.wrap(assigns.form[:effects].value),
              option_prefix: "effect-filter"
            })
          }
        />
        <:footer>
          <div class="flex flex-row justify-end px-4 py-4 gap-2">
            <.button_primary
              type="submit"
              phx-remove={hide_modal("alerts-filter-modal")}
              phx-click={
                JS.push("paginate_start")
                |> JS.push("apply_filter")
                |> JS.exec("phx-remove")
              }
            >
              Apply
            </.button_primary>
          </div>
        </:footer>
      </.modal>
      <div class="flex flex-row items-center join ">
        <button
          phx-click={show_modal("alerts-filter-modal")}
          class={[@button_classes, @active_button_classes]}
          type="button"
        >
          <span class={[
            "#{if @filter_count > 0, do: "hero-funnel-solid", else: "hero-funnel"} w-4 h-4 mr-1"
          ]} />
          {@button_label}
        </button>
        <span
          :if={@filter_count > 0}
          class={[@button_classes, @active_button_classes, "ms-px"]}
          phx-click={JS.push("paginate_start") |> JS.push("reset_modal_filters")}
          title="Clear filters"
        >
          <AlertsUIWeb.CoreComponents.icon name="hero-x-circle-solid" />
        </span>
      </div>
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
    <div class="group collapse rounded-none border-bg-elevation-6 border-b-[1px] first:border-t-0 last:border-b-0 has-[.trigger:checked]:border-b-0">
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
        <.icon
          name="hero-chevron-right"
          class="text-primary h-4 w-4 group-has-[.trigger:checked]:hidden"
        />
        <.icon
          name="hero-chevron-down"
          class="text-primary h-4 w-4 hidden group-has-[.trigger:checked]:block"
        />
      </label>
      <span
        :if={@field.value && @field.value != ["default"]}
        id={@field_string <> "-clear-filter-button"}
        phx-click="reset_filter"
        phx-value-filter-id={@field_string}
        class="hero-x-circle-mini w-4 h-4 bg-primary cursor-pointer absolute right-8 top-2.5"
      />
      <div class="collapse-content text-base !p-0">
        <.filtered_select class="h-[20rem]" field={@field} prompt="All" {@rest} />
      </div>
    </div>
    """
  end

  def format_effect_options do
    Effect.effects_tuples()
    |> Enum.map(fn {name, _, _} -> {name, name} end)
  end

  def format_routes_options do
    # get list of lists of routes, ordered by route type
    grouped_routes = Alerts.get_routes_grouped_by_mode()

    [
      Map.get(grouped_routes, 1, []) ++ Map.get(grouped_routes, 0, []),
      Map.get(grouped_routes, 2, []),
      Map.get(grouped_routes, 3, []),
      Map.get(grouped_routes, 4, [])
    ]
    # Within each group, sort alphanumerically
    |> Enum.flat_map(fn route_sub_list ->
      route_sub_list
      |> Enum.map(fn route -> parse_route_name(route) end)
      |> Enum.sort(&comparator/2)
      |> Enum.map(&build_route_option/1)
    end)
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
