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

  @fields ~w[header_text description_text draft cause_detail url image_url image_alternative_text]a

  @impl true
  def mount(socket) do
    form = %__MODULE__{} |> changeset() |> to_form()
    socket = assign(socket, %{form: form, image_size: nil, image_path: nil})
    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data} = assigns, socket) do
    changeset =
      %__MODULE__{}
      |> changeset(alert_data)

    form = to_form(changeset)
    assigns = assigns |> Map.put(:form, form)
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("validate", %{"alert_details" => alert_details}, socket) do
    changeset = changeset(%__MODULE__{}, alert_details)

    changeset
    |> apply_action(:insert)
    |> case do
      {:ok, changeset} ->
        send(self(), {:section_completed, changeset})
        changeset

      {:error, changeset} ->
        changeset
    end

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     assign(socket, %{
       form: form
     })}
  end

  def handle_event("validate_image_url", %{"alert_details" => alert_details}, socket) do
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

  def draft_changeset(changeset, params) do
    cast(changeset, params, @fields)
  end

  def changeset(changeset, params \\ %{}) do
    changeset
    |> cast(params, @fields)
    |> validate_change(:url, fn :url, url ->
      if url_valid?(url), do: [], else: [url: "Enter a valid URL"]
    end)
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
        <div id="image-preview-div">
          <.text_input
            field={@form[:image_url]}
            label="Image URL"
            phx-debounce={500}
            phx-target={@myself}
            phx-change="validate_image_url"
            id="image_url_input"
            class={["min-w-[50%]", if(@form[:image_url].value not in ["", nil], do: "border-b-0")]}
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
          label="Image alt text"
          phx-debounce={120}
          id="image_alt_text_input"
          class="w-[50%]"
          spellcheck="true"
        />
      </.form>
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
         {:ok,
          %{headers: %{"content-type" => content_type, "content-length" => [content_length]}}} <-
           Req.head(url),
         true <- content_type |> Enum.all?(&String.starts_with?(&1, "image/")),
         {integer, _} <- Integer.parse(content_length) do
      (integer / 1_000_000) |> Float.round(2)
    else
      _ -> nil
    end
  end

  defp get_image_path(nil), do: nil
  defp get_image_path(""), do: nil

  defp get_image_path(url) when is_binary(url),
    do: url |> Path.split() |> List.last() |> String.split("?") |> hd
end
