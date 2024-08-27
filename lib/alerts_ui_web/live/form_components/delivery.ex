defmodule AlertsUIWeb.FormComponents.Delivery do
  @moduledoc """
    Live Component for delivery section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset
  alias Phoenix.HTML.Form

  @primary_key false
  embedded_schema do
    field :draft, :boolean
    field :banner_text, :string
    field :banner_sync_toggle, :boolean, default: true
    field :view_banner, :boolean, default: false
    field :accept_banner, :boolean, default: false
  end

  @fields ~w[banner_text banner_sync_toggle view_banner accept_banner]a

  @impl true
  def mount(socket) do
    form = %__MODULE__{} |> changeset() |> to_form()
    socket = assign(socket, %{form: form})
    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data} = assigns, socket) do
    form_params = socket.assigns.form.params
    form = socket.assigns.form

    banner_text_map =
      if Form.normalize_value("checkbox", form[:banner_sync_toggle].value) and
           Form.normalize_value("checkbox", form[:view_banner].value) do
        %{"banner_text" => Map.get(alert_data, :header_text, "")}
      else
        %{}
      end

    form =
      %__MODULE__{}
      |> changeset(Map.merge(form_params, banner_text_map))
      |> to_form()

    assigns = assigns |> Map.put(:form, form)
    {:ok, assign(socket, assigns)}
  end

  def draft_changeset(changeset, params) do
    cast(changeset, params, @fields)
  end

  def changeset(changeset, params \\ %{}) do
    changeset
    |> cast(params, @fields)
  end

  @impl true
  def handle_event("validate", %{"delivery" => delivery}, socket) do
    validate(delivery, socket)
  end

  def handle_event("view_checkbox", %{"delivery" => delivery}, socket) do
    if Form.normalize_value("checkbox", delivery["view_banner"]) == false do
      delivery
      |> Map.put("banner_text", nil)
      |> Map.put("banner_sync_toggle", false)
    else
      Map.put(delivery, "banner_sync_toggle", true)
    end
    |> validate(socket)
  end

  def handle_event("banner_text_change", %{"delivery" => delivery}, socket) do
    # disables sync if user types in banner field
    Map.put(delivery, "banner_sync_toggle", false)
    |> validate(socket)
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

  def validate(delivery, socket) do
    delivery = Map.merge(socket.assigns.form.params, delivery)
    changeset = changeset(%__MODULE__{}, delivery)

    changeset
    |> apply_action(:insert)
    |> case do
      {:ok, changeset} ->
        send(self(), {:section_completed, changeset})

      {:error, changeset} ->
        changeset
    end

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, %{form: form})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class={unless @progress.name == "details", do: "hidden", else: "min-w-full flex flex-col mt-4"}
      id="delivery_view"
    >
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Delivery
      </.h5>
      <.form
        for={@form}
        phx-target={@myself}
        phx-submit="save"
        phx-change="validate"
        class="form-control gap-12"
        id="delivery_form"
      >
        <div id="banner_div" class="flex flex-col w-[50%]">
          <div class="flex flex-row mb-2">
            <.checkbox field={@form[:view_banner]} phx-change="view_checkbox" phx-target={@myself} />
            <span class="ml-4">Banner on all MBTA.com pages</span>
          </div>
          <div :if={Form.normalize_value("checkbox", @form[:view_banner].value)} class="flex flex-row">
            <div class="min-w-[100%]" id="banner-container">
              <.textarea
                field={@form[:banner_text]}
                label="Website banner text"
                phx-debounce={120}
                class="w-[100%] min-h-[10rem] border-b-0"
                maxlength="4000"
                phx-change="banner_text_change"
                phx-target={@myself}
                value={@form[:banner_text].value}
              />
              <.textarea_counter character_limit={4000} field={@form[:banner_text]} />
            </div>

            <div class="flex flex-col justify-center ml-4">
              <.checkbox
                field={@form[:banner_sync_toggle]}
                class="h-7 w-7 border border-border-primary rounded-sm"
                check_class="w-[100%] h-[100%] checked:before:content-[''] checked:before:hero-arrow-path leading-normal"
              />

              <button
                class="h-7 w-7 mt-4 border border-border-primary bg-bg-input-default active:bg-menu-active rounded-sm hover:bg-primary-hover"
                phx-click={JS.dispatch("phx:copy", to: "#delivery_banner_text")}
                title="Copy banner text to Clipboard"
                type="button"
              >
                <span class="hero-square-2-stack-solid w-5 h-5 stroke-3" />
              </button>
            </div>
          </div>
          <div
            :if={Form.normalize_value("checkbox", @form[:view_banner].value)}
            class="flex flex-row mt-4"
          >
            <.checkbox field={@form[:accept_banner]} />
            <span class={
              if @form[:accept_banner].errors |> length > 0, do: "-ml-[14rem]", else: "ml-4"
            }>
              I understand this will post a high priority alert banner on every page of MBTA.com.
            </span>
          </div>
        </div>
        <.button_primary class="basis-8 self-center min-w-[10%]" name="save">Publish</.button_primary>
      </.form>

      <.button_secondary
        phx-target={@myself}
        phx-click="save_as_draft"
        type="button"
        name="draft"
        id="details_draft"
        class="mt-8 basis-8 self-center min-w-[10%]"
      >
        Save as Draft
      </.button_secondary>
    </div>
    """
  end
end
