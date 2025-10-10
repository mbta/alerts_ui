defmodule AlertsUI.IBIAlertImporterTest do
  @moduledoc false

  use AlertsUI.DataCase

  alias AlertsUI.Repo
  alias AlertsUI.Models.IBIAlert
  alias AlertsUI.IBIAlertImporter

  @import_fixture_path "./test/support/fixtures/ibi_alert_importer/import.csv"
  @update_fixture_path "./test/support/fixtures/ibi_alert_importer/update.csv"

  describe "import_csv_file/2" do
    setup do
      # This fixture contains a header and 10 rows to import, assiging them 
      # alert_ids 1..10
      IBIAlertImporter.import_csv_file(@import_fixture_path)
      :ok
    end

    test "it creates IBI alerts from the import file, ignoring headers" do
      assert Repo.aggregate(IBIAlert, :count) == 10
      assert Repo.aggregate(from(i in IBIAlert, where: i.alert_id == "alert_id"), :count) == 0
    end

    test "it updates or inserts IBI alerts depending on the alert id and version number" do
      # This fixture again contains a header and 10 rows, this time in two batches:
      # - ids 6-10, version 1 again, which will trigger an update; alert_time_type will be set to "updated"
      # - ids 6-10, version 2, which will insert 5 new records
      IBIAlertImporter.import_csv_file(@update_fixture_path)
      assert Repo.aggregate(IBIAlert, :count) == 15
      assert Repo.aggregate(from(i in IBIAlert, where: i.alert_time_type == "updated"), :count) == 5
      assert Repo.aggregate(from(i in IBIAlert, where: i.alert_id == "10"), :count) == 2

      id_ten_version_one = Repo.get_by(IBIAlert, alert_id: "10", version_no: "1")
      id_ten_version_two = Repo.get_by(IBIAlert, alert_id: "10", version_no: "2")

      assert id_ten_version_one.alert_time_type == "updated"
      assert id_ten_version_two.alert_time_type == "One-time"
    end
  end
end
