defmodule AlertsUIWeb.FormComponents.Helpers.AutoText.BuildAutoTextTest do
  @moduledoc false
  use AlertsUIWeb.ConnCase
  alias AlertsUIWeb.FormComponents.Helpers.AutoText.AutoTextDuration

  describe "starts_today?/1" do
    test "if start time is nil returns false" do
      assert AutoTextDuration.starts_today?(nil, ~N[2025-05-08 13:00:00]) == false
    end

    test "if start time is today before midnight return true" do
      current_time = ~N[2025-05-08 13:00:00]
      start_datetime = ~N[2025-05-08 23:00:00]
      expected = true
      actual = AutoTextDuration.starts_today?(start_datetime, current_time)
      assert expected == actual
    end

    test "if start time is after midnight but before end of service return true" do
      current_time = ~N[2025-05-08 13:00:00]
      start_datetime = ~N[2025-05-09 01:00:00]
      expected = true
      actual = AutoTextDuration.starts_today?(start_datetime, current_time)
      assert expected == actual
    end

    test "if both times are after midnight but before EOS return true" do
      current_time = ~N[2025-05-09 01:00:00]
      start_datetime = ~N[2025-05-09 02:00:00]
      expected = true
      actual = AutoTextDuration.starts_today?(start_datetime, current_time)
      assert expected == actual
    end

    test "if start time is next day after end of service return false" do
      current_time = ~N[2025-05-08 13:00:00]
      start_datetime = ~N[2025-05-09 05:00:00]
      expected = false
      actual = AutoTextDuration.starts_today?(start_datetime, current_time)
      assert expected == actual
    end

    test "if both times are after midnight but start is after EOS return false" do
      current_time = ~N[2025-05-09 01:00:00]
      start_datetime = ~N[2025-05-09 05:00:00]
      expected = false
      actual = AutoTextDuration.starts_today?(start_datetime, current_time)
      assert expected == actual
    end
  end

  describe "build_date_string/3" do
    test "no start time returns empty string" do
      start_datetime = nil
      end_datetime = ~N[2025-05-18 15:00:00]

      assert AutoTextDuration.build_date_string(start_datetime, end_datetime, false) == ""
    end

    test "starts today but no end datetime" do
      start_datetime = ~N[2025-05-08 15:00:00]
      end_datetime = nil

      expected = "until further notice"
      actual = assert AutoTextDuration.build_date_string(start_datetime, end_datetime, true)
      assert expected == actual
    end

    test "does not start today but no end datetime" do
      start_datetime = ~N[2025-05-09 15:00:00]
      end_datetime = nil
      expected = "from Fri, May 09 to until further notice"
      actual = AutoTextDuration.build_date_string(start_datetime, end_datetime, false)
      assert expected == actual
    end

    test "starts today and has end datetime" do
      start_datetime = ~N[2025-05-08 15:00:00]
      end_datetime = ~N[2025-05-18 15:00:00]

      expected = "until Sun, May 18"
      actual = assert AutoTextDuration.build_date_string(start_datetime, end_datetime, true)
      assert expected == actual
    end

    test "does not start today and has end datetime" do
      start_datetime = ~N[2025-05-09 15:00:00]
      end_datetime = ~N[2025-05-18 15:00:00]

      expected = "from Fri, May 09 to Sun, May 18"
      actual = assert AutoTextDuration.build_date_string(start_datetime, end_datetime, false)
      assert expected == actual
    end
  end
end
