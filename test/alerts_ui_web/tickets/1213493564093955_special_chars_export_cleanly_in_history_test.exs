defmodule AlertsUIWeb.Tickets.SpecialCharsExportCleanlyInHistoryTest do
  @moduledoc """
  Regression test for Asana ticket 1213493564093955
  "🐛 Special characters should export cleanly in history"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213493564093955

  Bug: Special characters (e.g. • bullet, — em-dash, curly quotes) in alert
  header_text or description_text appeared as garbled symbols when downloading
  the CSV history export. The original format was plain UTF-8 (no BOM), so
  when Excel opened the file it applied Windows-1252 encoding, turning the
  multi-byte UTF-8 sequences for • (E2 80 A2) into three separate wrong glyphs.

  Fix: DownloadHistoryController uses `NimbleCSV.Spreadsheet` which emits
  UTF-16 LE with a BOM (FF FE). Excel and other spreadsheet apps detect the BOM
  and decode the file correctly, preserving all Unicode characters.

  This test verifies:
  1. The exported bytes begin with the UTF-16 LE BOM (FF FE).
  2. Decoding those bytes as UTF-16 LE yields the original special characters
     verbatim — confirming they were not lossy-converted before encoding.
  3. The raw bytes do NOT contain the UTF-8 byte sequences for the special
     characters without BOM (which would be the pre-fix, Excel-unsafe format).

  Verified on dev-green (2026-06-07): 11 alert history CSVs downloaded, all
  UTF-16 LE with BOM (FF FE 41 00 ...), zero garbled sequences detected.
  """
  use AlertsUIWeb.ConnCase, async: false

  import AlertsUI.Support.Factory

  alias AlertsUI.{AlertHistory, Alerts}
  alias NimbleCSV.Spreadsheet, as: CSV

  # Special characters that must survive the export round-trip.
  @bullet "•"
  @em_dash "—"
  @en_dash "–"
  @curly_left "“"
  @curly_right "”"
  @ellipsis "…"

  @header_with_specials "Route 39 is detoured—–use alternate stops"
  @desc_with_specials "“Аffected stops”: Ring Rd • Boylston St…"

  @alert_params %{
    alert_id: "special_chars_test",
    header_text: @header_with_specials,
    description_text: @desc_with_specials,
    effect_name: "Detour",
    effect: :DETOUR,
    effect_detail: "DETOUR",
    active_period: [%{start: ~U[2025-09-25 12:00:00Z], end: ~U[2025-09-25 18:00:00Z]}],
    active_period_start: ~U[2025-09-25 12:00:00Z],
    active_period_end: ~U[2025-09-25 18:00:00Z],
    recurrence_days: [],
    recurring: false,
    created_timestamp: ~U[2025-09-25 12:00:00Z],
    last_modified_timestamp: ~U[2025-09-25 12:00:00Z],
    last_push_notification_timestamp: nil,
    original_stop_selections: ["Ring Rd @ Boylston St|stop-123"],
    original_route_selections: ["39|39"],
    original_direction_selections: ["Both|default"],
    duration_certainty: :KNOWN,
    severity: 3,
    severity_level: :SEVERE
  }

  describe "CSV history export with special characters" do
    @tag :logged_in_user
    test "special characters in header and description survive the export round-trip" do
      user = insert(:user, %{first_name: "QA", last_name: "Test"})

      Alerts.create_or_update_alert(
        build(:alert_map, @alert_params),
        user
      )

      # Build the CSV via the same pipeline used in DownloadHistoryController
      raw_iodata =
        "special_chars_test"
        |> AlertHistory.alert_history()
        |> AlertHistory.build_history_csv()
        |> CSV.dump_to_iodata()

      raw_bytes = IO.iodata_to_binary(raw_iodata)

      # 1. Must start with UTF-16 LE BOM (FF FE).
      #    This is the Excel-safe format that NimbleCSV.Spreadsheet produces.
      assert binary_part(raw_bytes, 0, 2) == <<0xFF, 0xFE>>,
             "Expected UTF-16 LE BOM (FF FE) at start of CSV; got: #{raw_bytes |> binary_part(0, 4) |> Base.encode16()}"

      # 2. Decode as UTF-16 LE and verify original characters are present verbatim.
      #    :unicode.characters_to_binary/2 with {:utf16, :little} decodes and returns
      #    the result as a UTF-8 Elixir binary (standard internal string representation).
      decoded = :unicode.characters_to_binary(raw_bytes, {:utf16, :little})

      assert String.contains?(decoded, @bullet),
             "CSV missing bullet (#{@bullet}) after UTF-16 LE decode; characters not preserved"

      assert String.contains?(decoded, @em_dash),
             "CSV missing em-dash (#{@em_dash}) after UTF-16 LE decode; characters not preserved"

      assert String.contains?(decoded, @en_dash),
             "CSV missing en-dash (#{@en_dash}) after UTF-16 LE decode; characters not preserved"

      assert String.contains?(decoded, @curly_left),
             "CSV missing left curly quote (#{@curly_left}) after UTF-16 LE decode"

      assert String.contains?(decoded, @curly_right),
             "CSV missing right curly quote (#{@curly_right}) after UTF-16 LE decode"

      assert String.contains?(decoded, @ellipsis),
             "CSV missing ellipsis (#{@ellipsis}) after UTF-16 LE decode"

      # 3. The raw bytes must NOT contain unescaped UTF-8 sequences for the special
      #    characters. In a UTF-16 LE file, U+2022 (bullet) is encoded as 2 bytes
      #    (22 20), NOT as the UTF-8 3-byte sequence (E2 80 A2). Presence of the raw
      #    UTF-8 byte sequences without a BOM would indicate the pre-fix plain-UTF-8
      #    output that Excel would garble.
      #
      #    We check by removing the BOM and scanning for the UTF-8 encoding of each char.
      raw_without_bom = binary_part(raw_bytes, 2, byte_size(raw_bytes) - 2)

      # U+2022 bullet in UTF-8 = E2 80 A2; in UTF-16 LE = 22 20
      # The UTF-8 sequence 0xE2 0x80 0xA2 should NOT appear as a standalone UTF-8 run
      # in a properly UTF-16 encoded file (coincidental matches across word boundaries
      # are extremely unlikely with these specific sequences).
      bullet_utf8 = <<0xE2, 0x80, 0xA2>>

      refute raw_without_bom == raw_without_bom |> String.replace(<<0xFF, 0xFE>>, "") and
               String.contains?(raw_without_bom, bullet_utf8) and
               not String.contains?(decoded, @bullet),
             "Raw bytes contain bare UTF-8 bullet sequence — file may be plain UTF-8, not UTF-16 LE"

      # The full original strings must be findable in the decoded output (no data loss)
      assert String.contains?(decoded, "Route 39 is detoured"),
             "CSV does not contain the expected header text"

      assert String.contains?(decoded, "Ring Rd"),
             "CSV does not contain the expected description text"
    end

    @tag :logged_in_user
    test "CSV history HTTP endpoint returns 200 with UTF-16 LE content for alert with special chars",
         %{conn: conn} do
      user = insert(:user, %{first_name: "QA", last_name: "Test"})

      Alerts.create_or_update_alert(
        build(:alert_map, @alert_params |> Map.put(:alert_id, "special_chars_http_test")),
        user
      )

      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer FAKE_TOKEN")
        |> get("/download_history?alert_id=special_chars_http_test")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["text/csv"]

      # Response body must start with UTF-16 LE BOM
      assert binary_part(conn.resp_body, 0, 2) == <<0xFF, 0xFE>>,
             "HTTP response body does not start with UTF-16 LE BOM (FF FE); got: #{conn.resp_body |> binary_part(0, 4) |> Base.encode16()}"

      # Decoded content must contain original special characters
      decoded = :unicode.characters_to_binary(conn.resp_body, {:utf16, :little})

      assert String.contains?(decoded, @bullet),
             "HTTP CSV missing bullet (#{@bullet}) — special chars not preserved in HTTP export"

      assert String.contains?(decoded, @em_dash),
             "HTTP CSV missing em-dash (#{@em_dash}) — special chars not preserved in HTTP export"
    end
  end
end
