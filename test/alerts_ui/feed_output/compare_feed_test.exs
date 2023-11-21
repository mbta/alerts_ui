defmodule AlertsUI.FeedOutput.CompareFeedTest do
  use AlertsUI.DataCase, async: true
  import AlertsUI.Support.Factory
  alias AlertsUI.FeedOutput.CompareFeed

  describe "compare_headers/2" do
    test "returns :ok if headers match and timestamps are ints" do
      header_1 = %{
        "gtfs_realtime_version" => "2.0",
        "incrementality" => "FULL_DATASET",
        "timestamp" => 1_700_593_672
      }

      header_2 = %{
        "gtfs_realtime_version" => "2.0",
        "incrementality" => "FULL_DATASET",
        "timestamp" => 4
      }

      assert CompareFeed.compare_headers(header_1, header_2) == :ok
    end

    test "returns error tuple if mismatch" do
      header_1 = %{
        "gtfs_realtime_version" => "1.0",
        "incrementality" => "INCREMENTAL_DATASET",
        "timestamp" => 1_700_593_672
      }

      header_2 = %{
        "gtfs_realtime_version" => "2.0",
        "incrementality" => "FULL_DATASET",
        "timestamp" => 4
      }

      assert {:header_mismatch, [^header_1, ^header_2]} =
               CompareFeed.compare_headers(header_1, header_2)
    end
  end

  describe "compare informed_entities/2" do
    test "returns ok with match regardless of order" do
      list_1 = [
        %{
          "stop_id" => "door-qamnl-pickup",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["PARK_CAR"]
        },
        %{
          "stop_id" => "door-qamnl-indep",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["PARK_CAR"]
        },
        %{
          "stop_id" => "70104",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["RIDE"]
        }
      ]

      list_2 = [
        %{
          "stop_id" => "door-qamnl-indep",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["PARK_CAR"]
        },
        %{
          "stop_id" => "70104",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["RIDE"]
        },
        %{
          "stop_id" => "door-qamnl-pickup",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["PARK_CAR"]
        }
      ]

      assert :ok = CompareFeed.compare_informed_entities(list_1, list_2, "123")
    end

    test "returns error if list length is different" do
      list_1 = [
        %{
          "stop_id" => "door-qamnl-pickup",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["PARK_CAR"]
        },
        %{
          "stop_id" => "door-qamnl-indep",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["PARK_CAR"]
        },
        %{
          "stop_id" => "70104",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["RIDE"]
        }
      ]

      list_2 = [
        %{
          "stop_id" => "door-qamnl-indep",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["PARK_CAR"]
        },
        %{
          "stop_id" => "70104",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["RIDE"]
        }
      ]

      expected = {:informed_entity_mismatch, ["Alert_id: 123", list_1, list_2]}
      assert expected == CompareFeed.compare_informed_entities(list_1, list_2, "123")
    end

    test "returns error when entities don't match" do
      list_1 = [
        %{
          "stop_id" => "door-qamnl-pickup",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["PARK_CAR"]
        },
        %{
          "stop_id" => "door-qamnl-indep",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["PARK_CAR"]
        },
        %{
          "stop_id" => "70104",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["RIDE"]
        }
      ]

      list_2 = [
        %{
          "stop_id" => "door-qamnl-indep",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["RIDE"]
        },
        %{
          "stop_id" => "70104",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["RIDE"]
        },
        %{
          "stop_id" => "door-qamnl-pickup",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["PARK_CAR"]
        }
      ]

      expected = {:informed_entity_mismatch, ["Alert_id: 123", list_1, list_2]}
      assert expected == CompareFeed.compare_informed_entities(list_1, list_2, "123")
    end
  end

  describe "compare active periods/2" do
    test "returns ok with match regardless of order" do
      list_1 = [
        %{
          "start" => 1
        },
        %{
          "start" => 1,
          "end" => 2
        },
        %{
          "start" => 2,
          "end" => 3
        }
      ]

      list_2 = [
        %{
          "start" => 1,
          "end" => 2
        },
        %{
          "start" => 2,
          "end" => 3
        },
        %{
          "start" => 1
        }
      ]

      assert :ok = CompareFeed.compare_active_periods(list_1, list_2, "123")
    end

    test "returns error if list length is different" do
      list_1 = [
        %{
          "start" => 1
        },
        %{
          "start" => 1,
          "end" => 2
        },
        %{
          "start" => 2,
          "end" => 3
        }
      ]

      list_2 = [
        %{
          "start" => 1,
          "end" => 2
        },
        %{
          "start" => 2,
          "end" => 3
        }
      ]

      expected = {:active_period_mismatch, ["Alert_id: 123", list_1, list_2]}
      assert expected == CompareFeed.compare_active_periods(list_1, list_2, "123")
    end

    test "returns error when active periods don't match" do
      list_1 = [
        %{
          "start" => 1
        },
        %{
          "start" => 1,
          "end" => 2
        },
        %{
          "start" => 2,
          "end" => 3
        }
      ]

      list_2 = [
        %{
          "start" => 1
        },
        %{
          "start" => 1,
          "end" => 2
        },
        %{
          "start" => 2,
          "end" => 5
        }
      ]

      expected = {:active_period_mismatch, ["Alert_id: 123", list_1, list_2]}
      assert expected == CompareFeed.compare_active_periods(list_1, list_2, "123")
    end
  end

  describe "compare_alerts/2" do
    test "Alerts maps with matching fields return ok" do
      alert_1 = build(:alert_entity_data)
      alert_2 = build(:alert_entity_data)

      assert CompareFeed.compare_alerts(alert_1, alert_2) == :ok
    end

    test "Alerts maps with different fields return error tuple" do
      translation_1 = %{
        "translation" => [
          %{
            "language" => "en",
            "text" => "hello"
          }
        ]
      }

      translation_2 = %{
        "translation" => [
          %{
            "language" => "en",
            "text" => "goodbye"
          }
        ]
      }

      alert_1 = build(:alert_entity_data, %{"alert" => %{"header_text" => translation_1}})
      alert_2 = build(:alert_entity_data, %{"alert" => %{"header_text" => translation_2}})

      assert {:alert_map_mismatch, %{value: _, removed: _, added: _, changed: :map_change}} =
               CompareFeed.compare_alerts(alert_1, alert_2)
    end
  end

  describe "compare_entity_lists/2" do
    test "returns error tuple if lists of alert_ids differ in content" do
      list_1 = [
        build(:alert_entity_data, %{"id" => "123"}),
        build(:alert_entity_data, %{"id" => "234"}),
        build(:alert_entity_data, %{"id" => "456"})
      ]

      list_2 = [
        build(:alert_entity_data, %{"id" => "123"}),
        build(:alert_entity_data, %{"id" => "233"}),
        build(:alert_entity_data, %{"id" => "456"})
      ]

      expected = {:error_in_alert_match, [id_mismatch: ["234", "233"]]}

      assert expected == CompareFeed.compare_entity_lists(list_1, list_2)
    end

    test "returns error tuple if lists differ in length" do
      list_1 = [
        build(:alert_entity_data, %{"id" => "123"}),
        build(:alert_entity_data, %{"id" => "234"}),
        build(:alert_entity_data, %{"id" => "456"})
      ]

      list_2 = [
        build(:alert_entity_data, %{"id" => "123"}),
        build(:alert_entity_data, %{"id" => "234"}),
        build(:alert_entity_data, %{"id" => "456"}),
        build(:alert_entity_data, %{"id" => "567"})
      ]

      expected = {:alert_list_length_difference, [eq: ["123", "234", "456"], ins: ["567"]]}

      assert expected == CompareFeed.compare_entity_lists(list_1, list_2)
    end

    test "returns error tuple if lists of alert content does not match" do
      list_1 = [
        build(:alert_entity_data, %{"id" => "123"}),
        build(:alert_entity_data, %{"id" => "234", "alert" => %{"cause_detail" => "cool"}}),
        build(:alert_entity_data, %{"id" => "456"})
      ]

      list_2 = [
        build(:alert_entity_data, %{"id" => "123"}),
        build(:alert_entity_data, %{"id" => "234", "alert" => %{"cause_detail" => "bean"}}),
        build(:alert_entity_data, %{"id" => "456"})
      ]

      expected = {
        :error_in_alert_match,
        [
          alert_map_mismatch: %{
            value: %{
              "cause_detail" => %{removed: "cool", added: "bean", changed: :primitive_change}
            },
            removed: %{"cause_detail" => "cool"},
            added: %{"cause_detail" => "bean"},
            changed: :map_change
          }
        ]
      }

      assert expected == CompareFeed.compare_entity_lists(list_1, list_2)
    end

    test "returns error tuple if informed entities in alerts do not match" do
      informed_entity_1 = [
        %{
          "stop_id" => "door-qamnl-indep",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["RIDE"]
        },
        %{
          "stop_id" => "door-qamnl-pickup",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["PARK_CAR"]
        }
      ]

      informed_entity_2 = [
        %{
          "stop_id" => "door-qamnl-pickup",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["PARK_CAR"]
        },
        %{
          "stop_id" => "door-qamnl-indep",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["PARK_CAR"]
        }
      ]

      list_1 = [
        build(:alert_entity_data, %{"id" => "123"}),
        build(:alert_entity_data, %{
          "id" => "234",
          "alert" => %{"cause_detail" => "cool", "informed_entity" => informed_entity_1}
        }),
        build(:alert_entity_data, %{"id" => "456"})
      ]

      list_2 = [
        build(:alert_entity_data, %{"id" => "123"}),
        build(:alert_entity_data, %{
          "id" => "234",
          "alert" => %{"cause_detail" => "cool", "informed_entity" => informed_entity_2}
        }),
        build(:alert_entity_data, %{"id" => "456"})
      ]

      expected = {
        :error_in_alert_match,
        [
          informed_entity_mismatch: ["Alert_id: 234", informed_entity_1, informed_entity_2]
        ]
      }

      assert expected == CompareFeed.compare_entity_lists(list_1, list_2)
    end

    test "returns error tuple if active periods in alerts do not match" do
      active_period_1 = [
        %{
          "start" => 1
        },
        %{
          "start" => 2,
          "end" => 3
        },
        %{
          "start" => 1,
          "end" => 2
        }
      ]

      active_period_2 = [
        %{
          "start" => 1,
          "end" => 3
        },
        %{
          "start" => 2,
          "end" => 3
        },
        %{
          "start" => 1
        }
      ]

      list_1 = [
        build(:alert_entity_data, %{"id" => "123"}),
        build(:alert_entity_data, %{
          "id" => "234",
          "alert" => %{"cause_detail" => "cool", "active_period" => active_period_1}
        }),
        build(:alert_entity_data, %{"id" => "456"})
      ]

      list_2 = [
        build(:alert_entity_data, %{"id" => "123"}),
        build(:alert_entity_data, %{
          "id" => "234",
          "alert" => %{"cause_detail" => "cool", "active_period" => active_period_2}
        }),
        build(:alert_entity_data, %{"id" => "456"})
      ]

      expected = {
        :error_in_alert_match,
        [
          active_period_mismatch: ["Alert_id: 234", active_period_1, active_period_2]
        ]
      }

      assert expected == CompareFeed.compare_entity_lists(list_1, list_2)
    end

    test "returns :ok if everything matches" do
      active_period = [
        %{
          "start" => 2,
          "end" => 3
        }
      ]

      informed_entity = [
        %{
          "stop_id" => "door-qamnl-indep",
          "facility_id" => "park-qamnl-garage",
          "activities" => ["RIDE"]
        }
      ]

      list_1 = [
        build(:alert_entity_data, %{"id" => "123"}),
        build(:alert_entity_data, %{
          "id" => "234",
          "alert" => %{
            "cause_detail" => "cool",
            "active_period" => active_period,
            "informed_entity" => informed_entity
          }
        }),
        build(:alert_entity_data, %{"id" => "456"})
      ]

      list_2 = [
        build(:alert_entity_data, %{"id" => "123"}),
        build(:alert_entity_data, %{
          "id" => "234",
          "alert" => %{
            "cause_detail" => "cool",
            "active_period" => active_period,
            "informed_entity" => informed_entity
          }
        }),
        build(:alert_entity_data, %{"id" => "456"})
      ]

      assert CompareFeed.compare_entity_lists(list_1, list_2) == :ok
    end
  end
end
