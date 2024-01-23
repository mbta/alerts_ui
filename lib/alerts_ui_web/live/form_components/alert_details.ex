defmodule AlertsUIWeb.FormComponents.AlertDetails do
  @moduledoc """
    Live Component for alert details section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :header_text, :string
    field :description_text, :string
  end

  @fields ~w[header_text description_text]a

  @impl true
  def mount(socket) do
    changeset = %__MODULE__{} |> change() |> to_form()
    socket = socket |> assign(:details_changeset, changeset)
    {:ok, socket}
  end

  @impl true
  def handle_event("save", params, socket) do
    changeset(%__MODULE__{}, params)
    |> apply_action(:insert)
    |> case do
      {:ok, changeset} ->
        send(self(), {:details_created, changeset})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :details_changeset, changeset |> to_form())}
    end
  end

  def changeset(details_changeset, params) do
    details_changeset
    |> cast(params, @fields)
    |> validate_required([:header_text, :description_text])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={unless @hidden == false, do: "hidden"}>
      <.form
        for={@details_changeset}
        phx-target={@myself}
        phx-submit="save"
        phx-change="change"
        class="form-control gap-4"
        id="details_form"
      >
        <.input
          field={@details_changeset[:header_text]}
          name="header_text"
          value=""
          label="Header"
          type="textarea"
          phx-debounce={120}
          id="header_input"
        />
        <.input
          field={@details_changeset[:description_text]}
          name="description_text"
          value=""
          label="Description"
          type="textarea"
          phx-debounce={120}
          id="description_input"
        />
        <.button class="btn btn-outline basis-8 self-center px-8" name="save">submit</.button>
      </.form>
    </div>
    """
  end
end
