defmodule AlertsUIWeb.FormComponents.AlertDetails do
  @moduledoc """
    Live Component for alert details section of form
  """
  use AlertsUIWeb, :live_component
  use AlertsUI.Schema
  import Ecto.Changeset
  alias AlertsUI.Models.{Cause, SeverityLevel}
  alias AlertsUIWeb.FormComponents.Helpers.ErrorFormatter

  @primary_key false
  embedded_schema do
    field :header_text, :string
    field :description_text, :string
    field :cause_detail, :string, default: ""
    field :url, :string
    field :image_url, :string
    field :image_alternative_text, :string
    field :severity, :integer, default: 4
  end

  @required_fields ~w[header_text]a
  @fields ~w[description_text cause_detail url image_url image_alternative_text severity]a ++
            @required_fields

  @impl true
  def mount(socket) do
    severity_options =
      SeverityLevel.severity_tuples()
      |> Enum.map(fn {desc, severity, _level} -> {desc, severity} end)

    changeset = changeset(%__MODULE__{}, %{})

    send_changeset(changeset)

    socket =
      assign(socket, %{
        form: to_form(changeset),
        image_size: nil,
        image_path: nil,
        severity_options: severity_options,
        cause_options: []
      })

    {:ok, socket}
  end

  @impl true
  def update(%{alert_data: alert_data} = assigns, socket) do
    cause_options =
      formatted_causes(
        Map.get(assigns, :route_type),
        Map.get(assigns, :combination)
      )

    changeset =
      %__MODULE__{}
      |> changeset(
        alert_data
        |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
        |> Map.merge(socket.assigns.form.params)
      )

    send_changeset(changeset)

    form = to_form(changeset)
    assigns = assigns |> Map.merge(%{form: form, cause_options: cause_options})
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def update(%{submitted: submitted}, socket) do
    socket =
      if submitted do
        changeset =
          %__MODULE__{}
          |> changeset(socket.assigns.form.params)
          |> validate_required(@required_fields)
          |> validate_image_fields(socket.assigns.image_size)

        errors =
          case changeset |> apply_action(:validate) do
            {:ok, _changeset} -> []
            {:error, changeset} -> ErrorFormatter.parse_field_errors(changeset)
          end

        form =
          changeset
          |> to_form()
          |> Map.put(:action, :validate)
          |> Map.put(:errors, errors)

        assign(socket, form: form)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"alert_details" => alert_details}, socket) do
    image_size = alert_details["image_url"] |> get_image_size()
    image_path = alert_details["image_url"] |> get_image_path()

    changeset =
      %__MODULE__{}
      |> changeset(alert_details)
      |> validate_image_fields(image_size)

    send_changeset(changeset)

    form =
      changeset
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     assign(socket, %{
       form: form,
       image_size: image_size,
       image_path: image_path
     })}
  end

  defp validate_image_fields(changeset, image_size) do
    changeset
    |> validate_change(:image_url, fn :image_url, _image_url ->
      if is_number(image_size),
        do: [],
        else: [image_url: "Enter a valid image URL"]
    end)
    |> then(fn changeset ->
      if Map.get(changeset.changes, :image_url) in [nil, ""] do
        changeset
      else
        validate_required(changeset, :image_alternative_text, message: "Enter alt text")
      end
    end)
  end

  def changeset(changeset, params \\ %{}) do
    changeset
    |> cast(params, @fields)
    |> validate_change(:url, fn :url, url ->
      if url_valid?(url),
        do: [],
        else: [url: "Enter a correctly formatted URL (e.g. http://www.example.com) "]
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-w-full flex flex-col mt-4" id="details_view">
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
        <div class="flex flex-row">
          <.select
            label="Cause"
            field={@form[:cause_detail]}
            options={@cause_options}
            class="max-w-[16rem] mr-8"
            id="cause_input"
          />
          <.select
            label="Severity"
            field={@form[:severity]}
            options={@severity_options}
            class="max-w-[16rem]"
            id="severity_input"
          />
        </div>
        <div class="flex flex-row">
          <div class="flex flex-col w-[50%]">
            <.textarea
              field={@form[:header_text]}
              label="Main message"
              phx-debounce={120}
              maxlength="255"
              id="header_input"
              class="w-[100%] min-h-[10rem] border-b-0 z-20"
              value={@form[:header_text].value}
            />
            <.textarea_counter character_limit={255} field={@form[:header_text]} />
          </div>
          <div class="flex flex-col justify-center ml-4">
            <.copy_button copy_id="#alert_details_header_text" title="Copy main message to Clipboard" />
          </div>
        </div>
        <div class="flex flex-row">
          <div class="flex flex-col w-[50%]">
            <.textarea
              field={@form[:description_text]}
              label="Supporting information"
              phx-debounce={120}
              id="description_input"
              class="w-[100%] min-h-[10rem] border-b-0 z-20"
              maxlength="3000"
              value={@form[:description_text].value}
            />
            <.textarea_counter character_limit={3000} field={@form[:description_text]} />
          </div>
          <div class="flex flex-col justify-center ml-4">
            <.copy_button
              copy_id="#alert_details_description_text"
              title="Copy supporting information to Clipboard"
            />
          </div>
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
              <p :if={@image_path}>{@image_path}</p>
              <p :if={@image_size}>{"#{@image_size} mB"}</p>
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

  defp send_changeset(changeset) do
    case apply_action(
           changeset |> validate_required(@required_fields),
           :validate
         ) do
      {:ok, changeset} ->
        send(self(), {:add_errors, [], __MODULE__})
        send(self(), {:section_completed, changeset})
        changeset

      {:error, changeset} ->
        send(self(), {:add_errors, ErrorFormatter.parse_field_errors(changeset), __MODULE__})
    end
  end

  defp formatted_causes(route_type, combination) do
    mode = if combination == :ACCESS, do: :ACCESS, else: route_type

    options_list =
      mode
      |> Cause.cause_map_by_mode()
      |> Map.keys()
      |> Enum.map(fn cause_detail ->
        display_name = cause_detail |> String.replace("_", " ") |> String.downcase()
        {display_name, cause_detail}
      end)

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
