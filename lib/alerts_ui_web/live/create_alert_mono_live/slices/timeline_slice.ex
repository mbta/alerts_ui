defmodule AlertsUIWeb.CreateAlertMonoLive.Step do
  @moduledoc "Describe a step in the multi-step form and where it can go."

  @doc """
  Returns list of atoms allowed in alert lifecycle field of alert

  ## Examples
      iex> %AlertsUIWeb.Step{name: "example", previous: "cool", next: "bean", label: "hi"}
      %AlertsUIWeb.Step{name: "example", previous: "cool", next: "bean", label: "hi"}
  """
  defstruct [:name, :previous, :next, :label]

  @type t :: %__MODULE__{
          name: String.t(),
          previous: String.t() | nil,
          next: String.t() | nil,
          label: String.t()
        }
end

defmodule AlertsUIWeb.CreateAlertMonoLive.Slices.TimelineSlice do
  alias AlertsUIWeb.CreateAlertMonoLive.Step
  alias AlertsUIWeb.CreateAlertMonoLive.AlertData
  alias AlertsUIWeb.CreateAlertMonoLive.Slice

  use AlertsUIWeb, :html

  defstruct [
    :route_type,
    :effect_name
  ]

  defimpl Slice, for: __MODULE__ do
    @steps [
      %Step{
        name: "route_type_and_effect",
        previous: nil,
        next: "details",
        label: "Select Alert Type"
      },
      %Step{
        name: "details",
        previous: "route_type_and_effect",
        next: "preview",
        label: "Alert Details"
      },
      %Step{name: "preview", previous: nil, next: nil, label: "Preview and Submit"}
    ]

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
      progress =
        Map.get(
          socket.assigns,
          :progress,
          progress_on_mount(params, socket.assigns.live_action, @steps)
        )

      assign(socket,
        previous_steps: previous_steps(progress, @steps),
        progress: progress,
        steps: @steps,
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
    clickable_class =
      cond do
        step.name in (assigns.previous_steps -- [assigns.progress.name]) ->
          "text-text-primary hover:underline"

        step.name in assigns.previous_steps ->
          "text-text-primary"

        true ->
          "text-text-secondary"
      end

    selected_class =
      if assigns.progress.name == step.name, do: "text-base font-medium", else: "text-sm"

    assigns = assign(assigns, %{step: step, class: "#{clickable_class} #{selected_class}"})

    ~H"""
    <button
      disabled={
        disable_button(
          @step.name,
          @previous_steps -- [assigns.progress.name],
          @form_type != :creating
        )
      }
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
end
