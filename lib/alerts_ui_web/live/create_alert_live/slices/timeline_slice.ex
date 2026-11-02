defmodule AlertsUIWeb.CreateAlertLive.Slices.TimelineSlice do
  @moduledoc """
  Slice that tracks multi-step form progress and renders the step-navigation
  header bar. Gets the list of "Step" structs from the assigns and
  managers the currently active step.
  """

  alias AlertsUIWeb.CreateAlertLive.AlertData
  alias AlertsUIWeb.CreateAlertLive.Slice
  alias AlertsUIWeb.CreateAlertLive.Step

  use AlertsUIWeb, :html

  defstruct [
    :route_type,
    :effect_name
  ]

  defimpl Slice, for: __MODULE__ do
    def mount(_timeline_data, socket, _base_params), do: socket

    def extract(timeline_data, %AlertData{}, _params) do
      struct(timeline_data)
    end

    def transform(_timeline_data, changeset, _params, _socket) do
      changeset
    end

    def validate(_timeline_data, changeset, _params, _socket) do
      changeset
    end

    def assigns(_timeline_data, socket, params) do
      steps = socket.assigns.steps

      progress =
        Map.get(
          socket.assigns,
          :progress,
          progress_on_mount(params, socket.assigns.live_action, steps)
        )

      assign(socket,
        previous_steps: previous_steps(progress, steps),
        progress: progress,
        form_type: socket.assigns.form_type
      )
    end

    @spec previous_steps(Step.t(), [Step.t()], [String.t()]) :: [String.t()]
    def previous_steps(current_step, steps, acc \\ [])

    def previous_steps(%Step{previous: nil} = current_step, _steps, acc),
      do: acc ++ [current_step.name]

    def previous_steps(nil, _, _), do: []

    def previous_steps(current_step, steps, acc) do
      previous_steps(find_previous_step(current_step, steps), steps, acc ++ [current_step.name])
    end

    def find_previous_step(nil, _), do: nil

    def find_previous_step(current_step, steps) do
      Enum.find(steps, &(&1.name == current_step.previous))
    end

    defp progress_on_mount(params, action, [first_step, second_step | _]) do
      route_type = Map.get(params, "route_type")
      effect = Map.get(params, "effect_name")

      if action == :new && (is_nil(route_type) || is_nil(effect)) do
        first_step
      else
        second_step
      end
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-wrap md:flex-nowrap flex-row items-center mb-12 bg-bg-elevation-3 border-b border-border-primary px-4 min-w-full">
      <.h3 class="w-full md:w-auto md:mx-6 mt-2 text-text-primary">
        <span :if={@form_type == :creating}>Creating New Alert</span>
        <span :if={@form_type == :editing}>Editing Alert #{@alert_id}</span>
        <span :if={@form_type == :duplicating}>Duplicating Alert #{@alert_id}</span>
      </.h3>
      <div class="flex items-center">
        <div :for={{step, i} <- Enum.with_index(@steps)} class="flex items-center">
          <.caret_icon :if={i > 0} direction={:right} class="mx-2 text-text-secondary" />
          {step_buttons(assigns, step)}
        </div>
      </div>
    </div>
    """
  end

  def step_buttons(assigns, step) do
    disabled =
      disable_button(
        step.name,
        assigns.previous_steps -- [assigns.progress.name],
        assigns.change_type,
        assigns.form_type
      )

    clickable_class =
      cond do
        step.name !== assigns.progress.name && !disabled ->
          "text-text-link-outline hover:underline"

        step.name in assigns.previous_steps ->
          "text-text-primary"

        true ->
          "text-text-secondary"
      end

    selected_class =
      if assigns.progress.name == step.name, do: "text-base font-bold", else: "text-sm"

    assigns =
      assign(
        assigns,
        %{
          step: step,
          class: "#{clickable_class} #{selected_class}",
          disabled: disabled
        }
      )

    ~H"""
    <button
      disabled={@disabled}
      type="button"
      phx-click="move_progress"
      class={"#{@class}"}
      value={@step.name}
      id={@step.name}
    >
      {@step.label}
    </button>
    """
  end

  @spec disable_button(String.t(), [String.t()], boolean(), atom()) :: boolean()
  defp disable_button(name, previous_steps, change_type?, form_type)

  defp disable_button("details", [], true, form_type) when form_type !== :creating do
    false
  end

  defp disable_button(name, previous_steps, _, _) do
    name not in previous_steps
  end
end
