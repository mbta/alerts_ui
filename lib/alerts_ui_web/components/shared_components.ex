defmodule AlertsUIWeb.SharedComponents do
  @moduledoc """
  Provides UI components that are shared between MBTA projects.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component

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
  slot :inner_block, required: true

  def h1(assigns) do
    ~H"""
    <h1 class="font-medium mb-4 text-4xl">
      <%= render_slot(@inner_block) %>
    </h1>
    """
  end

  @doc """
  Renders an h2 header.

  ## Examples

      <.h2>H2 Header Text</.h2>

  """
  slot :inner_block, required: true

  def h2(assigns) do
    ~H"""
    <h2 class="font-medium mb-4 text-3xl">
      <%= render_slot(@inner_block) %>
    </h2>
    """
  end

  @doc """
  Renders an h3 header.

  ## Examples

      <.h3>H3 Header Text</.h3>

  """
  slot :inner_block, required: true

  def h3(assigns) do
    ~H"""
    <h3 class="font-bold mb-2 text-2xl">
      <%= render_slot(@inner_block) %>
    </h3>
    """
  end

  @doc """
  Renders an h4 header.

  ## Examples

      <.h4>H4 Header Text</.h4>

  """
  slot :inner_block, required: true

  def h4(assigns) do
    ~H"""
    <h4 class="font-medium mb-2 text-xl">
      <%= render_slot(@inner_block) %>
    </h4>
    """
  end

  @doc """
  Renders an h5 header.

  ## Examples

      <.h5>H5 Header Text</.h5>

  """
  slot :inner_block, required: true

  def h5(assigns) do
    ~H"""
    <h5 class="font-medium mb-1 text-lg">
      <%= render_slot(@inner_block) %>
    </h5>
    """
  end

  @doc """
  Renders an h6 header.

  ## Examples

      <.h6>H6 Header Text</.h6>

  """
  slot :inner_block, required: true

  def h6(assigns) do
    ~H"""
    <h6 class="font-medium mb-1 text-base">
      <%= render_slot(@inner_block) %>
    </h6>
    """
  end

  @doc """
  Renders a medium primary button.

  ##Examples
    <.button_primary>Button Text</.button_primary>
  """
  slot :inner_block, required: true

  def button_primary(assigns) do
    ~H"""
    <button class="
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
    ">
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders a medium secondary button.

  ##Examples
    <.button_secondary>Button Text</.button_secondary>
  """
  slot :inner_block, required: true

  def button_secondary(assigns) do
    ~H"""
    <button class="
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
    ">
      <%= render_slot(@inner_block) %>
    </button>
    """
  end
end
