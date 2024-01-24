defmodule AlertsUIWeb.FormComponents.Timeline do
  @moduledoc """
    Timeline component for alert creation
  """
  use AlertsUIWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div :for={step <- @steps}>
        <%= step_buttons(assigns, step) %>
      </div>
    </div>
    """
  end

  def step_buttons(assigns, step) do
    button_class = if assigns.progress.name == step.name, do: "btn-primary", else: "btn-neutral"
    assigns = assign(assigns, %{step: step, button_class: button_class})

    ~H"""
    <button
      disabled={@step.name not in previous_steps(@progress.name, @steps)}
      type="button"
      phx-click="move_progress"
      class={"btn #{@button_class} rounded basis-8 self-center px-8 w-full"}
      value={@step.name}
    >
      <%= @step.label %> ↬
    </button>
    """
  end

  defp previous_steps("success", _steps), do: []

  defp previous_steps(name, steps) do
    current_index = Enum.find_index(steps, &(&1.name == name))

    steps
    |> Enum.with_index()
    |> Enum.filter(fn {_step, index} -> index <= current_index end)
    |> Enum.map(fn {step, _index} -> step.name end)
  end
end
