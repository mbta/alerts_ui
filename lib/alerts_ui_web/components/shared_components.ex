defmodule AlertsUIWeb.SharedComponents do
  @moduledoc """
  Provides UI components that are shared between MBTA projects.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component
  use Gettext, backend: AlertsUIWeb.Gettext
  import AlertsUIWeb.IconComponents

  alias AlertsUIWeb.CoreComponents
  alias AlertsUIWeb.Helpers.ContentFormatter
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
      {render_slot(@inner_block)}
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
      {render_slot(@inner_block)}
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
    <h1 class={"mb-4 font-bold text-lg lg:font-medium lg:text-4xl #{if @hidden, do: "hidden", else: ""} #{@class}"}>
      {render_slot(@inner_block)}
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
    <h2 class={"mb-4 font-bold lg:font-medium lg:text-3xl #{if @hidden, do: "hidden", else: ""} #{@class}"}>
      {render_slot(@inner_block)}
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
    <h3 class={"font-bold mb-2 lg:text-2xl #{if @hidden, do: "hidden", else: ""} #{@class}"}>
      {render_slot(@inner_block)}
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
    <h4 class={"font-medium mb-2 lg:text-xl #{if @hidden, do: "hidden", else: ""} #{@class}"}>
      {render_slot(@inner_block)}
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
    <h5 class={"mb-1 font-normal text-sm uppercase lg:text-base #{if @hidden, do: "hidden", else: ""} #{@class}"}>
      {render_slot(@inner_block)}
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
    <h6 class={"mb-1 font-normal italic text-base #{if @hidden, do: "hidden", else: ""} #{@class}"}>
      {render_slot(@inner_block)}
    </h6>
    """
  end

  def base_button_classes, do: "
    px-3
    py-1.5
    border
    rounded
    flex
    md:w-fit
    h-fit
    items-center
  "

  def primary_button_classes, do: "
    #{base_button_classes()}
      text-text-dark
      bg-primary
      border-primary
      hover:bg-primary-hover
      hover:border-primary-hover
      active:bg-primary-active
      active:border-primary-active
      focus:border-primary-active
      disabled:bg-primary-disabled
      disabled:border-primary-disabled
      disabled:text-text-primary-disabled
  "

  @doc """
  Renders a medium primary button.

  ##Examples
    <.button_primary>Button Text</.button_primary>
  """
  attr :rest, :global,
    include:
      ~w(phx-target phx-click phx-value-effect_name phx-value-route_type name id value disabled data-count type)

  attr :class, :string, default: "", doc: "additional classes to add"
  attr :hidden, :boolean, default: false, doc: "hides component if true"
  slot :inner_block, required: true

  def button_primary(assigns) do
    ~H"""
    <button
      class={"
      #{primary_button_classes()}
      #{if @hidden, do: "hidden", else: ""}
      #{@class}
    "}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders a link that looks like a medium primary button.

  ##Examples
    <.button_primary_link>Button Text</.button_primary_link>
  """
  attr :rest, :global,
    include:
      ~w(phx-target phx-click phx-value-effect_name phx-value-route_type name id value disabled target)

  attr :class, :string, default: "", doc: "additional classes to add"
  attr :href, :string, default: nil, doc: "additional link"
  slot :inner_block, required: true

  def button_primary_link(assigns) do
    ~H"""
    <.link href={@href} class={"
      #{primary_button_classes()}
      #{@class}
    "} {@rest}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  def secondary_button_classes, do: "
    #{base_button_classes()}
    text-primary
    border-primary
    bg-elevation-3
    hover:bg-bg-elevation-6
    hover:border-secondary-hover-border
    active:bg-secondary-active
    active:border-secondary-active
    active:text-text-invert
    focus:border-secondary-focus-border
    focus:shadow-secondary-focus-shadow
    disabled:text-secondary-disabled
    disabled:border-secondary-disabled
  "

  @doc """
  Renders a medium secondary button.

  ##Examples
    <.button_secondary>Button Text</.button_secondary>
  """
  attr :rest, :global,
    include:
      ~w(phx-target phx-click phx-value-effect_name phx-value-route_type name id value disabled type)

  attr :class, :string, default: "", doc: "additional classes to add"
  attr :hidden, :boolean, default: false, doc: "hides component if true"
  slot :inner_block, required: true

  def button_secondary(assigns) do
    ~H"""
    <button
      class={"
      #{secondary_button_classes()}
      #{if @hidden, do: "hidden", else: ""}
      #{@class}
    "}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders a link that looks like a medium secondary button.

  ##Examples
    <.button_secondary_link>Button Text</.button_secondary_link>
  """
  attr :rest, :global,
    include:
      ~w(phx-target phx-click phx-value-effect_name phx-value-route_type name id value disabled)

  attr :class, :string, default: "", doc: "additional classes to add"
  attr :href, :string, default: nil, doc: "additional link"
  slot :inner_block, required: true

  def button_secondary_link(assigns) do
    ~H"""
    <.link href={@href} class={"
      #{secondary_button_classes()}
      #{@class}
    "} {@rest}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders a medium danger button.

  ##Examples
    <.button_danger>Button Text</.button_danger>
  """
  attr :rest, :global,
    include:
      ~w(phx-target phx-click phx-value-effect_name phx-value-route_type name id value disabled type)

  attr :class, :string, default: "", doc: "additional classes to add"
  attr :hidden, :boolean, default: false, doc: "hides component if true"
  slot :inner_block, required: true

  def button_danger(assigns) do
    ~H"""
    <button
      class={"
      #{base_button_classes()}
      text-text-primary
      bg-danger
      border-danger
      hover:bg-danger-hover
      hover:border-danger-hover
      active:bg-danger-active
      active:border-danger-active
      focus:border-primary-active
      disabled:bg-danger-disabled
      disabled:border-danger-disabled
      disabled:text-text-danger-disabled
      #{if @hidden, do: "hidden", else: ""}
      #{@class}
    "}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @spec toggle_button_classes :: [
          {:base_toggle_classes, String.t()}
          | {:toggled_off, String.t()}
          | {:toggled_on, String.t()},
          ...
        ]
  def toggle_button_classes do
    [
      base_toggle_classes: "
        disabled:text-secondary-disabled
        disabled:border-secondary-disabled
        cursor-pointer" <> shared_base_toggle_classes(),
      toggled_off: "
        hover:bg-bg-elevation-4
        text-white
        border-toggle-active
        bg-bg-elevation-3",
      toggled_on: "
        hover:bg-primary-hover
        hover:border-primary-border-hover
        hover:text-text-invert
        bg-secondary-active
        border-secondary-active
        text-text-invert"
    ]
  end

  defp shared_base_toggle_classes do
    "font-medium
        border-[1px]
        mb-1
        text-base
        px-4
        py-3
        rounded
        focus:border-secondary-focus-border
        focus:shadow-secondary-focus-shadow"
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
  attr :use_outline_buttons, :boolean, default: false, doc: "whether to use outline button type"
  slot :inner_block, required: true

  def button_toggle(assigns) do
    assigns = assigns |> assign(toggle_button_classes())

    ~H"""
    <button
      class={"
      #{@base_toggle_classes}
      #{if @active, do: @toggled_on, else: @toggled_off}
      #{if @hidden, do: "hidden", else: ""}
      #{@class}
    "}
      aria-checked={@active}
      {@rest}
    >
      <div class="flex flex-row justify-center align-center">
        <div class={"#{unless @icon, do: "hidden"} mr-3 self-center"}>
          <.circle_icon type={@icon} />
        </div>
        {render_slot(@inner_block)}
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
      class="px-2 py-1 border border-border-primary bg-bg-input-default active:bg-secondary-active rounded hover:bg-secondary-hover"
      phx-click={JS.dispatch("phx:copy_input", to: @copy_id)}
      title={@title}
      type="button"
      aria-live="polite"
    >
      <span class="state-default">
        <span class="hero-square-2-stack-solid w-5 h-5 stroke-3" /> Copy text
      </span>
      <span class="state-copied hidden" aria-hidden="true">
        <span class="hero-clipboard-document-check-solid w-5 h-5 stroke-3" /> Copied
      </span>
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

  attr :column, :boolean, default: true, doc: "whether to arrange buttons in column (or row)"

  attr :options, :list, default: []

  attr :icon_type, :string,
    default: nil,
    doc: "icon to to display if all options should have the same icon."

  attr :show_icons, :boolean,
    default: false,
    doc: "whether to show icons. Icon will display option name unless icon_type is set."

  attr :use_outline_buttons, :boolean, default: false, doc: "whether to use outline button type"

  attr :label, :string, default: nil
  attr :class, :string, default: "", doc: "additional classes to add"
  attr :button_class, :string, default: "", doc: "classes to add to buttons"

  attr :prevent_empty, :boolean,
    default: false,
    doc:
      "when true, the only remaining checked option is rendered non-interactive so it can't be unchecked"

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
      class={["flex flex-col gap-1 text-sm items-baseline content-start", @class]}
    >
      <.label for={@id} class={"text-base #{if is_nil(@label), do: "hidden"}"}>{@label}</.label>

      <div class={["flex gap-2 w-full", if(@column, do: "flex-col", else: "flex-col md:flex-row")]}>
        <div
          :for={[key: option_name, value: id, id: dom_id] <- @options}
          class={[
            "flex-1",
            @button_class,
            "!m-0 !p-0",
            @base_toggle_classes,
            if(@field_value && id in @field_value, do: @toggled_on, else: @toggled_off)
          ]}
        >
          <.label
            for={dom_id}
            class={if @prevent_empty and @field_value == [id], do: "pointer-events-none"}
          >
            <div class="px-4 py-3">
              <input
                type="checkbox"
                id={dom_id}
                name={@name}
                value={id}
                checked={@field_value && id in @field_value}
                class="hidden"
                {@rest}
              />
              <div class={["lol flex flex-row justify-left align-center", @button_class]}>
                <div :if={@show_icons} class="mr-3 self-center">
                  <.circle_icon type={if @icon_type, do: @icon_type, else: option_name} />
                </div>
                {if is_atom(option_name) do
                  ContentFormatter.route_atom_to_string(option_name)
                else
                  option_name
                end}
              </div>
            </div>
          </.label>
        </div>
      </div>

      <.input_error :for={msg <- @errors}>{msg}</.input_error>
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
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :header_text, :string, default: ""
  attr :header_class, :string, default: ""
  attr :accept_button_text, :string, default: "Accept"
  attr :cancel_button_text, :string, default: "Cancel"
  attr :cancel_event_name, :string, default: nil
  attr :accept_event_name, :string, default: nil
  attr :accept_button_classes, :string, default: "", doc: "classes to add to accept button"
  attr :cancel_button_classes, :string, default: "", doc: "classes to add to cancel button"

  attr :button_type, :string,
    default: "button",
    doc: "The type of button, either 'button' or 'submit' (which submits the form)"

  attr :target_id, :string,
    default: "",
    doc: "The target to send the events to (eg form component id)"

  attr :class, :string, default: "", doc: "classes to add to the containing div"
  attr :outer_class, :string, default: "", doc: "classes to add to the outer containing div"
  attr :inner_class, :string, default: "", doc: "classes to add on the inner_block"
  attr :container_class, :string, default: "", doc: "classes to add on the container focus_wrap"

  attr :footer_warning_text, :string, default: nil, doc: "If present, adds warning text to footer"

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_accept, JS, default: %JS{}
  attr :on_cancel, JS, default: %JS{}

  attr :value, :string, default: "", doc: "data to pass to event handler on accept"

  attr :send_close_on_esc?, :boolean,
    default: true,
    doc:
      "if this is false the component should not send a close event on the user hitting escape. used to keep multiple modals from emitting an event."

  slot :header
  slot :inner_block, required: true
  slot :footer

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-accept={JS.exec(@on_accept, "phx-remove")}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      data-show={show_modal(@id)}
      class="fixed inset-0 z-50 hidden"
    >
      <div id={"#{@id}-bg"} class="bg-black/90 fixed inset-0 transition-opacity" aria-hidden="true" />
      <div
        class="absolute inset-0 flex place-content-center place-items-center"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class={["contents", @outer_class]}>
          <div class={["contents", @class]}>
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={
                if @send_close_on_esc? do
                  JS.push(@cancel_event_name, target: @target_id)
                  |> JS.exec("data-cancel", to: "##{@id}")
                end
              }
              phx-key="escape"
              phx-click-away={
                JS.push(@cancel_event_name, target: @target_id)
                |> JS.exec("data-cancel", to: "##{@id}")
              }
              class={[
                "max-h-dvh w-full md:max-h-[calc(100dvh-3rem)] md:w-auto md:max-w-2xl !flex flex-col justify-stretch content-stretch shadow-zinc-700/10 ring-zinc-700/10 hidden md:rounded-md bg-bg-elevation-4
              border-bg-elevation-6 shadow-lg ring-1 transition border",
                @container_class
              ]}
            >
              <div class="flex-none flex flex-row items-center justify-between py-3 pr-3 pl-4">
                <h1 class={["md:text-xl", @header_class]}>
                  {render_slot(@header) || @header_text}
                </h1>
                <button
                  phx-click={
                    JS.push(@cancel_event_name, target: @target_id)
                    |> JS.exec("data-cancel", to: "##{@id}")
                  }
                  type="button"
                  class="opacity-20 hover:opacity-40"
                  aria-label={gettext("close")}
                >
                  <AlertsUIWeb.CoreComponents.icon name="hero-x-mark-solid" class="h-8 w-8" />
                </button>
              </div>
              <div
                id={"#{@id}-content"}
                class={[
                  "p-4 w-full overflow-auto flex-1 border-y border-bg-elevation-6",
                  @inner_class
                ]}
              >
                {render_slot(@inner_block)}
              </div>
              <%= if render_slot(@footer) do %>
                {render_slot(@footer)}
              <% else %>
                <div class="flex-none flex flex-col md:flex-row md:justify-end px-3 py-3 gap-2">
                  <div
                    :if={@footer_warning_text}
                    class="mr-4 self-center text-warning order-last md:order-first"
                  >
                    {@footer_warning_text}
                  </div>
                  <.button_secondary
                    :if={@cancel_event_name}
                    type="button"
                    class={@cancel_button_classes}
                    phx-remove={hide_modal(@id)}
                    phx-click={
                      JS.push(@cancel_event_name, target: @target_id)
                      |> JS.exec("data-cancel", to: "##{@id}")
                      |> JS.exec("phx-remove")
                    }
                  >
                    {@cancel_button_text}
                  </.button_secondary>
                  <.button_primary
                    :if={@accept_event_name}
                    type={@button_type}
                    class={@accept_button_classes}
                    phx-remove={hide_modal(@id)}
                    phx-click={
                      JS.push(@accept_event_name, target: @target_id)
                      |> JS.exec("data-accept", to: "##{@id}")
                      |> JS.exec("phx-remove")
                    }
                    value={@value}
                  >
                    {@accept_button_text}
                  </.button_primary>
                </div>
              <% end %>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "##{id}-container",
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "##{id}-container",
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
    |> JS.hide(to: "##{id}", transition: {"flex", "flex", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  def demote_modal(js \\ %JS{}, id) do
    js
    |> JS.remove_class("z-50", to: "##{id}")
    |> JS.add_class("z-[49]", to: "##{id}")
  end

  @doc """
  Renders a button menu.

  ##Examples
    <.button_menu id="button-menu">
      <:toggle>
        <.button_secondary>
          <.icon name="hero-ellipsis-vertical" />
        </.button_secondary>
      </:toggle>
      <:menu>
        <.link>
          <.icon name="hero-square-2-stack-solid"/>
          <div>First button</div>
        </.link>
        <.link>
          <.icon name="hero-document-arrow-down-solid"/>
          <div>Second button</div>
        </.link>
      </:menu>
    </.button_menu>
  """
  attr :id, :string, required: true
  attr :container_id, :string, default: nil

  slot :toggle, required: true
  slot :menu, required: true

  def button_menu(assigns) do
    ~H"""
    <div phx-click={JS.show(to: {:inner, ".menu"})} class="relative">
      <div id={"#{@id}-toggle"}>
        {render_slot(@toggle)}
      </div>
      <div
        id={"#{@id}"}
        data-toggle-id={"#{@id}-toggle"}
        data-container-id={@container_id}
        phx-hook="DropdownPosition"
        class="
          menu
          p-0
          py-2
          hidden
          absolute
          top-[34px]
          right-0
          z-[100]
          bg-bg-input-default
          rounded
          text-white
          border
          border-border-primary

          before:content=[' ']
          before:absolute
          before:bottom-full
          before:right-[10px]
          before:border-8
          before:border-transparent
          before:border-b-border-primary

          after:content=[' ']
          after:absolute
          after:bottom-full
          after:right-[12px]
          after:border-[6px]
          after:border-transparent
          after:border-b-bg-input-default
        "
        phx-click-away={JS.hide()}
      >
        {render_slot(@menu)}
      </div>
    </div>
    """
  end

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

  attr :loading, :boolean, default: false, doc: "show loading state based on server variable"

  attr :loads_based_on, :list,
    default: [],
    doc:
      "IDs of elements whose phx-change-loading indicates this element should show its loading state"

  attr :modal_filter_id, :string,
    default: nil,
    doc: "id for modal filter associated with select. will not display if nil."

  attr :modal_filter_title, :string,
    default: nil,
    doc: "text that opens modal filter when clicked"

  attr :modal_filter_active, :boolean,
    default: false,
    doc: "whether a modal filter has been applied"

  attr :field, FormField,
    required: true,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"

  attr :options, :list,
    required: true,
    doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"

  attr :multiple, :boolean, default: false, doc: "whether this input allows multiple selections"

  attr :hidden, :boolean, default: false, doc: "hides component if true"

  attr :disabled, :boolean, default: false, doc: "whether the element is disabled"

  attr :warning, :boolean, default: false, doc: "if true, element gains a yellow border"

  attr :modal_filter_disabled, :boolean,
    default: false,
    doc: "whether the modal filter link element is disabled"

  attr :no_results, :boolean, default: false, doc: "true if result has been returned but is empty"

  attr :target_id, :string,
    default: "",
    doc: "The target to send the events to (eg form component id)"

  attr :selected, :list, default: nil

  attr :rest, :global, include: ~w(hook disabled size phx-debounce)

  def select(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(field: nil, id: field.id)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))
      |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
      |> assign_new(:value, fn ->
        assigns.selected || field.value || if assigns.multiple, do: [], else: nil
      end)
      |> assign(
        :client_loading_block_class,
        create_client_loading_class(assigns.loads_based_on, "block")
      )
      |> assign(
        :client_loading_hidden_class,
        create_client_loading_class(assigns.loads_based_on, "hidden")
      )

    ~H"""
    <div phx-feedback-for={@name} class={["#{@class}", "relative", @hidden && "hidden"]}>
      <%!-- In the event of slow connections, it is useful to have a loading state set by the client which
        is set immediately (phx-change-loading on the select that was changed) without having to wait for
        a server round trip. The server side loading state kicks in after the client loading state,
        so both can exist simultaneously. --%>
      <div
        :if={@loads_based_on !== []}
        class={["ml-4 absolute hidden", @client_loading_block_class]}
      >
        <.loading loading={true}></.loading>
      </div>
      <div :if={!@disabled} class="ml-4 absolute">
        <.loading loading={@loading}></.loading>
      </div>
      <div :if={@modal_filter_id || @label} class="flex flex-row justify-between">
        <.label for={@id} class={"block #{if @disabled, do: "text-text-disabled", else: ""}"}>
          {@label}
        </.label>
        <button
          :if={@modal_filter_id}
          phx-click={show_modal(@modal_filter_id)}
          class={[
            "leading-tight mb-2 min-h-[1.3rem] text-right",
            if(@modal_filter_disabled, do: "text-text-disabled", else: "text-primary")
          ]}
          type="button"
          id={@modal_filter_id <> "_button"}
          disabled={@modal_filter_disabled}
        >
          <span class={[
            "hero-funnel-mini w-4 h-4 mr-1",
            if(@modal_filter_disabled, do: "text-text-disabled", else: "bg-primary")
          ]} />
          {@modal_filter_title}
          <span
            :if={@modal_filter_active}
            id="clear-button"
            phx-target={@target_id}
            phx-click="clear_filter"
            phx-value-filter-id={@modal_filter_id}
            class="hero-x-circle-mini w-4 h-4 ml-1 bg-primary"
          />
        </button>
      </div>
      <select
        name={@name}
        id={@id}
        disabled={@disabled}
        class={[
          "bg-bg-elevation-5 border border-bg-elevation-6 px-3 mb-2 max-w-full min-w-full p-0 [color-scheme:light]
            rounded text-text-primary disabled:text-text-select-disabled [scrollbar-width:thin] overflow-auto
            disabled:bg-bg-elevation-3 ring-0 ring-border-focus focus:ring-0 focus:border-border-focus
            focus:drop-shadow-[0 .25rem .25rem rgba(13,110,253,0.25) h-10 [&_*]:pb-[.40rem] [&_*]:whitespace-pre-wrap [&_*]:truncate block",
          @select_class,
          @errors != [] && "border-danger focus:border-danger",
          @warning && "border-warning focus:border-warning",
          @client_loading_hidden_class
        ]}
        multiple={@multiple}
        phx-hook="Selector"
        {@rest}
      >
        <option
          :if={@prompt}
          value="default"
          selected={
            cond do
              @loading ->
                false

              # possible 'empty' states for 'value'
              @value not in [nil, "", [], ["default"]] ->
                false

              true ->
                true
            end
          }
          disabled={if @loading, do: true, else: false}
        >
          {@prompt}
        </option>
        <option :if={@no_results && !@loading} value="" selected={false} disabled={true}>
          No results
        </option>
        {Form.options_for_select(@options, @value)}
      </select>

      <.input_error :for={msg <- @errors} class="mt-2">{msg}</.input_error>
    </div>
    """
  end

  defp create_client_loading_class(id_list, class) do
    # This is unfortunately a necessary comment as tailwind needs static strings to
    # determine which CSS classes to respect. Tailwind scans all files as plaintext,
    # so including the necessary class in a comment makes sure to include it in the
    # generated CSS. I tried writing functions which return these strings but that didn't
    # work because of escaping underscore shenanigans, and also didn't really feel like
    # a better solution.
    #   group-has-[select[id=alert\_data\_route\_ids].phx-change-loading]:block
    #   group-has-[select[id=alert\_data\_route\_ids].phx-change-loading]:hidden
    #   group-has-[select[id=alert\_data\_single\_route\_id].phx-change-loading]:block
    #   group-has-[select[id=alert\_data\_single\_route\_id].phx-change-loading]:hidden
    #   group-has-[select[id=alert\_data\_direction].phx-change-loading]:block
    #   group-has-[select[id=alert\_data\_direction].phx-change-loading]:hidden
    #   group-has-[select[id=alert\_data\_trip\_ids].phx-change-loading]:block
    #   group-has-[select[id=alert\_data\_trip\_ids].phx-change-loading]:hidden

    id_list
    |> Enum.map_join(" ", fn id ->
      escaped_id = String.replace(id, "_", "\\_")
      "group-has-[select[id=#{escaped_id}].phx-change-loading]:#{class}"
    end)
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

  attr :loading, :boolean, default: false, doc: "show loading state based on server variable"

  attr :loads_based_on, :list,
    default: [],
    doc:
      "IDs of elements whose phx-change-loading indicates this element should show its loading state"

  attr :first_async_load, :boolean, default: false, doc: "is the initial loading state"

  attr :multiple, :boolean, default: true

  attr :field, FormField,
    required: true,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :filter_field, FormField,
    required: true,
    doc:
      "a form field struct for the filter retrieved from the form, for example: @form[:filtered_select_filter]"

  attr :modal_filter_id, :string,
    default: nil,
    doc: "id for modal filter associated with select. will not display if nil."

  attr :modal_filter_title, :string,
    default: "filter",
    doc: "text that opens modal filter when clicked"

  attr :modal_filter_active, :boolean,
    default: false,
    doc: "whether a modal filter has been applied"

  attr :prompt, :string, default: nil, doc: "the prompt for filtered_select inputs"

  attr :options, :list,
    required: true,
    doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"

  attr :no_results, :boolean, default: false, doc: "true if result has been returned but is empty"

  attr :disabled, :boolean, default: false, doc: "whether the element is disabled"

  attr :target_id, :string,
    default: "",
    doc: "The target to send the events to (eg form component id)"

  attr :selected, :list,
    default: nil,
    doc: "a separate list of selected items that overrides the field's value"

  attr :rest, :global, include: ~w(disabled phx-debounce hook)

  def filtered_select(
        %{field: %FormField{} = field, filter_field: %FormField{} = filter_field} = assigns
      ) do
    assigns =
      assigns
      |> assign(id: field.id)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))
      |> assign_new(:filter_value, fn -> String.downcase(filter_field.value || "") end)

    ~H"""
    <div {@rest} class={["flex flex-col justify-start", @class]} id={"#{@field.id}_selector"}>
      <div :if={@modal_filter_id || @label} class="flex flex-row justify-between">
        <.label for={@id} class={if @disabled, do: "text-text-disabled"}>
          {@label}
        </.label>
        <button
          :if={@modal_filter_id}
          phx-click={show_modal(@modal_filter_id)}
          class={[
            "flex shrink min-w-0 items-center leading-tight ml-2 mb-2 min-h-[1.3rem] text-right",
            if(@disabled || @first_async_load, do: "text-text-disabled", else: "text-primary")
          ]}
          type="button"
          disabled={@disabled || @first_async_load}
        >
          <span class={[
            "shrink-0 hero-funnel-mini w-4 h-4 mr-1",
            if(@disabled || @first_async_load, do: "text-text-disabled", else: "bg-primary")
          ]} />
          <span class="truncate">{@modal_filter_title}</span>
          <span
            :if={@modal_filter_active}
            id="clear-button"
            phx-target={@target_id}
            phx-click="clear_filter"
            phx-value-filter-id={@modal_filter_id}
            class="shrink-0 hero-x-circle-mini w-4 h-4 ml-1 bg-primary"
          />
        </button>
      </div>
      <div
        class={[
          "flex flex-col rounded border grow w-[100%]
          border-bg-elevation-6 ring-0 ring-border-focus
          focus:ring-1 focus:border-border-focus
          focus-within:ring-1 focus-within:border-border-focus",
          @errors != [] && "border-danger focus:border-danger",
          if(@disabled, do: "bg-bg-elevation-3", else: "bg-bg-elevation-5")
        ]}
        {@rest}
      >
        <.text_input
          class="grow py-[.6rem] mb-0 border-0 ring-0 focus:ring-0 focus:border-0 focus:outline-0 rounded-b-none"
          icon="hero-magnifying-glass-mini"
          field={@filter_field}
          placeholder={if @disabled || @first_async_load, do: nil, else: "Search..."}
          disabled={@disabled || @first_async_load}
          phx-debounce="250"
          action_icon="hero-x-circle-solid"
          action_event="reset_search_filter"
          action_name="Clear"
          target_id={@target_id}
          {@rest}
        />
        <hr class="w-5/6 self-center border-y-1 border-bg-elevation-6 min-h-[1rem]" />
        <.select
          multiple={@multiple}
          size="2"
          options={if @loading && is_nil(@options), do: [], else: @options}
          field={@field}
          no_results={@no_results}
          prompt={
            cond do
              @disabled -> nil
              @loading -> nil
              @filter_field.value in [nil, ""] -> @prompt
              true -> nil
            end
          }
          disabled={@disabled}
          loading={@loading}
          loads_based_on={@loads_based_on}
          class="m-0 h-full"
          select_class="min-w-full pt-0 mt-0 [scrollbar-width:thin] overflow-auto
            border-0 focus:ring-0 focus:border-0 focus:outline-0 rounded-t-none [appearance:none] max-w-[100%] h-full"
          selected={@selected}
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
    <label for={@for} class={["leading-tight mb-2 min-h-[1.3rem]", @class]}>
      {render_slot(@inner_block)}
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
      {render_slot(@inner_block)}
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
  attr :icon, :string, default: nil, doc: "name of an optional icon to display"

  attr :field, FormField,
    required: true,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :disabled, :boolean, default: false, doc: "whether the element is disabled"

  attr :action_icon, :string, default: nil, doc: "hero icon button"
  attr :action_event, :string, default: nil, doc: "event triggered by action button"

  attr :action_name, :string,
    default: nil,
    doc: "name of action triggered by action button (for screen readers)"

  attr :target_id, :string,
    default: "",
    doc: "The target to send the events to (eg form component id)"

  attr :rest, :global,
    include: ~w(value phx-debounce maxlength minlength placeholder spellcheck phx-change)

  def text_input(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(field: nil, id: field.id)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))
      |> assign_new(:name, fn -> field.name end)
      |> assign_new(:value, fn -> field.value end)

    ~H"""
    <div phx-feedback-for={@name} class="relative flex flex-col">
      <.label :if={not is_nil(@label)} for={@id}>{@label}</.label>
      <div class="flex flex-row items-center">
        <AlertsUIWeb.CoreComponents.icon
          :if={@icon && !@disabled}
          name={@icon}
          class="w-4 h-4 text-text-disabled absolute inset-y-2.5 inset-x-4"
        />
        <input
          type="text"
          id={@id}
          name={@name}
          value={@value}
          class={[
            "bg-bg-input-default border border-bg-elevation-6 pl-1
              rounded text-text-primary disabled:text-text-secondary
              disabled:bg-bg-elevation-3 ring-0 min-w-full focus:ring-0 ring-border-focus
              focus:border-border-focus",
            @icon && "ps-10",
            @action_icon && @action_event && "pe-[3rem] w-full",
            @class,
            @errors != [] && "border-danger focus:border-danger"
          ]}
          disabled={@disabled}
          {@rest}
        />
        <button
          :if={@action_event != nil && @action_icon != nil}
          class={"h-[38px] relative right-[3rem] flex flex-row items-center justify-center align-center rounded-xl text-primary hover:text-primary-hover active:text-primary-active cursor-pointer z-1 #{if @value in ["", nil], do: "invisible"}"}
          phx-click={@action_event}
          phx-value-name={@name}
          phx-target={@target_id}
          type="button"
        >
          <AlertsUIWeb.CoreComponents.icon name={@action_icon} class="p-2 z-1 w-[3rem]" />
          <span class="sr-only">{@action_name}</span>
        </button>
      </div>
      <.input_error :for={msg <- @errors}>{msg}</.input_error>
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
      <.label for={@id}>{@label}</.label>
      <textarea
        id={@id}
        name={@name}
        resize="none"
        value={@value}
        class={[
          "bg-bg-input-default border border-bg-elevation-6 px-3 py-1.5
            rounded text-text-primary disabled:text-text-secondary
            disabled:bg-bg-elevation-3 ring-0 ring-border-focus
            focus:ring-1 focus:border-border-focus invalid:border-danger",
          @class,
          @errors != [] && "border-danger focus:border-danger"
        ]}
        {@rest}
      ><%= @value %></textarea>
    </div>
    """
  end

  @doc """
  Text area with counter.

  ## Examples

      <.textarea_footer field={@form[:fieldname]} />
  """

  attr :class, :string, default: "", doc: "additional classes to add"
  attr :character_limit, :integer, required: true

  attr :copy_id, :string,
    default: nil,
    doc: "id of input component for copying, to be passed to copy button"

  attr :copy_title, :string, doc: "text to be passed to copy button"

  attr :field, FormField,
    required: true,
    doc: "the form field the counter is associated with"

  def textarea_footer(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign_new(:value, fn -> field.value end)
      |> assign(:at_limit, String.length(field.value || "") >= assigns.character_limit)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))

    ~H"""
    <div class={[
      "flex flex-row items-center min-w-full text-sm bg-bg-elevation-3 px-3 py-2 rounded-b border border-bg-elevation-6 border-t-0 -mt-2",
      if(@errors != [], do: "border-danger")
    ]}>
      <.copy_button :if={@copy_id} title={@copy_title} copy_id={@copy_id} />
      <div class={["text-text-secondary ml-auto", if(@at_limit, do: "!text-error")]}>
        {String.length(@value || "")}/{@character_limit}
        <span :if={@at_limit} class="ml-1">
          Character limit reached
        </span>
      </div>
    </div>
    <.input_error :for={msg <- @errors} class="ml-1 relative">{msg}</.input_error>
    """
  end

  @doc """
  Renders a checkbox input for a form field.

  ## Examples

      <.form_checkbox field={@form[:fieldname]} />
  """
  attr :id, :any, default: nil
  attr :class, :string, default: "", doc: "additional classes to add to container div"
  attr :check_class, :string, default: "", doc: "additional classes to add directly to input"
  attr :label, :string, default: nil

  attr :field, FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :rest, :global, include: ~w(phx-debounce disabled)

  def form_checkbox(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(id: assigns.id || field.id)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))
      |> assign(:name, field.name)
      |> assign_new(:checked, fn -> Form.normalize_value("checkbox", field.value) end)

    ~H"""
    <div>
      <div phx-feedback-for={@name} class={@class}>
        <input type="hidden" name={@name} value="false" />
        <.checkbox
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={@check_class}
          errors={@errors}
          {@rest}
        />
        <.label :if={@label} for={@id}>{@label}</.label>
        <.input_error :for={msg <- @errors}>{msg}</.input_error>
      </div>
    </div>
    """
  end

  @doc """
  Renders a checkbox input.

  ## Examples

    <.checkbox id="my_checkbox" value="true" />
  """
  attr :id, :any, default: nil
  attr :value, :any
  attr :name, :string, default: ""
  attr :class, :string, default: "", doc: "additional classes to add to container div"
  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"

  attr :rest, :global, include: ~w(phx-debounce disabled phx-click)

  def checkbox(assigns) do
    ~H"""
    <input
      type="checkbox"
      id={@id}
      name={@name}
      value={@value}
      checked={@checked}
      class={[
        "[appearance:none] bg-bg-input-default checked:bg-primary hover:bg-bg-elevation-6 hover:checked:bg-primary-hover
            rounded font-bold leading-none text-text-dark  w-4 h-4 before:content-['✓']
            border border-primary border-rounded hover:checked:border-primary-hover
            outline-text-primary outline-offset-2 focus:outline focus:outline-1
            [&:not(:checked)]:text-transparent
            ",
        @class,
        if(length(@errors) > 0, do: "border border-1 border-danger focus:border-danger")
      ]}
      {@rest}
    />
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

  attr :warning, :boolean, default: false, doc: "if true the element will gain a yellow border"

  attr :field, FormField,
    required: true,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :hidden, :boolean, default: false, doc: "hides component if true"

  attr :disabled, :boolean, default: false, doc: "disallows editing if true"

  attr :rest, :global, include: ~w(disabled phx-debounce step)
  slot :inner_block

  def datetime(%{field: %FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(field: nil, id: field.id, name: field.name)
      |> assign(:errors, Enum.map(field.errors, &CoreComponents.translate_error(&1)))
      |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)

    ~H"""
    <div
      phx-feedback-for={@name}
      class={["#{@class}", @hidden && "hidden"]}
      id={"#{@id}-root-element"}
    >
      <.label for={@id} class="block">{@label}</.label>
      <span class="block flex flex-row">
        <input
          id={@id}
          name={@name}
          min={@min}
          max={@max}
          disabled={@disabled}
          value={Form.normalize_value("datetime-local", @value)}
          class={[
            "bg-bg-elevation-5 border border-border-primary px-3 py-1.5 p-0 w-64
              rounded text-text-primary disabled:text-text-secondary [scrollbar-width:thin] overflow-auto
              disabled:bg-bg-elevation-3 ring-0 ring-border-focus focus:ring-0 focus:border-border-focus
              focus:drop-shadow-[0 .25rem .25rem rgba(13,110,253,0.25) appearance-auto dark:text-white dark:[color-scheme:dark]",
            @errors != [] && "border-danger focus:border-danger",
            @warning && "border-warning focus:border-warning"
          ]}
          type={@type}
          {@rest}
        />
        <span class="flex flex-row ml-2">{render_slot(@inner_block)}</span>
      </span>

      <.input_error :for={msg <- @errors}>{msg}</.input_error>
    </div>
    """
  end

  @doc """
  Renders a pagination component.

  ## Examples
      <.pagination meta={@meta} />
  """
  attr :rest, :global, include: ~w(meta)

  def pagination(assigns) do
    ~H"""
    <Flop.Phoenix.pagination
      on_paginate={JS.push("paginate_start") |> JS.push("paginate-alerts")}
      disabled_link_attrs={[
        class: "border-secondary-disabled text-secondary-disabled cursor-not-allowed
          hover:bg-transparent hover:text-secondary-disabled hover:border-secondary-disabled
          active:bg-transparent active:text-secondary-disabled active:border-secondary-disabled"
      ]}
      page_links={3}
      class="flex flex-row justify-center has-[.ellipsis]:w-[370px]"
      page_link_attrs={[
        class:
          "rounded-none h-auto min-h-fit #{secondary_button_classes()} !py-1 !px-2 leading-[1.5] font-normal"
      ]}
      current_page_link_attrs={[
        class:
          "rounded-none h-auto min-h-fit #{secondary_button_classes()} !py-1 !px-2 leading-[1.5] font-normal !bg-primary hover:!bg-primary-hover text-text-invert"
      ]}
      page_list_attrs={[
        class: "join mx-3 [&>:first-child>button]:rounded-s-sm [&>:last-child>button]:rounded-e-sm"
      ]}
      {@rest}
    >
      <:previous attrs={[
        class: "text-primary flex items-center mr-auto !py-1 !px-[6px] leading-[1.5]",
        "aria-labelledby": "paginate-previous"
      ]}>
        <.caret_icon direction={:left} />
        <span id="paginate-previous" class="text-xs hidden lg:flex-inline font-normal">Previous</span>
      </:previous>
      <:ellipsis>
        <span
          class="ellipsis pointer-events-none text-primary-disabled border-primary-disabled bg-transparent rounded-none btn h-auto min-h-fit !py-1 !px-2 leading-[1.5] font-normal"
          aria-hidden="true"
        >
          &hellip;
        </span>
      </:ellipsis>
      <:next attrs={[
        class: "text-primary flex items-center ml-auto !py-1 !px-[6px] leading-[1.5] order-last",
        "aria-labelledby": "paginate-next"
      ]}>
        <span id="paginate-next" class="text-xs hidden lg:flex-inline font-normal">Next</span>
        <.caret_icon direction={:right} />
      </:next>
    </Flop.Phoenix.pagination>
    """
  end

  @doc """
  Renders a caret_icon component.

  ## Examples
      <.caret_icon direction={:left} class={@class} />
  """
  attr :direction, :atom, doc: "atom for direction of caret"
  attr :class, :string, default: "", doc: "classes to add to the containing div"

  def caret_icon(%{direction: :left} = assigns) do
    ~H"""
    <span class={"#{@class} w-4 h-4"}>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="2"
        stroke="currentColor"
        class="w-4 h-4"
      >
        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5 8.25 12l7.5-7.5" />
      </svg>
    </span>
    """
  end

  def caret_icon(%{direction: :right} = assigns) do
    ~H"""
    <span class={"#{@class} w-4 h-4"}>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="2"
        stroke="currentColor"
        class="w-4 h-4"
      >
        <path stroke-linecap="round" stroke-linejoin="round" d="m8.25 4.5 7.5 7.5-7.5 7.5" />
      </svg>
    </span>
    """
  end

  @doc """
  Renders a "loading" component.

  ## Examples
      <.loading loading={true} loading_text="Now loading" />Click here!</.loading>
  """
  attr :loading, :boolean, doc: "state of whether loading is happening"
  attr :loading_text, :string, default: "Loading", doc: "Text to display while loading"
  attr :button_text, :string, doc: "Text to display when not loading"
  slot :inner_block, required: true

  def loading(assigns) do
    ~H"""
    <%= if @loading do %>
      <div class="flex space-x-1 items-baseline hover:cursor-wait">
        <span class="loading-ellipsis"><span>{@loading_text}</span><span>.</span><span>.</span><span>.</span></span>
      </div>
    <% else %>
      {render_slot(@inner_block)}
    <% end %>
    """
  end
end
