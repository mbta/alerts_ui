defmodule AlertsUIWeb.SharedComponents do
  @moduledoc """
  Provides UI components that are shared between MBTA projects.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component
  import AlertsUIWeb.IconComponents

  alias AlertsUIWeb.CoreComponents
  alias AlertsUIWeb.FormComponents.Helpers.ContentFormatter
  alias Phoenix.HTML.{Form, FormField}
  alias Phoenix.LiveView.JS

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
      px-1
      py-3
      rounded-md
      hover:bg-primary-hover
      hover:border-primary-border-hover
      active:bg-primary-active
      active:border-primary-active
      focus:border-primary-active
      focus:border-4
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
      text-primary
      border
      border-primary
      border-1
      px-1
      py-3
      rounded-md
      hover:bg-secondary-hover
      active:bg-secondary-active
      active:border-secondary-active
      focus:border-secondary-focus-border
      focus:border-4
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
  attr :icon, :string, default: nil, doc: "optional name of icon"
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
      <div class="flex flex-row justify-center align-center">
        <div class={"#{unless @icon, do: "hidden"} mr-3 self-center"}>
          <.mode_icon type={@icon} />
        </div>
        <%= render_slot(@inner_block) %>
      </div>
    </button>
    """
  end

  @doc """
  Renders a copy to clipboard.

  ##Examples
    <.copy_button copy_id="#input-id" title="copy input text"/>
  """
  attr :copy_id, :string, required: true, doc: "id of input component with text to be copied"
  attr :title, :string, default: "Copy text to clipboard", doc: "text to be displayed on hover"
  attr :rest, :global, include: ~w(phx-target phx-click name id value disabled)

  attr :class, :string, default: "", doc: "additional classes to add"
  attr :hidden, :boolean, default: false, doc: "hides component if true"

  def copy_button(assigns) do
    ~H"""
    <button
      class="h-7 w-7 mt-4 border border-border-primary bg-bg-input-default active:bg-menu-active rounded-sm hover:bg-primary-hover"
      phx-click={JS.dispatch("phx:copy", to: @copy_id)}
      title={@title}
      type="button"
    >
      <span class="hero-square-2-stack-solid w-5 h-5 stroke-3" />
    </button>
    """
  end

  @doc """
  Renders a checkgroup.

  ##Examples
    <.toggle_checkgroup
      field={@form[:route_ids]}
      options={[{"route_name", "route_id"}]}
      show_icons={true}
      icon_type={:FERRY}
      name="affected_service[route_ids][]"
     />
  """
  attr :field, FormField,
    required: true,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :options, :list, default: []

  attr :icon_type, :string,
    default: nil,
    doc: "icon to to display if all options should have the same icon."

  attr :show_icons, :boolean,
    default: false,
    doc: "whether to show icons. Icon will display option name unless icon_type is set."

  attr :label, :string, default: nil
  attr :class, :string, default: "", doc: "additional classes to add"
  attr :rest, :global, include: ~w(disabled form readonly)

  def toggle_checkgroup(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(id: field.id, field_value: normalize_strings_to_integers(field.value))
      |> assign_new(:name, fn -> field.name <> "[]" end)
      |> assign(toggle_button_classes())
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))

    ~H"""
    <div
      phx-feedback-for={@name}
      class={["grid grid-cols-1 gap-1 text-sm items-baseline content-start", @class]}
    >
      <.label for={@id} class={if is_nil(@label), do: "hidden"}><%= @label %></.label>
      <div :for={{option_name, id} <- @options} class="">
        <.label for={id}>
          <div class={[
            @base_toggle_classes,
            if(@field_value && id in @field_value, do: @toggled_on, else: @toggled_off)
          ]}>
            <input
              type="checkbox"
              id={id}
              name={@name}
              value={id}
              checked={@field_value && id in @field_value}
              class="hidden"
              {@rest}
            />
            <div class="flex flex-row justify-left align-center">
              <div class={[unless(@show_icons, do: "hidden"), "mr-3 self-center"]}>
                <.mode_icon type={if @icon_type, do: @icon_type, else: option_name} />
              </div>
              <%= if is_atom(option_name) do
                ContentFormatter.route_atom_to_string(option_name) |> :string.titlecase()
              else
                option_name
              end %>
            </div>
          </div>
        </.label>
      </div>
      <.input_error :for={msg <- @errors}><%= msg %></.input_error>
    </div>
    """
  end

  defp normalize_strings_to_integers(values) when is_list(values),
    do:
      Enum.map(values, fn value ->
        if is_integer(value), do: Integer.to_string(value), else: value
      end)

  defp normalize_strings_to_integers(value), do: value

  @doc """
  Renders a select input.

  ##Examples
    <.select
      label="Select"
      field={@form[:field_name]}
      options={[[display: :value]]}
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

  attr :rest, :global, include: ~w(disabled size phx-debounce)

  def select(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(field: nil, id: field.id)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))
      |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
      |> assign_new(:value, fn -> field.value end)

    ~H"""
    <div phx-feedback-for={@name} class={["#{@class}", @hidden && "hidden"]}>
      <.label for={@id} class={if is_nil(@label), do: "hidden"}><%= @label %></.label>
      <select
        id={@id}
        name={@name}
        class={[
          "bg-bg-elevation-5 border border-bg-elevation-6 pl-3 min-w-[99%] p-0 [color-scheme:light]
            rounded text-text-primary disabled:text-text-secondary [scrollbar-width:thin] overflow-auto
            disabled:bg-bg-elevation-3 ring-0 ring-border-focus focus:ring-0 focus:border-border-focus
            focus:drop-shadow-[0 .25rem .25rem rgba(13,110,253,0.25) h-10",
          @select_class,
          @errors != [] && "border-danger focus:border-danger"
        ]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="default" selected={@value in ["default", []]}>
          <%= @prompt %>
        </option>
        <%= Form.options_for_select(@options, @value) %>
      </select>
      <.input_error :for={msg <- @errors}><%= msg %></.input_error>
    </div>
    """
  end

  @doc """
  Renders a filtered_select input with an attached filter.
  Requires: select field, filter field. Expects the
  options to be pre-filtered with the filter field
  value before being passed in.
  See live/components_live.ex for a working example

  ##Examples
    <.filtered_select
      label="filtered_select"
      field={@form[:filtered_select_field]}
      filter_field={@form[:filtered_select_filter_field]}
      options={[[display: :value]]}
  """
  attr :label, :string, default: nil

  attr :class, :string, default: "", doc: "additional classes to add"

  attr :loading, :boolean, default: false, doc: "in loading state if true"

  attr :multiple, :boolean, default: true

  attr :field, FormField,
    required: true,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :filter_field, FormField,
    required: true,
    doc:
      "a form field struct for the filter retrieved from the form, for example: @form[:filtered_select_filter]"

  attr :prompt, :string, default: nil, doc: "the prompt for filtered_select inputs"

  attr :options, :list,
    required: true,
    doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"

  attr :rest, :global, include: ~w(disabled phx-debounce)

  def filtered_select(
        %{field: %FormField{} = field, filter_field: %FormField{} = filter_field} = assigns
      ) do
    assigns =
      assigns
      |> assign(id: field.id)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))
      |> assign_new(:filter_value, fn -> String.downcase(filter_field.value || "") end)

    ~H"""
    <div {@rest} class={["flex flex-col justify-start", @class]}>
      <.label for={@id}><%= @label %></.label>
      <div
        class={[
          "min-h-[100%] grow min-w-fit flex flex-col rounded border
          bg-bg-elevation-5 disabled:bg-bg-elevation-3
          border-bg-elevation-6 ring-0 ring-border-focus
          focus:ring-1 focus:border-border-focus
          focus-within:ring-1 focus-within:border-border-focus",
          @errors != [] && "border-danger focus:border-danger"
        ]}
        {@rest}
      >
        <.text_input
          class="min-w-full py-[.6rem] mb-0 border-0 ring-0 focus:ring-0 focus:border-0 focus:outline-0 rounded-b-none"
          field={@filter_field}
          placeholder="⌕ Search..."
          {@rest}
        />
        <hr class="w-5/6 self-center border-y-1 border-bg-elevation-6 min-h-[1rem]" />
        <div :if={@loading} class="-mt-4 ml-4 z-50">Loading ...</div>
        <.select
          multiple={@multiple}
          size="20"
          options={@options}
          field={@field}
          prompt={if @loading, do: nil, else: @prompt}
          class="min-h-[100%] h-[100%] m-0"
          select_class="min-w-full min-h-[87%] pt-0 mt-0 [scrollbar-width:thin] overflow-auto
            border-0 focus:ring-0 focus:border-0 focus:outline-0 rounded-t-none [appearance:none]"
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
    <label for={@for} class={["block font-medium leading-tight mb-2", @class]}>
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Renders an error block that works with inputs.
  """
  attr :for, :string, default: nil
  attr :class, :string, default: "", doc: "additional classes to add"
  slot :inner_block, required: true

  def input_error(assigns) do
    ~H"""
    <p for={@for} class={[@class, "flex gap-2 text-sm text-text-error"]}>
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
  attr :class, :any, default: "", doc: "additional classes to add"

  attr :field, FormField,
    required: true,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :rest, :global,
    include: ~w(disabled phx-debounce maxlength minlength placeholder spellcheck)

  def text_input(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(field: nil, id: field.id)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))
      |> assign_new(:name, fn -> field.name end)
      |> assign_new(:value, fn -> field.value end)

    ~H"""
    <div phx-feedback-for={@name}>
      <.label :if={not is_nil(@label)} for={@id}><%= @label %></.label>
      <input
        type="text"
        id={@id}
        name={@name}
        value={@value}
        class={[
          "bg-bg-input-default border border-bg-elevation-6 pl-2
            rounded text-text-primary disabled:text-text-secondary
            disabled:bg-bg-elevation-3 ring-0  focus:ring-0 ring-border-focus
            focus:border-border-focus",
          @class,
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

  attr :rest, :global,
    include: ~w(disabled phx-debounce maxlength minlength placeholder spellcheck phx-change)

  attr :value, :string, default: nil, doc: "you can override the value"

  def textarea(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(field: nil, id: field.id)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))
      |> assign_new(:name, fn -> field.name end)
      |> assign_new(:value, fn -> assigns.value || field.value end)

    ~H"""
    <div phx-feedback-for={@name} class="z-20">
      <.label for={@id}><%= @label %></.label>
      <textarea
        id={@id}
        name={@name}
        resize="none"
        value="true"
        class={[
          "bg-bg-input-default border border-bg-elevation-6 px-3 py-1.5
            rounded text-text-primary disabled:text-text-secondary
            disabled:bg-bg-elevation-3 ring-0 ring-border-focus
            focus:ring-1 focus:border-border-focus invalid:border-danger",
          @class,
          @errors != [] && "border-danger focus:border-danger"
        ]}
        {@rest}
      ><%=  @value%></textarea>
      <.input_error :for={msg <- @errors} class="-mt-[1.5rem] ml-1 relative"><%= msg %></.input_error>
    </div>
    """
  end

  @doc """
  Text area with counter.

  ## Examples

      <.textarea_counter field={@form[:fieldname]} />
  """

  attr :class, :string, default: "", doc: "additional classes to add"
  attr :character_limit, :integer, required: true

  attr :field, FormField,
    required: true,
    doc: "the form field the counter is associated with"

  attr :rest, :global, include: ~w(disabled)

  def textarea_counter(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign_new(:value, fn -> field.value end)
      |> assign(
        :error_length,
        Enum.map(field.errors, &CoreComponents.translate_error(&1)) |> length
      )

    ~H"""
    <div class={[
      "flex flex-row justify-end min-w-[100%] text-sm text-text-secondary bg-bg-elevation-3 px-2 pt-4 rounded-b border border-bg-elevation-6 border-t-0 -mt-2",
      if(@error_length > 0, do: "border-danger"),
      if(String.length(@value || "") == @character_limit, do: "text-danger ")
    ]}>
      <%= String.length(@value || "") %>/<%= @character_limit %><span
        :if={String.length(@value || "") == @character_limit}
        class="ml-1"
      > Character limit reached</span>
    </div>
    """
  end

  @doc """
  Renders a checkbox input.

  ## Examples

      <.checkbox field={@form[:fieldname]} />
  """
  attr :id, :any, default: nil
  attr :value, :any
  attr :hidden, :boolean, default: false
  attr :class, :string, default: "", doc: "additional classes to add to container div"
  attr :check_class, :string, default: "", doc: "additional classes to add directly to input"
  attr :label, :string, default: nil

  attr :field, FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"

  attr :rest, :global, include: ~w(phx-debounce disabled)

  def checkbox(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(id: assigns.id || field.id)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))
      |> assign(:name, field.name)
      |> assign_new(:checked, fn -> Form.normalize_value("checkbox", field.value) end)

    ~H"""
    <div>
      <.label :if={@label} for={@id}><%= @label %></.label>
      <div phx-feedback-for={@name} class={@class}>
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={[
            "[appearance:none] hover:bg-primary-hover w-4 h-4 checked:bg-primary checked:before:content-['']
            rounded-sm bg-bg-input-default checked:before:content-['✓'] font-bold leading-none",
            @check_class,
            if(length(@errors) > 0, do: "border border-1 border-danger focus:border-danger")
          ]}
          {@rest}
        />
        <.input_error :for={msg <- @errors}><%= msg %></.input_error>
      </div>
    </div>
    """
  end

  @doc """
  Renders a date/time input.

  You can use this as a date or a time input by passing those as the type.
  Default type is datetime-local
  ##Examples
    <.datetime
      label="Datetime selector"
      field={@form[:field_name]}
      min="2024-07-18T12:43"
      value="2024-07-18T12:43
      max="2024-07-19T12:43"
    />
  """
  attr :label, :string, default: nil

  attr :class, :string, default: "", doc: "classes to add to the containing div"

  attr :min, :string, default: ""

  attr :max, :string, default: ""

  attr :value, :string, default: nil

  attr :type, :string, default: "datetime-local"

  attr :field, FormField,
    required: true,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :hidden, :boolean, default: false, doc: "hides component if true"

  attr :rest, :global, include: ~w(disabled phx-debounce)

  def datetime(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(field: nil, id: field.id, name: field.name)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))
      |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)

    ~H"""
    <div phx-feedback-for={@name} class={["#{@class}", @hidden && "hidden"]}>
      <.label for={@id} class={if is_nil(@label), do: "hidden"}><%= @label %></.label>
      <input
        id={@id}
        name={@name}
        min={@min}
        max={@max}
        value={Form.normalize_value("datetime-local", @value)}
        step="1"
        class={[
          "bg-bg-elevation-5 border border-border-primary pl-3 py-1.5 min-w-[99%] p-0
            rounded text-text-primary disabled:text-text-secondary [scrollbar-width:thin] overflow-auto
            disabled:bg-bg-elevation-3 ring-0 ring-border-focus focus:ring-0 focus:border-border-focus
            focus:drop-shadow-[0 .25rem .25rem rgba(13,110,253,0.25)",
          @errors != [] && "border-danger focus:border-danger"
        ]}
        type={@type}
        {@rest}
      />

      <.input_error :for={msg <- @errors}><%= msg %></.input_error>
    </div>
    """
  end

  @doc """
  Renders form error flash notices.
  Takes in a title and a flash map with a semicolon-separated list of errors, eg:
  %{
  "error" => "Select direction; Enter message text; Select stop(s);  Select route(s)"
  }

  ## Examples
      <.form_error_flash title="Error Title" flash={@flash} />
  """
  attr :id, :string, default: "flash", doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  def form_error_flash(assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, :error)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: :error}) |> CoreComponents.hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <div class="hero-exclamation-circle-mini h-4 w-4" />
        <%= @title %>
      </p>
      <div :for={msg_line <- String.split(msg, ";")}>
        <li class="mt-2 ml-2 text-sm leading-5">
          <%= msg_line %>
        </li>
      </div>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label="close">
        <div class="hero-x-mark-solid h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end
end
