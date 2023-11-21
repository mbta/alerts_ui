defmodule AlertsUI.FeedOutput.CreateGtfsProtobufTest do
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUI.Alerts
  alias AlertsUI.FeedOutput.{CreateGtfsProtobuf, CreateOutputAlert, GTFSProtobufDefinition}

  @translated_image %{
    localized_image: [
      %{
        url: "hello.com",
        language: "en",
        media_type: "image/png"
      }
    ]
  }

  @translated_string %{
    translation: [
      %{
        text: "hello",
        language: "en"
      }
    ]
  }

  @time_range %{
    start: 1_700_155_435,
    end: 1_700_155_443
  }

  @trip_descriptor %{
    trip_id: "1",
    route_id: "2",
    direction_id: nil,
    start_time: "25:01:01",
    start_date: "20231013",
    schedule_relationship: :ADDED
  }

  @entity_selector %{
    agency_id: "1",
    route_id: "2",
    route_type: 3,
    trip: @trip_descriptor,
    stop_id: "4",
    direction_id: 5
  }

  @alert %{
    active_period: [@time_range, @time_range],
    informed_entity: [@entity_selector, @entity_selector],
    cause: :OTHER_CAUSE,
    effect: :NO_SERVICE,
    url: @translated_string,
    header_text: @translated_string,
    description_text: @translated_string,
    tts_header_text: @translated_string,
    tts_description_text: @translated_string,
    severity_level: :INFO,
    image: @translated_image,
    image_alternative_text: @translated_string,
    cause_detail: @translated_string,
    effect_detail: @translated_string
  }

  describe "output_protobuf/1" do
    test "encodes alerts from database" do
      insert(:alert, %{alert_id: "123"})
      insert(:alert, %{alert_id: "234"})

      alert_1 = Alerts.get_by_alert_id("123")
      alert_2 = Alerts.get_by_alert_id("234")

      encoded_protobuf =
        [alert_1, alert_2]
        |> Enum.map(&CreateOutputAlert.build_alert/1)
        |> CreateGtfsProtobuf.output_protobuf()

      assert is_binary(encoded_protobuf) == true
    end
  end

  describe "build_alert/1" do
    test "builds alert" do
      actual_alert = CreateGtfsProtobuf.build_alert(@alert) |> Map.from_struct()
      actual_ie = actual_alert.informed_entity |> hd |> Map.from_struct()
      actual_trip = actual_ie.trip |> Map.from_struct()
      assert actual_trip == @trip_descriptor
      assert actual_ie.agency_id == @entity_selector.agency_id
    end

    test "does not include extraneous field" do
      extended_alert = Map.put(@alert, :severity, 1)
      actual_alert = CreateGtfsProtobuf.build_alert(extended_alert) |> Map.from_struct()
      assert Map.has_key?(actual_alert, :severity) == false
    end

    test "encodes alert" do
      assert @alert
             |> CreateGtfsProtobuf.build_entity_selector()
             |> GTFSProtobufDefinition.FeedMessage.encode()
             |> is_binary()
    end
  end

  describe "build_entity_selector/1" do
    test "builds informed_entity without trip correctly" do
      ie = Map.delete(@entity_selector, :trip)
      actual = CreateGtfsProtobuf.build_entity_selector(ie)
      assert actual.trip == nil
      assert actual.route_type == 3
    end

    test "builds with trip correctly" do
      actual = CreateGtfsProtobuf.build_entity_selector(@entity_selector)
      assert actual.trip.trip_id == "1"
      assert actual.route_type == 3
    end

    test "informed_entity with trip encodes correctly" do
      assert @entity_selector
             |> CreateGtfsProtobuf.build_entity_selector()
             |> GTFSProtobufDefinition.FeedMessage.encode()
             |> is_binary()
    end
  end

  describe "build_trip_descriptor/1" do
    test "builds trip correctly" do
      actual = CreateGtfsProtobuf.build_trip_descriptor(@trip_descriptor)
      assert actual.trip_id == "1"
      assert actual.schedule_relationship == :ADDED
    end

    test "trip can be encoded without error" do
      assert CreateGtfsProtobuf.build_trip_descriptor(@trip_descriptor)
             |> GTFSProtobufDefinition.FeedMessage.encode()
             |> is_binary()
    end
  end

  describe "build_translated_string/2" do
    test "translated string can be encoded" do
      assert @translated_string
             |> CreateGtfsProtobuf.build_translated_string()
             |> GTFSProtobufDefinition.FeedMessage.encode()
             |> is_binary()
    end
  end

  describe "build_translated_image/2" do
    test "translated image can be encoded" do
      assert @translated_image
             |> CreateGtfsProtobuf.build_translated_image()
             |> GTFSProtobufDefinition.FeedMessage.encode()
             |> is_binary()
    end
  end

  describe "build_time_range/2" do
    test "time range can be encoded" do
      assert @time_range
             |> CreateGtfsProtobuf.build_time_range()
             |> GTFSProtobufDefinition.FeedMessage.encode()
             |> is_binary()
    end
  end
end
