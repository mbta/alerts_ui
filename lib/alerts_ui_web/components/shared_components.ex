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

  @doc """
  Renders a toggle button.

  ##Examples
    <.button_toggle>Button Text</.button_toggle>
  """
  attr :rest, :global,
    include:
      ~w(phx-target phx-click phx-value-effect_name phx-value-route_type name id value disabled)

  attr :class, :string, default: "", doc: "additional classes to add"
  attr :hidden, :boolean, default: false, doc: "hides component if true"
  attr :active, :boolean, default: true, doc: "switches to active colors if true"
  slot :inner_block, required: true

  def button_toggle(assigns) do
    on = "
  bg-bg-toggle-active
  text-text-dark
  hover:bg-primary-hover
  active:bg-primary-active
  "
    off = "
  bg-bg-elevation-5
  text-text-primary-bg
  hover:bg-secondary-hover
  active:bg-secondary-active
  "

    ~H"""
    <button
      class={"
      font-medium
      mb-1
      text-base
      px-4
      py-3
      rounded-sm
      #{if @active, do: on, else: off}
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
  Renders a select input.

  ##Examples
    <.select />
  """
  attr :label, :string, default: nil

  attr :class, :string, default: "", doc: "additional classes to add"

  attr :field, FormField,
    required: true,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"

  attr :options, :list,
    required: true,
    doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"

  attr :multiple, :boolean, default: false, doc: "whether this input allows multiple selections"

  attr :rest, :global, include: ~w(disabled)

  def select(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(field: nil, id: field.id)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))
      |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
      |> assign_new(:value, fn -> field.value end)

    ~H"""
    <div phx-feedback-for={@name} class="mb-5">
      <.label for={@id}><%= @label %></.label>
      <select
        id={@id}
        name={@name}
        class={[
          "bg-bg-primary border border-border-primary pl-3 py-1.5
            rounded text-text-primary disabled:text-text-secondary
            disabled:bg-bg-elevation-3 focus:border-border-focus
            focus:drop-shadow-[0 .25rem .25rem rgba(13,110,253,0.25)] #{@class}",
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
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block font-medium leading-tight mb-2">
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
    <div phx-feedback-for={@name} class="mb-5">
      <.label for={@id}><%= @label %></.label>
      <input
        type="text"
        id={@id}
        name={@name}
        placeholder={@placeholder}
        value={@value}
        class={[
          "bg-bg-primary border border-border-primary pl-3 py-1.5
            rounded text-text-primary disabled:text-text-secondary
            disabled:bg-bg-elevation-3 focus:border-border-focus
            focus:drop-shadow-[0 .25rem .25rem rgba(13,110,253,0.25)] #{@class}",
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
          "bg-bg-primary border border-border-primary pl-3 py-1.5
            rounded text-text-primary disabled:text-text-secondary
            disabled:bg-bg-elevation-3 focus:border-border-focus
            focus:drop-shadow-input #{@class}",
          @errors != [] && "border-danger focus:border-danger"
        ]}
        {@rest}
      ><%= Form.normalize_value("textarea", @value) %></textarea>
      <.input_error :for={msg <- @errors}><%= msg %></.input_error>
    </div>
    """
  end
end
