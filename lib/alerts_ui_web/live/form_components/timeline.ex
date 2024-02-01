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
    <div class="flex flex-row justify-start min-w-full mb-20 bg-sky-200 py-2">
      <h1 class="mx-6 text-xl py-3 font-extrabold">Creating New Alert</h1>
      <div :for={step <- @steps} class="mx-6 self-center min-w-[12rem]">
        <%= step_buttons(assigns, step) %>
      </div>
    </div>
    """
  end

  def step_buttons(assigns, step) do
    button_class = if assigns.progress.name == step.name, do: "btn-primary", else: "btn-default"
    assigns = assign(assigns, %{step: step, button_class: button_class})

    ~H"""
    <button
      disabled={@step.name not in @previous_steps}
      type="button"
      phx-click="move_progress"
      class={"btn #{@button_class} rounded-full min-w-full font-extrabold"}
      value={@step.name}
    >
      <%= @step.label %> ►
    </button>
    """
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
