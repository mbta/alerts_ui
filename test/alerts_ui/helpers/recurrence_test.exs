defmodule AlertsUI.Helpers.RecurrenceTest do
  use ExUnit.Case, asyne: true

  import AlertsUI.Helpers.Recurrence

  describe "recurrence_text_from_days/1" do
    test "using atom values" do
      assert "Thursdays" == recurrence_text_from_days([:thursday])
    end

    test "using string values" do
      assert "Thursdays" == recurrence_text_from_days(["thursday"])
    end

    test "using out of order and mixed values" do
      assert "weekends" == recurrence_text_from_days(["Sunday", :saturday])
    end

    test "all 7 days is 'daily'" do
      assert "daily" ==
               recurrence_text_from_days([
                 :monday,
                 :tuesday,
                 :wednesday,
                 :thursday,
                 :friday,
                 :saturday,
                 :sunday
               ])
    end

    test "all 5 weekdays is 'weekdays'" do
      assert "weekdays" ==
               recurrence_text_from_days([:monday, :tuesday, :wednesday, :thursday, :friday])
    end

    test "Saturday and Sunday is 'weekends'" do
      assert "weekends" ==
               recurrence_text_from_days([:saturday, :sunday])
    end

    test "a range is '[start]-[end]'" do
      assert "Tuesday-Saturday" ==
               recurrence_text_from_days([:tuesday, :wednesday, :thursday, :friday, :saturday])
    end

    test "a range wrapping around is '[start]-[end]'" do
      assert "Friday-Monday" ==
               recurrence_text_from_days([:monday, :friday, :saturday, :sunday])
    end

    test "a range starting Monday is 'Monday-[end]'" do
      assert "Monday-Wednesday" ==
               recurrence_text_from_days([:monday, :tuesday, :wednesday])
    end

    test "a range ending Sunday is '[start]-Sunday'" do
      assert "Friday-Sunday" ==
               recurrence_text_from_days([:friday, :saturday, :sunday])
    end

    test "a disparate set is '[count] days a week'" do
      assert "4 days a week" ==
               recurrence_text_from_days([:tuesday, :thursday, :friday, :saturday])
    end

    test "a disparate set starting monday is '[count] days a week'" do
      assert "3 days a week" ==
               recurrence_text_from_days([:monday, :wednesday, :sunday])
    end

    test "a disparate set that ends on sunday is '[count] days a week'" do
      assert "3 days a week" ==
               recurrence_text_from_days([:thursday, :saturday, :sunday])
    end

    test "one is '[day]s'" do
      assert "Fridays" == recurrence_text_from_days([:friday])
    end

    test "none is nil" do
      assert nil == recurrence_text_from_days([])
    end
  end
end
