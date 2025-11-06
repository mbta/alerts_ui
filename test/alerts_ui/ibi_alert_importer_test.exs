defmodule AlertsUI.IBIAlertImporterTest do
  @moduledoc false

  use AlertsUI.DataCase

  import AlertsUI.IBIAlertImporter

  alias AlertsUI.AlertBuilder
  alias AlertsUI.Repo
  alias AlertsUI.Models.Alert
  alias AlertsUI.Models.IBIAlert

  @import_fixture_path "./test/support/fixtures/ibi_alert_importer/import.csv"
  @update_fixture_path "./test/support/fixtures/ibi_alert_importer/update.csv"

  setup do
    # This fixture contains a header and 10 rows to import, assiging them
    # alert_ids 1..10
    ingest_csv_file(@import_fixture_path)

    %{
      ibi_alert: Repo.one(from i in IBIAlert, where: i.alert_id == "1"),
      recurring_alert: Repo.one(from i in IBIAlert, where: i.alert_id == "2")
    }
  end

  describe "ingest_csv_file/2" do
    test "it creates IBI alerts from the import file, ignoring headers" do
      assert Repo.aggregate(IBIAlert, :count) == 10
      assert Repo.aggregate(from(i in IBIAlert, where: i.alert_id == "alert_id"), :count) == 0
    end

    test "it updates or inserts IBI alerts depending on the alert id and version number" do
      # This fixture again contains a header and 10 rows, this time in two batches:
      # - ids 6-10, version 1 again, which will trigger an update; alert_time_type will be set to "updated"
      # - ids 6-10, version 2, which will insert 5 new records
      ingest_csv_file(@update_fixture_path)
      assert Repo.aggregate(IBIAlert, :count) == 15

      assert Repo.aggregate(from(i in IBIAlert, where: i.alert_time_type == "updated"), :count) ==
               5

      assert Repo.aggregate(from(i in IBIAlert, where: i.alert_id == "10"), :count) == 2

      id_ten_version_one = Repo.get_by(IBIAlert, alert_id: "10", version_no: "1")
      id_ten_version_two = Repo.get_by(IBIAlert, alert_id: "10", version_no: "2")

      assert id_ten_version_one.alert_time_type == "updated"
      assert id_ten_version_two.alert_time_type == "One-time"
    end
  end

  describe "ibi_alert_to_changeset/2" do
    test "active period and informed entity can be disabled via options", %{
      ibi_alert: ibi_alert
    } do
      changeset = %Ecto.Changeset{} = ibi_alert_to_changeset(ibi_alert, %Alert{}, no_active_periods: true, no_informed_entities: true)
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
      alert_params =
        ibi_alert
        |> ibi_alert_to_alert_data()
        |> AlertBuilder.build_alert(from_ibi(ibi_alert, :combination))

      assert alert_params.effect_name == ibi_alert.effect_name
    end
  end

  describe "from_ibi/2" do
    test ":route_type", %{ibi_alert: ibi_alert} do
      assert ibi_alert.gui_mode_name == "Commuter Rail"
      assert from_ibi(ibi_alert, :route_type) == 2
    end

    test ":route_ids", %{ibi_alert: ibi_alert} do
      assert ibi_alert.informed_route_id == "CR-Fitchburg"
      assert from_ibi(ibi_alert, :route_ids) == ["CR-Fitchburg"]
    end

    test ":stop_ids", %{ibi_alert: ibi_alert} do
      assert ibi_alert.informed_stop_id == "CR-Fitchburg-Test-Stop"
      assert from_ibi(ibi_alert, :stop_ids) == ["CR-Fitchburg-Test-Stop"]
    end

    test ":trip_ids", %{ibi_alert: ibi_alert} do
      assert ibi_alert.informed_trip_id == "CR-Fitchburg-Test-Trip"
      assert from_ibi(ibi_alert, :trip_ids) == ["CR-Fitchburg-Test-Trip"]
    end

    test ":direction", %{ibi_alert: ibi_alert} do
      assert ibi_alert.informed_direction_id == "1"
      assert from_ibi(ibi_alert, :direction) == "1"
    end

    test ":facility_id", %{ibi_alert: ibi_alert} do
      assert ibi_alert.informed_facility_id == "CR-Fitchburg-Test-Facility"
      assert from_ibi(ibi_alert, :facility_id) == "CR-Fitchburg-Test-Facility"
    end

    test ":service_types", %{ibi_alert: ibi_alert} do
      assert from_ibi(ibi_alert, :service_types) == [from_ibi(ibi_alert, :route_type)]
    end

    test ":reminder_times", %{ibi_alert: ibi_alert} do
      assert ibi_alert.reminders ==
               "2025-10-22T11:40:00.123 send bulletin; 2025-10-22T11:45 send tweet"

      assert from_ibi(ibi_alert, :reminder_times) == [
               ~N[2025-10-22 11:40:00],
               ~N[2025-10-22 11:45:00]
             ]
    end

    test ":alert_timing", %{ibi_alert: ibi_alert, recurring_alert: recurring_alert} do
      assert ibi_alert.alert_time_type == "One-time"
      assert from_ibi(ibi_alert, :alert_timing) == :one_time
      assert recurring_alert.alert_time_type == "Recurring"
      assert from_ibi(recurring_alert, :alert_timing) == :recurring
    end

    test ":active_period_start", %{ibi_alert: ibi_alert} do
      assert ibi_alert.effect_start == "3/25/2013 10:30:00 PM"
      assert from_ibi(ibi_alert, :active_period_start) == ~N[2013-03-25 22:30:00]
    end

    test ":active_period_end", %{ibi_alert: ibi_alert} do
      assert ibi_alert.effect_end == "3/26/2013 2:03:00 AM"
      assert from_ibi(ibi_alert, :active_period_end) == ~N[2013-03-26 02:03:00]
    end

    test ":active_period_start_time", %{recurring_alert: recurring_alert} do
      assert recurring_alert.recurrence_start_time == "07:00:00"
      assert from_ibi(recurring_alert, :active_period_start_time) == ~T[07:00:00]
    end

    test ":active_period_end_time", %{recurring_alert: recurring_alert} do
      assert recurring_alert.recurrence_end_time == "17:00:00"
      assert from_ibi(recurring_alert, :active_period_end_time) == ~T[17:00:00]
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
      assert from_ibi(ibi_alert, :notification_period_start) == ~N[2013-03-25 00:06:51]
    end

    test ":notification_period_end", %{ibi_alert: ibi_alert} do
      assert ibi_alert.notif_end == "3/26/2013 2:03:00 AM"
      assert from_ibi(ibi_alert, :notification_period_end) == ~N[2013-03-26 02:03:00]
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
  end
end
