defmodule AlertsUIWeb.FormComponents.AlertDetails do
  @moduledoc """
    Live Component for alert details section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset
  alias AlertsUI.Models.Cause
  alias Phoenix.HTML.Form

  @primary_key false
  embedded_schema do
    field :header_text, :string
    field :description_text, :string
    field :draft, :boolean
    field :cause_detail, :string, default: ""
    field :banner_text, :string, default: ""
    field :url, :string
    field :image_url, :string
    field :image_alternative_text, :string
    field :banner_sync_toggle, :boolean, default: true
    field :view_banner, :boolean, default: false
    field :accept_banner, :boolean, default: false
  end

  @fields ~w[header_text description_text draft cause_detail url image_url image_alternative_text banner_text banner_sync_toggle view_banner accept_banner]a

  @impl true
  def mount(socket) do
    form = %__MODULE__{} |> changeset() |> to_form()
    socket = assign(socket, %{form: form})
    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data} = assigns, socket) do
    alert_data =
      %{
        "header_text" => Map.get(alert_data, :header_text),
        "description_text" => Map.get(alert_data, :description_text),
        "cause_detail" => Map.get(alert_data, :cause_detail),
        "banner_text" => Map.get(alert_data, :banner_text),
        "url" => Map.get(alert_data, :url),
        "image_url" => Map.get(alert_data, :image_url),
        "image_alternative_text" => Map.get(alert_data, :image_alternative_text)
      }

    changeset =
      %__MODULE__{}
      |> changeset(alert_data)

    form = to_form(changeset)
    assigns = assigns |> Map.put(:form, form) |> Map.put(:alert_details, alert_data)
    {:ok, assign(socket, assigns)}
  end

  def handle_event("validate", %{"alert_details" => alert_details}, socket) do
    validate(alert_details, socket)
  end

  def handle_event("banner_text_change", %{"alert_details" => new_alert_details}, socket) do
    # deselects banner update toggle when user types in banner text box
    Map.put(socket.assigns.alert_details, "banner_sync_toggle", "false")
    |> Map.merge(new_alert_details)
    |> validate(socket)
  end

  def handle_event("view_banner_toggle", %{"alert_details" => new_alert_details}, socket) do
    socket.assigns.alert_details
    |> Map.put("banner_text", "")
    |> Map.put("accept_banner", false)
    |> Map.merge(new_alert_details)
    |> validate(socket)
  end

  def handle_event("checkbox_change", %{"alert_details" => new_alert_details}, socket) do
    # empties banner text if user re-syncs it with header text
    if new_alert_details["banner_sync_toggle"] == true do
      Map.put(socket.assigns.alert_details, "banner_text", "")
    else
      socket.assigns.alert_details
    end
    |> Map.merge(new_alert_details)
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

  def validate(alert_details, socket) do
    changeset = changeset(%__MODULE__{}, alert_details) |> Map.put(:action, :validate)

    changeset =
      if !is_nil(Map.get(changeset.changes, :banner_text)) and
           Map.get(changeset.changes, :accept_banner, false) == false do
        add_error(changeset, :accept_banner, "Check box to show you understand")
      else
        changeset
      end

    form =
      changeset
      |> to_form()

    {:noreply, assign(socket, %{form: form, alert_details: alert_details})}
  end

  def draft_changeset(changeset, params) do
    cast(changeset, params, @fields)
  end

  def changeset(changeset, params \\ %{}) do
    changeset
    |> cast(params, @fields)
    |> validate_required(:header_text, message: "Enter alert text")
  end

  @impl true
  def render(assigns) do
    cause_options =
      formatted_causes(Map.get(assigns, :route_type), Map.get(assigns, :combination))

    assigns =
      assign(assigns,
        cause_options: cause_options
      )

    ~H"""
    <div
      class={unless @progress.name == "details", do: "hidden", else: "min-w-full flex flex-col mt-4"}
      id="details_view"
    >
      <.h5 class="text-text-secondary mb-8 w-full text-center md:text-left">
        Alert details
      </.h5>
      <.form
        for={@form}
        phx-target={@myself}
        phx-submit="save"
        phx-change="validate"
        class="form-control gap-12"
        id="details_form"
      >
        <.select
          label="Cause"
          field={@form[:cause_detail]}
          options={@cause_options}
          class="max-w-[16rem]"
          id="cause_input"
        />
        <div class="flex flex-col w-[50%]">
          <.textarea
            field={@form[:header_text]}
            label="Message"
            phx-debounce={120}
            maxlength="255"
            id="header_input"
            class="w-[100%] min-h-[10rem] border-b-0 z-20"
            value={@form[:header_text].value}
          />
          <.textarea_counter character_limit={255} field={@form[:header_text]} />
        </div>
        <div class="flex flex-col w-[50%]">
          <.textarea
            field={@form[:description_text]}
            label="Additional information"
            phx-debounce={120}
            id="description_input"
            class="w-[100%] min-h-[10rem] border-b-0 z-20"
            maxlength="255"
            value={@form[:description_text].value}
          />
          <.textarea_counter character_limit={255} field={@form[:description_text]} />
        </div>
        <.text_input
          field={@form[:url]}
          label="URL"
          phx-debounce={120}
          id="url_input"
          class="w-[50%]"
        />
        <.text_input
          field={@form[:image_url]}
          label="Image URL"
          phx-debounce={120}
          id="image_url_input"
          class="w-[50%]"
        />
        <.text_input
          field={@form[:image_alternative_text]}
          label="Image alt text"
          phx-debounce={120}
          id="image_alt_text_input"
          class="w-[50%]"
          spellcheck="true"
        />
        <.h5 class="text-text-secondary w-full text-center md:text-left">
          Delivery
        </.h5>
        <div id="banner_div" class="flex flex-col w-[50%]">
          <div class="flex flex-row mb-2">
            <.checkbox
              field={@form[:view_banner]}
              phx-change="view_banner_toggle"
              phx-target={@myself}
            />
            <span class="ml-4">Banner on all MBTA.com pages</span>
          </div>
          <div class={[
            "flex flex-row",
            unless(Form.normalize_value("checkbox", @form[:view_banner].value), do: "hidden")
          ]}>
            <div class="min-w-[100%]">
              <.textarea
                field={@form[:banner_text]}
                label="Website banner text"
                phx-debounce={120}
                class="w-[100%] min-h-[10rem] border-b-0"
                maxlength="4000"
                phx-change="banner_text_change"
                phx-target={@myself}
                value={
                  if Form.normalize_value("checkbox", @form[:banner_sync_toggle].value),
                    do: @form[:header_text].value,
                    else: @form[:banner_text].value
                }
              />
              <.textarea_counter character_limit={4000} field={@form[:banner_text]} />
            </div>

            <div class="flex flex-col justify-center ml-4">
              <.checkbox
                phx-change="checkbox_change"
                phx-target={@myself}
                field={@form[:banner_sync_toggle]}
                class="h-7 w-7 border border-border-primary rounded-sm"
                check_class="w-[100%] h-[100%] checked:before:content-[''] checked:before:hero-arrow-path leading-normal"
              />

              <button
                class="h-7 w-7 mt-4 border border-border-primary bg-bg-input-default active:bg-menu-active rounded-sm hover:bg-primary-hover"
                phx-click={JS.dispatch("phx:copy", to: "#alert_details_banner_text")}
                title="Copy banner text to Clipboard"
              >
                <span class="hero-square-2-stack-solid w-5 h-5 stroke-3" />
              </button>
            </div>
          </div>
          <div class={[
            "flex flex-row mt-4",
            unless(Form.normalize_value("checkbox", @form[:view_banner].value), do: "hidden")
          ]}>
            <.checkbox
              field={@form[:accept_banner]}
              phx-change="checkbox_change"
              phx-target={@myself}
            />
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

  defp formatted_causes(route_type, combination) do
    mode = if combination == :ACCESS, do: :ACCESS, else: route_type

    options_list =
      mode
      |> Cause.cause_map_by_mode()
      |> Map.keys()
      |> Enum.map(fn cause_detail -> {cause_detail, cause_detail} end)

    [{"<none>", ""} | options_list]
  end
end
