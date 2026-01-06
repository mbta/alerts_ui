defmodule AlertsUIWeb.FormattingTest do
  @moduledoc """
  Module for testing string formatting helper functions
  """
  use AlertsUIWeb.ConnCase
  import AlertsUIWeb.Formatting

  test "word_list/1 with no elements" do
    assert "" == word_list([])
  end

  test "word_list/1 with one element" do
    assert "one" == word_list(["one"])
  end

  test "word_list/1 with twp elements" do
    assert "one and two" == word_list(["one", "two"])
  end

  test "word_list/1 with many elements" do
    assert "one, two, three and a four" == word_list(["one", "two", "three", "a four"])
  end
end
