defmodule AlertsUI.Jobs.TripValidationWorkerTest do
  use AlertsUI.DataCase, async: false

  import ExUnit.CaptureLog
  import AlertsUI.Support.Factory

  import Mock
  import Test.Support.Helpers

  alias AlertsUI.Jobs.TripValidationWorker
  alias MBTAV3API.Schedules.Repo, as: SchedulesRepo
  alias MBTAV3API.Schedules.Trip
  alias MBTAV3API.Services.Repo, as: ServicesRepo
  alias MBTAV3API.Services.Service
  alias Oban.Job

  describe "perform" do
    test "reports no warnings when there are no soon-to-be-ending services" do
      set_log_level(:info)

      today = Date.utc_today()
      service_id = "service-1"
      service_2 = "service-2"

      with_mocks([
        {SchedulesRepo, [],
         [
           trips_by_ids: fn
             _, [], [base_url: _, api_key: _] ->
               [
                 %Trip{id: "1", service_id: service_id},
                 %Trip{id: "2", service_id: service_2}
               ]
           end
         ]},
        {ServicesRepo, [],
         [
           by_ids: fn
             _service_ids, _params, _opts ->
               [
                 %Service{id: service_id, end_date: Date.add(today, 7)},
                 %Service{id: service_2, end_date: Date.add(today, 7)}
               ]
           end
         ]}
      ]) do
        insert(:alert, %{
          alert_id: "123",
          informed_entity: [%{trip: %{trip_id: "1"}}, %{trip: %{trip_id: "2"}}]
        })

        {:ok, log} =
          with_log(fn ->
            TripValidationWorker.perform(%Job{args: %{}})
          end)

        assert log =~ "All trips on open alerts are still in service"
      end
    end

    test "warns when there are trips with soon-to-be-ending services" do
      set_log_level(:warning)

      today = Date.utc_today()
      tomorrow = Date.add(today, 1)
      service_id = "service-1"
      service_ending_soon = "service-2"

      with_mocks([
        {SchedulesRepo, [],
         [
           trips_by_ids: fn
             _, [], [base_url: _, api_key: _] ->
               [
                 %Trip{id: "1", service_id: service_id},
                 %Trip{id: "2", service_id: service_ending_soon}
               ]
           end
         ]},
        {ServicesRepo, [],
         [
           by_ids: fn
             _service_ids, _params, _opts ->
               [
                 %Service{id: service_id, end_date: Date.add(today, 7)},
                 %Service{id: service_ending_soon, end_date: tomorrow}
               ]
           end
         ]}
      ]) do
        insert(:alert, %{
          alert_id: "123",
          informed_entity: [%{trip: %{trip_id: "1"}}, %{trip: %{trip_id: "2"}}]
        })

        {:warning, log} =
          with_log(fn ->
            TripValidationWorker.perform(%Job{args: %{}})
          end)

        assert log =~
                 "Trip 2 will be invalid after #{tomorrow} but is still listed in alert(s) 123"
      end
    end
  end
end
