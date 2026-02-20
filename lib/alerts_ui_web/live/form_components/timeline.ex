defmodule AlertsUIWeb.FormComponents.Timeline do
  @moduledoc """
    Timeline component for alert creation
  """
  use AlertsUIWeb, :live_component
  alias AlertsUIWeb.Step

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :previous_steps, previous_steps(assigns.progress, assigns.steps))

    ~H"""
    <div class="flex flex-wrap md:flex-nowrap flex-row items-center mb-12 bg-bg-elevation-3 border-b border-border-primary px-4 min-w-full">
      <.h3 :if={@form_type == :creating} class="w-full md:w-auto md:mx-6 mt-2 text-text-primary">
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
    clickable_class =
      if step.name in assigns.previous_steps,
        do: "text-text-primary  hover:underline",
        else: "text-text-secondary"

    selected_class =
      if assigns.progress.name == step.name, do: "text-base font-medium", else: "text-sm"

    assigns = assign(assigns, %{step: step, class: "#{clickable_class} #{selected_class}"})

    ~H"""
    <button
      disabled={disable_button(@step.name, @previous_steps, @form_type != :creating)}
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

  defp disable_button(name, previous_steps, editing) do
    name not in previous_steps or (editing and name === "route_type_and_effect")
  end

  @spec previous_steps(Step.t(), [Step.t()], [String.t()]) :: [String.t()]
  def previous_steps(current_step, steps, acc \\ [])

  def previous_steps(%Step{previous: nil} = current_step, _steps, acc),
    do: acc ++ [current_step.name]

  def previous_steps(current_step, steps, acc) do
    previous_steps(find_previous_step(current_step, steps), steps, acc ++ [current_step.name])
  end

  def find_previous_step(current_step, steps) do
    Enum.find(steps, &(&1.name == current_step.previous))
  end
end
