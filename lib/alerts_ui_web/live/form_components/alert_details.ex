defmodule AlertsUIWeb.FormComponents.AlertDetails do
  @moduledoc """
    Live Component for alert details section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset
  alias AlertsUI.Models.Cause

  @primary_key false
  embedded_schema do
    field :header_text, :string
    field :description_text, :string
    field :draft, :boolean
    field :cause_detail, :string, default: ""
    field :url, :string
    field :image_url, :string
    field :image_alternative_text, :string
  end

  @required_fields ~w[header_text description_text]a
  @fields @required_fields ++ ~w[draft cause_detail url image_url image_alternative_text]a

  @impl true
  def mount(socket) do
    form = %__MODULE__{} |> changeset() |> to_form()
    socket = assign(socket, %{form: form, image_size: nil, image_path: nil})
    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data} = assigns, socket) do
    edit_alert_data =
      %{
        header_text: Map.get(alert_data, :header_text),
        description_text: Map.get(alert_data, :description_text),
        cause_detail: Map.get(alert_data, :cause_detail),
        url: Map.get(alert_data, :url),
        image_url: Map.get(alert_data, :image_url),
        image_alternative_text: Map.get(alert_data, :image_alternative_text)
      }

    changeset =
      %__MODULE__{}
      |> changeset(edit_alert_data)

    form = to_form(changeset)
    assigns = edit_alert_data |> Map.put(:form, form) |> Map.merge(assigns)
    {:ok, assign(socket, assigns)}
  end

  def handle_event("validate", %{"alert_details" => alert_details}, socket) do
    image_size = alert_details["image_url"] |> get_image_size()
    image_path = alert_details["image_url"] |> get_image_path()

    changeset =
      %__MODULE__{}
      |> changeset(alert_details)
      |> validate_change(:image_url, fn :image_url, _image_url ->
        if is_number(image_size),
          do: [],
          else: [image_url: "Enter a valid image URL"]
      end)
      |> then(fn changeset ->
        if alert_details["image_url"] in [nil, ""] do
          changeset
        else
          validate_required(changeset, :image_alternative_text, message: "Enter alt text")
        end
      end)

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     assign(socket, %{
       form: form,
       alert_details: alert_details,
       image_size: image_size,
       image_path: image_path
     })}
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
        <.textarea
          field={@form[:header_text]}
          label="Header"
          phx-debounce={120}
          id="header_input"
          class="min-w-[50%]"
        />
        <.textarea
          field={@form[:description_text]}
          label="Description"
          phx-debounce={120}
          id="description_input"
          class="min-w-[50%]"
        />
        <.text_input
          field={@form[:url]}
          label="URL"
          phx-debounce={120}
          id="url_input"
          class="min-w-[50%]"
        />
        <div id="image-preview-div">
          <.text_input
            field={@form[:image_url]}
            label="Image URL"
            phx-debounce={500}
            id="image_url_input"
            class={"min-w-[50%] #{if(@form[:image_url].value not in ["", nil], do: "border-b-0")}"}
          />

          <div
            :if={@form[:image_url].value not in ["", nil]}
            id="image-information"
            class="flex flex-row w-[50%] text-sm text-text-secondary bg-bg-elevation-3 p-4 rounded-b border border-bg-elevation-6 border-t-0 -mt-4"
          >
            <img
              src={@form[:image_url].value}
              class={["max-h-[8rem] mt-4", if(@form[:image_url].value in ["", nil], do: "hidden")]}
            />
            <div class="flex flex-col justify-center ml-4">
              <p :if={@image_path}><%= @image_path %></p>
              <p :if={@image_size}><%= "#{@image_size} mB" %></p>
            </div>
          </div>
        </div>
        <.text_input
          field={@form[:image_alternative_text]}
          label="Image Alt Text"
          phx-debounce={120}
          id="image_alt_text_input"
          class="min-w-[50%]"
        />
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

  defp url_valid?(url) do
    uri = URI.parse(url)
    !is_nil(uri.scheme) && !is_nil(uri.host) && uri.host =~ "."
  end

  defp get_image_size(url) do
    with true <- url_valid?(url),
         {:ok, request} <- Req.get(url),
         false <- is_nil(request.body),
         true <-
           Req.Response.get_header(request, "content-type")
           |> Enum.all?(&Regex.match?(~r/image\//, &1)),
         true <- is_binary(request.body),
         true <- is_integer(byte_size(request.body)) do
      (byte_size(request.body) / 1_000_000) |> Float.round(2)
    else
      _ -> nil
    end
  end

  defp get_image_path(nil), do: nil
  defp get_image_path(""), do: nil

  defp get_image_path(url) when is_binary(url),
    do: url |> Path.split() |> List.last() |> String.split("?") |> hd
end
