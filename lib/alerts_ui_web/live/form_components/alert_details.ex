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
    field :draft, :boolean
  end

  @fields ~w[header_text description_text draft]a
  @required_fields ~w[header_text description_text]a

  @impl true
  def mount(socket) do
    form = %__MODULE__{} |> changeset() |> to_form()
    socket = assign(socket, %{form: form})
    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data} = assigns, socket) do
    edit_alert_data =
      %{
        header_text: Map.get(alert_data, :header_text),
        description_text: Map.get(alert_data, :description_text)
      }

    changeset =
      %__MODULE__{}
      |> changeset(edit_alert_data)

    form = to_form(changeset)
    assigns = edit_alert_data |> Map.put(:form, form) |> Map.merge(assigns)
    {:ok, assign(socket, assigns)}
  end

  def handle_event("validate", %{"alert_details" => alert_details}, socket) do
    form =
      %__MODULE__{}
      |> changeset(alert_details)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, %{form: form, alert_details: alert_details})}
  end

  @impl true
  def handle_event("save_as_draft", _params, socket) do
    changes = Map.put(socket.assigns.form.source.changes, :draft, true)

    %__MODULE__{}
    |> draft_changeset(changes)
    |> apply_action(:insert)
    |> case do
      {:ok, changeset} ->
        send(self(), {:save_as_draft, changeset})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("save", _params, socket) do
    %__MODULE__{}
    |> changeset(socket.assigns.form.source.changes)
    |> apply_action(:insert)
    |> case do
      {:ok, changeset} ->
        send(self(), {:create_alert, changeset})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def draft_changeset(changeset, params) do
    cast(changeset, params, @fields)
  end

  def changeset(changeset, params \\ %{}) do
    changeset
    |> cast(params, @fields)
    |> validate_required(@required_fields, message: "is required")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class={unless @progress.name == "details", do: "hidden", else: "min-w-full flex flex-col"}
      id="details_view"
    >
      <.form
        for={@form}
        phx-target={@myself}
        phx-submit="save"
        phx-change="validate"
        class="form-control gap-4"
        id="details_form"
      >
        <.input
          field={@form[:header_text]}
          label="Header"
          type="textarea"
          phx-debounce={120}
          id="header_input"
          value={@header_text}
        />
        <.input
          field={@form[:description_text]}
          label="Description"
          type="textarea"
          phx-debounce={120}
          id="description_input"
          value={@description_text}
        />
        <.button class="btn btn-outline basis-8 self-center px-8" name="save">Publish</.button>
      </.form>
      <button
        phx-target={@myself}
        phx-click="save_as_draft"
        type="button"
        name="draft"
        id="details_draft"
        class="btn rounded-lg mt-8 basis-8 self-center px-8 min-w-[25%] font-extrabold"
      >
        Save as Draft
      </button>
    </div>
    """
  end
end
