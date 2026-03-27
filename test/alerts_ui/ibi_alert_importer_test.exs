defmodule AlertsUI.IBIAlertImporterTest do
  @moduledoc false

  use AlertsUI.DataCase

  import AlertsUI.IBIAlertImporter

  alias AlertsUI.AlertBuilder
  alias AlertsUI.Models.Alert
  alias AlertsUI.Models.IBIAlert
  alias AlertsUI.Models.LatestIBIAlert
  alias AlertsUI.Repo

  @import_fixture_path "./test/support/fixtures/ibi_alert_importer/import.csv"

  setup do
    # This fixture contains a header and 10 rows to import, assiging them
    # alert_ids 1..10
    ingest_csv_file(@import_fixture_path)

    %{
      ibi_alert: Repo.one(from i in LatestIBIAlert, where: i.alert_id == "1"),
      recurring_alert: Repo.one(from i in LatestIBIAlert, where: i.alert_id == "2")
    }
  end

  describe "ingest_csv_file/1" do
    test "it creates IBI alerts from the import file, ignoring headers" do
      assert Repo.aggregate(IBIAlert, :count) == 19
      assert Repo.aggregate(from(i in IBIAlert, where: i.alert_id == "alert_id"), :count) == 0
    end
  end

  describe "convert_ibi_alerts/1" do
    test "it imports alerts" do
      assert Repo.aggregate(Alert, :count) == 0
      convert_ibi_alerts()
      assert Repo.aggregate(Alert, :count) == 2
    end

    test "it imports alerts incrementally" do
      convert_ibi_alerts()
      Repo.one(from a in Alert, where: a.alert_id == "2") |> Repo.delete()
      assert Repo.aggregate(Alert, :count) == 1
      convert_ibi_alerts()
      assert Repo.aggregate(Alert, :count) == 2
    end
  end

  describe "ibi_alert_to_changeset/2" do
    test "sets source = \"ibi\"", %{
      ibi_alert: ibi_alert
    } do
      changeset =
        %Ecto.Changeset{} =
        ibi_alert_to_changeset(ibi_alert, %Alert{})

      assert get_field(changeset, :source) == :IBI
    end

    test "active period and informed entity can be disabled via options", %{
      ibi_alert: ibi_alert
    } do
      changeset =
        %Ecto.Changeset{} =
        ibi_alert_to_changeset(ibi_alert, %Alert{},
          no_active_periods: true,
          no_informed_entities: true
        )

      assert changeset.data.__struct__ == Alert
      assert changeset.valid?
    end

    test "informed entity is required with no options", %{
      ibi_alert: ibi_alert
    } do
      changeset = %Ecto.Changeset{} = ibi_alert_to_changeset(ibi_alert, %Alert{})
      assert changeset.data.__struct__ == Alert
      assert Keyword.get(changeset.errors, :informed_entity)
      refute changeset.valid?
    end
  end

  describe "ibi_alert_to_alert_data/1" do
    test "given a valid IBI alert it produces alert data consumable by AlertBuilder", %{
      ibi_alert: ibi_alert
    } do
      assert _alert_params =
               ibi_alert
               |> ibi_alert_to_alert_data()
               |> AlertBuilder.build_alert(from_ibi(ibi_alert, :combination))
    end
  end

  describe "from_ibi/2" do
    test ":route_type", %{ibi_alert: ibi_alert} do
      assert ibi_alert.gui_mode_name == "Commuter Rail"
      assert from_ibi(ibi_alert, :route_type) == 2
    end

    test ":route_ids", %{ibi_alert: ibi_alert} do
      assert ibi_alert.informed_route_list == "CR-Fitchburg|Fitchburg/South Acton Line"
      assert from_ibi(ibi_alert, :route_ids) == ["Fitchburg/South Acton Line|CR-Fitchburg"]
    end

    test ":stop_ids", %{ibi_alert: ibi_alert} do
      assert ibi_alert.informed_stop_list == "1|CR-Fitchburg-Test-Stop"
      assert from_ibi(ibi_alert, :stop_ids) == ["CR-Fitchburg-Test-Stop|1"]
    end

    test ":trip_ids", %{ibi_alert: ibi_alert} do
      assert ibi_alert.informed_trip_list ==
               "CR-Fitchburg-CR-Sunday-2415|2415 (11:30 pm from North Station)"

      assert from_ibi(ibi_alert, :trip_ids) == [
               "2415 (11:30 pm from North Station)|CR-Fitchburg-CR-Sunday-2415"
             ]
    end

    test ":direction", %{ibi_alert: ibi_alert} do
      assert ibi_alert.informed_direction_list == "1"
      assert from_ibi(ibi_alert, :direction) == "1"
    end

    test ":facility_ids", %{ibi_alert: ibi_alert} do
      assert ibi_alert.informed_facility_list == "1|My Elevator"
      assert from_ibi(ibi_alert, :facility_ids) == ["My Elevator|1"]
    end

    test ":service_types", %{ibi_alert: ibi_alert} do
      assert from_ibi(ibi_alert, :service_types) == [from_ibi(ibi_alert, :route_type)]
    end

    test ":alert_timing", %{ibi_alert: ibi_alert, recurring_alert: recurring_alert} do
      assert ibi_alert.alert_time_type == "One-time"
      assert from_ibi(ibi_alert, :alert_timing) == :one_time
      assert recurring_alert.alert_time_type == "Recurring"
      assert from_ibi(recurring_alert, :alert_timing) == :recurring
    end

    test ":active_period_start", %{ibi_alert: ibi_alert} do
      assert ibi_alert.effect_start == "3/25/2013 10:30:00 PM"
      assert from_ibi(ibi_alert, :active_period_start) == ~U[2013-03-26 02:30:00Z]
    end

    test ":active_period_end", %{ibi_alert: ibi_alert} do
      assert ibi_alert.effect_end == "3/26/2013 2:03:00 AM"
      assert from_ibi(ibi_alert, :active_period_end) == ~U[2013-03-26 06:03:00Z]
    end

    test ":active_period_start_time", %{recurring_alert: recurring_alert} do
      assert recurring_alert.recurrence_start_time == "07:00:00"
      utc_offset = DateTime.now!("America/New_York").utc_offset
      std_offset = DateTime.now!("America/New_York").std_offset
      time_in_utc = Time.add(~T[07:00:00], -(utc_offset + std_offset))
      assert from_ibi(recurring_alert, :active_period_start_time) == time_in_utc
    end

    test ":active_period_end_time", %{recurring_alert: recurring_alert} do
      assert recurring_alert.recurrence_end_time == "17:00:00"
      utc_offset = DateTime.now!("America/New_York").utc_offset
      std_offset = DateTime.now!("America/New_York").std_offset
      time_in_utc = Time.add(~T[17:00:00], -(utc_offset + std_offset))
      assert from_ibi(recurring_alert, :active_period_end_time) == time_in_utc
    end

    test ":active_period_start_date", %{recurring_alert: recurring_alert} do
      assert recurring_alert.recurrence_start == "3/25/2013 12:01:01 AM"
      assert from_ibi(recurring_alert, :active_period_start_date) == ~D[2013-03-25]
    end

    test ":active_period_end_date", %{recurring_alert: recurring_alert} do
      assert recurring_alert.recurrence_end == "3/25/2013 12:02:02 AM"
      assert from_ibi(recurring_alert, :active_period_end_date) == ~D[2013-03-25]
    end

    test ":recurrence_days", %{recurring_alert: recurring_alert} do
      assert recurring_alert.recurrence_days == "Monday, Wednesday, Friday"
      assert from_ibi(recurring_alert, :recurrence_days) == [:monday, :wednesday, :friday]
    end

    test ":notification_period_start", %{ibi_alert: ibi_alert} do
      assert ibi_alert.notif_start == "3/25/2013 12:06:51 AM"
      assert from_ibi(ibi_alert, :notification_period_start) == ~U[2013-03-25 04:06:51Z]
    end

    test ":notification_period_end", %{ibi_alert: ibi_alert} do
      assert ibi_alert.notif_end == "3/26/2013 2:03:00 AM"
      assert from_ibi(ibi_alert, :notification_period_end) == ~U[2013-03-26 06:03:00Z]
    end

    test ":header_text", %{ibi_alert: ibi_alert} do
      assert ibi_alert.header ==
               "Fitchburg/South Acton Line Train 2415 (11:30 pm from North Station) cancelled"

      assert from_ibi(ibi_alert, :header_text) ==
               "Fitchburg/South Acton Line Train 2415 (11:30 pm from North Station) cancelled"
    end

    test ":description_text", %{ibi_alert: ibi_alert} do
      assert ibi_alert.details == "All the deets here"
      assert from_ibi(ibi_alert, :description_text) == "All the deets here"
    end

    test ":severity", %{ibi_alert: ibi_alert} do
      assert ibi_alert.severity_name == "Moderate"
      assert from_ibi(ibi_alert, :severity) == 5
    end

    test ":combination", %{ibi_alert: ibi_alert} do
      assert from_ibi(ibi_alert, :combination) == :RDTS
    end

    test ":effect_name", %{ibi_alert: ibi_alert} do
      assert ibi_alert.effect_name == "Cancelled Trip"
      assert from_ibi(ibi_alert, :effect_name) == "Cancellation"
    end
  end
end
