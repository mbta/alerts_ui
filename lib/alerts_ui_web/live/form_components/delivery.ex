defmodule AlertsUIWeb.FormComponents.Delivery do
  @moduledoc """
    Live Component for delivery section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset
  alias AlertsUIWeb.FormComponents.Helpers.ErrorFormatter
  alias Phoenix.HTML.Form

  @primary_key false
  embedded_schema do
    field :banner_text, :string
    field :banner_sync_toggle, :boolean, default: true
    field :view_banner, :boolean, default: false
    field :accept_banner, :boolean, default: false
    field :notification_toggle, :boolean, default: true
  end

  @fields ~w[banner_text banner_sync_toggle view_banner accept_banner notification_toggle]a

  @impl true
  def mount(socket) do
    form =
      %__MODULE__{}
      |> changeset(%{})
      |> to_form()

    socket = assign(socket, %{form: form})
    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data} = assigns, socket) do
    form = socket.assigns.form

    banner_text_map =
      if Form.normalize_value("checkbox", form[:banner_sync_toggle].value) and
           Form.normalize_value("checkbox", form[:view_banner].value) do
        %{"banner_text" => Map.get(alert_data, :header_text, "")}
      else
        %{}
      end

    data =
      alert_data
      |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
      |> Map.merge(form.params)
      |> Map.merge(banner_text_map)

    data =
      if Map.get(form.params, "banner_text") do
        Map.put(data, "view_banner", true)
      else
        data
      end

    changeset = changeset(%__MODULE__{}, data)

    changes = changeset |> apply_action!(:validate)

    send(self(), {:section_completed, changes})

    form =
      changeset
      |> to_form()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(form: form)}
  end

  @impl true
  def update(%{submitted: submitted}, socket) do
    socket =
      if submitted do
        form =
          %__MODULE__{}
          |> changeset(socket.assigns.form.params)
          |> validate_banner_acceptance(socket.assigns.form.params["view_banner"])
          |> Map.put(:action, :validate)
          |> to_form()

        assign(socket, form: form)
      else
        socket
      end

    {:ok, socket}
  end

  def changeset(changeset, params \\ %{}) do
    changeset
    |> cast(params, @fields)
  end

  @impl true
  def handle_event("validate", %{"delivery" => delivery}, socket) do
    validate(delivery, socket)
  end

  def handle_event("view_banner", %{"delivery" => delivery}, socket) do
    if Form.normalize_value("checkbox", delivery["view_banner"]) == false do
      delivery
      |> Map.put("banner_text", nil)
      |> Map.put("banner_sync_toggle", false)
    else
      delivery
      |> Map.put("banner_sync_toggle", true)
      |> Map.put("banner_text", socket.assigns.alert_data[:header_text])
    end
    |> validate(socket)
  end

  def handle_event("notification_toggle_change", %{"delivery" => delivery}, socket) do
    validate(delivery, socket)
  end

  def handle_event("banner_text_change", %{"delivery" => delivery}, socket) do
    # disables sync if user types in banner field
    delivery
    |> Map.put("banner_sync_toggle", false)
    |> validate(socket)
  end

  def validate(delivery, socket) do
    delivery = Map.merge(socket.assigns.form.params, delivery)

    changeset = changeset(%__MODULE__{}, delivery)

    case changeset
         |> validate_banner_acceptance(delivery["view_banner"])
         |> apply_action(:validate) do
      {:ok, changeset} ->
        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changeset})

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
        send(self(), {:section_completed, changeset})
    end

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, %{form: form})}
  end

  defp validate_banner_acceptance(changeset, "true"),
    do: validate_banner_acceptance(changeset, true)

  defp validate_banner_acceptance(changeset, true),
    do:
      validate_acceptance(changeset, :accept_banner, message: "Check box to show you understand")

  defp validate_banner_acceptance(changeset, "false"), do: changeset
  defp validate_banner_acceptance(changeset, false), do: changeset

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-w-full flex flex-col mt-8" id="delivery_view">
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Delivery
      </.h5>
      <.form
        for={@form}
        phx-target={@myself}
        phx-change="validate"
        class="form-control gap-4"
        id="delivery_form"
      >
        <div class="flex flex-row">
          <.form_checkbox
            field={@form[:notification_toggle]}
            phx-change="notification_toggle_change"
            phx-target={@myself}
            id="notification-toggle"
          />

          <span class="ml-4">
            Send notification to alert subscribers
          </span>
        </div>
        <div id="banner_div" class="flex flex-col">
          <div class="flex flex-row mb-2">
            <.form_checkbox field={@form[:view_banner]} phx-change="view_banner" phx-target={@myself} />
            <span class="ml-4">Banner on all MBTA.com pages</span>
          </div>
          <div
            :if={Form.normalize_value("checkbox", @form[:view_banner].value)}
            class="flex flex-col md:flex-row"
          >
            <div class="flex flex-col md:w-[50%]" id="banner-container">
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
              <.textarea_footer
                character_limit={4000}
                copy_id="#delivery_banner_text"
                copy_title="Copy banner text to Clipboard"
                field={@form[:banner_text]}
              />
            </div>
            <.form_checkbox
              class="mt-2 md:ml-4 md:mt-8"
              field={@form[:banner_sync_toggle]}
              label="Auto refresh"
            />
          </div>
          <div
            :if={Form.normalize_value("checkbox", @form[:view_banner].value)}
            class="flex flex-row mt-4"
          >
            <.form_checkbox field={@form[:accept_banner]} />
            <span class={
              if @form[:accept_banner].errors |> length > 0, do: "-ml-[14rem]", else: "ml-4"
            }>
              I understand this will post a high priority alert banner on every page of MBTA.com.
            </span>
          </div>
        </div>
      </.form>
      <hr class="mt-8" />
    </div>
    """
  end
end
