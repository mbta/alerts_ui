defmodule AlertsUIWeb.SharedComponents do
  @moduledoc """
  Provides UI components that are shared between MBTA projects.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component

  alias AlertsUIWeb.CoreComponents
  alias Phoenix.HTML.{Form, FormField}

  @doc """
  Renders a body tag.

  ## Examples

      <.body>
        This is the page body.
      </.body>

  """
  slot :inner_block, required: true

  def body(assigns) do
    ~H"""
    <body class="bg-bg-primary font-body font-normal text-base text-text-primary">
      <%= render_slot(@inner_block) %>
    </body>
    """
  end

  @doc """
  Renders a paragraph.

  ## Examples

      <.p>
        Lorem ipsum dolor sit amet
      </.p>

  """
  slot :inner_block, required: true

  def p(assigns) do
    ~H"""
    <p class="mb-4">
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  @doc """
  Renders an h1 header.

  ## Examples

      <.h1>H1 Header Text</.h1>

  """
  attr :class, :string, default: "", doc: "additional classes to add"
  attr :hidden, :boolean, default: false, doc: "hides component if true"
  slot :inner_block, required: true

  def h1(assigns) do
    ~H"""
    <h1 class={"font-medium mb-4 text-4xl #{if @hidden, do: "hidden", else: ""} #{@class}"}>
      <%= render_slot(@inner_block) %>
    </h1>
    """
  end

  @doc """
  Renders an h2 header.

  ## Examples

      <.h2>H2 Header Text</.h2>

  """
  attr :class, :string, default: "", doc: "additional classes to add"
  attr :hidden, :boolean, default: false, doc: "hides component if true"
  slot :inner_block, required: true

  def h2(assigns) do
    ~H"""
    <h2 class={"font-medium mb-4 text-3xl #{if @hidden, do: "hidden", else: ""} #{@class}"}>
      <%= render_slot(@inner_block) %>
    </h2>
    """
  end

  @doc """
  Renders an h3 header.

  ## Examples

      <.h3>H3 Header Text</.h3>

  """
  attr :class, :string, default: "", doc: "additional classes to add"
  attr :hidden, :boolean, default: false, doc: "hides component if true"
  slot :inner_block, required: true

  def h3(assigns) do
    ~H"""
    <h3 class={"font-bold mb-2 text-2xl #{if @hidden, do: "hidden", else: ""} #{@class}"}>
      <%= render_slot(@inner_block) %>
    </h3>
    """
  end

  @doc """
  Renders an h4 header.

  ## Examples

      <.h4>H4 Header Text</.h4>

  """
  attr :class, :string, default: "", doc: "additional classes to add"
  attr :hidden, :boolean, default: false, doc: "hides component if true"
  slot :inner_block, required: true

  def h4(assigns) do
    ~H"""
    <h4 class={"font-medium mb-2 text-xl #{if @hidden, do: "hidden", else: ""} #{@class}"}>
      <%= render_slot(@inner_block) %>
    </h4>
    """
  end

  @doc """
  Renders an h5 header.

  ## Examples

      <.h5>H5 Header Text</.h5>

  """
  attr :class, :string, default: "", doc: "additional classes to add"
  attr :hidden, :boolean, default: false, doc: "hides component if true"
  slot :inner_block, required: true

  def h5(assigns) do
    ~H"""
    <h5 class={"font-medium mb-1 text-lg #{if @hidden, do: "hidden", else: ""} #{@class}"}>
      <%= render_slot(@inner_block) %>
    </h5>
    """
  end

  @doc """
  Renders an h6 header.

  ## Examples

      <.h6>H6 Header Text</.h6>

  """
  attr :class, :string, default: "", doc: "additional classes to add"
  attr :hidden, :boolean, default: false, doc: "hides component if true"
  slot :inner_block, required: true

  def h6(assigns) do
    ~H"""
    <h6 class={"font-medium mb-1 text-base #{if @hidden, do: "hidden", else: ""} #{@class}"}>
      <%= render_slot(@inner_block) %>
    </h6>
    """
  end

  @doc """
  Renders a medium primary button.

  ##Examples
    <.button_primary>Button Text</.button_primary>
  """
  attr :rest, :global,
    include:
      ~w(phx-target phx-click phx-value-effect_name phx-value-route_type name id value disabled)

  attr :class, :string, default: "", doc: "additional classes to add"
  attr :hidden, :boolean, default: false, doc: "hides component if true"
  slot :inner_block, required: true

  def button_primary(assigns) do
    ~H"""
    <button
      class={"
      text-text-dark
      bg-primary
      border-primary
      border-1
      px-4
      py-3
      rounded-md
      hover:bg-primary-hover
      hover:border-primary-border-hover
      active:bg-primary-active
      active:border-primary-active
      focus:border-primary-active
      focus:border-4
      focus:px-3
      focus:py-2
      disabled:bg-primary-disabled
      disabled:border-primary-disabled
      #{if @hidden, do: "hidden", else: ""}
      #{@class}
    "}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders a medium secondary button.

  ##Examples
    <.button_secondary>Button Text</.button_secondary>
  """
  attr :rest, :global,
    include:
      ~w(phx-target phx-click phx-value-effect_name phx-value-route_type name id value disabled)

  attr :class, :string, default: "", doc: "additional classes to add"
  attr :hidden, :boolean, default: false, doc: "hides component if true"
  slot :inner_block, required: true

  def button_secondary(assigns) do
    ~H"""
    <button
      class={"
      text-text-white
      bg-secondary-border
      border-secondary-border
      border-1
      px-4
      py-3
      rounded-md
      hover:bg-secondary-hover
      active:bg-secondary-active
      active:border-secondary-active
      focus:border-secondary-focus-border
      focus:border-4
      focus:px-3
      focus:py-2
      disabled:bg-secondary-disabled
      disabled:border-secondary-disabled
      #{if @hidden, do: "hidden", else: ""}
      #{@class}
    "}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @spec toggle_button_classes() :: [
          {:base_toggle_classes, String.t()}
          | {:toggled_off, String.t()}
          | {:toggled_on, String.t()},
          ...
        ]
  def toggle_button_classes do
    [
      base_toggle_classes: "font-medium
        border-[1px]
        mb-1
        text-base
        px-4
        py-3
        rounded
        focus:drop-shadow-[0 .25rem .25rem rgba(13,110,253,0.25)]",
      toggled_on: "bg-menu-active
        text-text-invert
        hover:bg-primary-hover
        focus:bg-primary-hover
        active:bg-primary-active",
      toggled_off: "bg-bg-input-default
        text-text-primary
        border-bg-elevation-6
        hover:bg-secondary-hover
        focus:bg-secondary-hover
        active:bg-secondary-active"
    ]
  end

  @doc """
  Renders a toggle button.

  ##Examples
    <.button_toggle>Button Text</.button_toggle>
  """
  attr :rest, :global,
    include:
      ~w(type phx-target phx-click phx-value-effect_name phx-value-route_type name id value disabled)

  attr :class, :string, default: "", doc: "additional classes to add"
  attr :hidden, :boolean, default: false, doc: "hides component if true"
  attr :active, :boolean, default: true, doc: "switches to active colors if true"
  slot :inner_block, required: true

  def button_toggle(assigns) do
    assigns =
      assigns
      |> assign(toggle_button_classes())

    ~H"""
    <button
      class={"
      #{@base_toggle_classes}
      #{if @active, do: @toggled_on, else: @toggled_off}
      #{if @hidden, do: "hidden", else: ""}
      #{@class}
    "}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders a checkgroup.

  ##Examples
    <.checkgroup />
  """
  attr :field, FormField,
    required: true,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :name, :string, default: ""
  attr :options, :any
  attr :label, :string, default: nil
  attr :hidden, :boolean, default: false, doc: "hides component if true"
  attr :class, :string, default: "", doc: "additional classes to add"
  attr :rest, :global, include: ~w(disabled form readonly)

  def toggle_checkgroup(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(id: field.id, field_value: field.value)
      |> assign(toggle_button_classes())
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))

    ~H"""
    <div
      phx-feedback-for={@name}
      class={"text-sm items-baseline #{if @hidden, do: "hidden", else: ""}"}
    >
      <div :for={{route_name, id} <- @options} class="">
        <.label for={id}>
          <div class={"
            #{@base_toggle_classes}
              #{if (@field_value && id in @field_value), do: @toggled_on, else: @toggled_off}
              #{@class}"}>
            <input
              type="checkbox"
              id={id}
              name={@name}
              value={id}
              checked={@field_value && id in @field_value}
              class="hidden"
              {@rest}
            />
            <%= route_name %>
          </div>
        </.label>
      </div>
      <.input_error :for={msg <- @errors}><%= msg %></.input_error>
    </div>
    """
  end

  @doc """
  Renders a select input.

  ##Examples
    <.select
      label="Select"
      field={@form[:single_select]}
      options={single_select_options()}
      prompt="All"
    />
  """
  attr :label, :string, default: nil

  attr :select_class, :string,
    default: "",
    doc: "additional classes to add to the select component"

  attr :class, :string, default: "", doc: "classes to add to the containing div"

  attr :field, FormField,
    required: true,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"

  attr :options, :list,
    required: true,
    doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"

  attr :multiple, :boolean, default: false, doc: "whether this input allows multiple selections"

  attr :hidden, :boolean, default: false, doc: "hides component if true"

  attr :rest, :global, include: ~w(disabled)

  def select(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(field: nil, id: field.id)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))
      |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
      |> assign_new(:value, fn -> field.value end)

    ~H"""
    <div phx-feedback-for={@name} class={"#{@class} #{if @hidden, do: "hidden", else: ""}"}>
      <.label for={@id} class={if is_nil(@label), do: "hidden"}><%= @label %></.label>
      <select
        id={@id}
        name={@name}
        class={[
          "bg-bg-elevation-5 border border-border-primary pl-3 py-1.5 min-w-[99%] p-0
            rounded text-text-primary disabled:text-text-secondary
            disabled:bg-bg-elevation-3 ring-0 ring-border-focus focus:ring-0 focus:border-border-focus
            focus:drop-shadow-[0 .25rem .25rem rgba(13,110,253,0.25)] #{@select_class}",
          @errors != [] && "border-danger focus:border-danger"
        ]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="default"><%= @prompt %></option>
        <%= Form.options_for_select(@options, @value) %>
      </select>
      <.input_error :for={msg <- @errors}><%= msg %></.input_error>
    </div>
    """
  end

  @doc """
  Renders a multiselect input with an attached filter.
  Requires: select field, filter field, and a handle_event
  function that updates the filter_value attribute.
  See live/components_live.ex for a working example

  ##Examples
    <.multiselect
      label="Multiselect"
      field={@form[:multiselect]}
      filter_field={@form[:multiselect_filter]}
      filter_value={@filter_value}
      update_function="rerender"
      options={multiselect_options()}
  """
  attr :label, :string, default: nil

  attr :class, :string, default: "", doc: "additional classes to add"

  attr :field, FormField,
    required: true,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :filter_field, FormField,
    required: true,
    doc:
      "a form field struct for the filter retrieved from the form, for example: @form[:multiselect_filter]"

  attr :filter_value, :string,
    default: "",
    doc: "The value of the filter input (passed in from component to force re-render)"

  attr :filter_update_function, :string,
    required: true,
    doc: "the name of the function to call on change of the the filter_value attribute"

  attr :prompt, :string, default: nil, doc: "the prompt for multiselect inputs"

  attr :hidden, :boolean, default: false, doc: "hides component if true"

  attr :options, :list,
    required: true,
    doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"

  attr :rest, :global, include: ~w(disabled)

  def multiselect(%{field: %FormField{} = field, filter_value: filter_value} = assigns) do
    assigns =
      assigns
      |> assign(id: field.id)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))
      |> assign_new(:filter_value, fn -> String.downcase(filter_value) end)

    ~H"""
    <div {@rest} class={"#{@class} flex flex-col justify-start #{if @hidden, do: "hidden", else: ""}"}>
      <.label for={@id}><%= @label %></.label>
      <div
        class={[
          "min-h-full min-w-fit flex flex-col -space-y-2 rounded border
          bg-bg-elevation-5 disabled:bg-bg-elevation-3
          border-border-primary ring-0 ring-border-focus
          focus:ring-1 focus:border-border-focus
          focus-within:ring-1 focus-within:border-border-focus",
          @errors != [] && "border-danger focus:border-danger"
        ]}
        {@rest}
      >
        <.text_input
          class="min-w-full pb-5 mb-0 border-0 ring-0 focus:ring-0 focus:border-0 focus:outline-0 rounded-b-none"
          field={@filter_field}
          placeholder="⌕ Search..."
          phx-change={@filter_update_function}
          {@rest}
        />
        <hr class="w-5/6 self-center border-y-1 border-border-primary min-h-[1rem]" />
        <.select
          multiple={true}
          options={
            Enum.filter(@options, fn {option, _value} ->
              option = String.downcase(option || "")

              case @filter_value do
                "" -> true
                _ -> String.starts_with?(option, @filter_value)
              end
            end)
          }
          field={@field}
          prompt={@prompt}
          class="min-h-full m-0"
          select_class="min-w-full min-h-[87%] pt-0 mt-0 [scrollbar-width:none]
            border-0 focus:ring-0 focus:border-0 focus:outline-0 rounded-t-none"
          {@rest}
        />
      </div>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  attr :class, :string, default: "", doc: "additional classes to add"
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class={"block font-medium leading-tight mb-2 #{@class}"}>
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Renders an error block that works with inputs.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def input_error(assigns) do
    ~H"""
    <p for={@for} class="flex gap-2 mt-1 text-sm text-text-error">
      <CoreComponents.icon name="hero-exclamation-circle" class="flex-none h-4 mt-0.5 w-4" />
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  @doc """
  Renders a text input
    ##Examples
    <.text_input />
  """
  attr :label, :string, default: nil
  attr :class, :string, default: "", doc: "additional classes to add"

  attr :field, FormField,
    required: true,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :placeholder, :string, default: nil, doc: "placeholder text"
  attr :rest, :global, include: ~w(disabled phx-debounce)

  def text_input(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(field: nil, id: field.id)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))
      |> assign_new(:name, fn -> field.name end)
      |> assign_new(:value, fn -> field.value end)

    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id} class={if is_nil(@label), do: "hidden"}><%= @label %></.label>
      <input
        type="text"
        id={@id}
        name={@name}
        placeholder={@placeholder}
        value={@value}
        class={[
          "bg-bg-input-default border border-border-primary pl-3 py-1.5
            rounded text-text-primary disabled:text-text-secondary
            disabled:bg-bg-elevation-3 ring-0  focus:ring-0 ring-border-focus
            focus:border-border-focus
            #{@class}",
          @errors != [] && "border-danger focus:border-danger"
        ]}
        {@rest}
      />
      <.input_error :for={msg <- @errors}><%= msg %></.input_error>
    </div>
    """
  end

  @doc """
  Renders a textarea input
    ##Examples
    <.textarea />
  """
  attr :label, :string, default: nil
  attr :class, :string, default: "", doc: "additional classes to add"

  attr :field, FormField,
    required: true,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :placeholder, :string, default: nil, doc: "placeholder text"
  attr :rest, :global, include: ~w(disabled phx-debounce)

  def textarea(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(field: nil, id: field.id)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))
      |> assign_new(:name, fn -> field.name end)
      |> assign_new(:value, fn -> field.value end)

    ~H"""
    <div phx-feedback-for={@name} class="mb-5">
      <.label for={@id}><%= @label %></.label>
      <textarea
        id={@id}
        name={@name}
        placeholder={@placeholder}
        class={[
          "bg-bg-input-default border border-border-primary pl-3 py-1.5
            rounded text-text-primary disabled:text-text-secondary
            disabled:bg-bg-elevation-3 ring-0 ring-border-focus
            focus:ring-1 focus:border-border-focus #{@class}",
          @errors != [] && "border-danger focus:border-danger"
        ]}
        {@rest}
      ><%= Form.normalize_value("textarea", @value) %></textarea>
      <.input_error :for={msg <- @errors}><%= msg %></.input_error>
    </div>
    """
  end
end
