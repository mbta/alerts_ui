defmodule AlertsUIWeb.Formatting do
  @moduledoc """
  Functions for formatting things as strings
  """

  @doc """
  Format a list of Strings into a comma separated list fit for a sentence

  Examples:
    word_list(["one", "two", "three", "a four"])
      #=> "one, two, three and a four"
    word_list(["one", "two"])
      #=> "one and two"
  """
  @spec word_list(list(String.t())) :: String.t()
  def word_list([]), do: ""
  def word_list([item]), do: item
  def word_list([item1, item2]), do: "#{item1} and #{item2}"
  def word_list([item1 | items]), do: "#{item1}, #{word_list(items)}"
end
