defmodule AlertsUIWeb.Tickets.WafFirewallTest do
  @moduledoc """
  Regression test for Asana ticket 1213534705218460
  "🧯 Ensure AM is behind the web firewall"
  https://app.asana.com/1/15492006741476/project/1167196461144361/task/1213534705218460

  Context: 290,000 GET requests hit the Alerts Manager between 1–1:30am on
  March 4 without WAF throttling/blocking. The fix was to ensure the app is
  behind an AWS WAF with managed rules, so that malicious traffic (XSS, SQLi,
  known scanner user-agents) is blocked at the ALB layer before reaching the
  Phoenix app server.

  This test verifies the WAF is active on dev-green by making HTTP requests
  that AWS Managed Rules are known to block. The distinguishing signal:
  - Legitimate requests: 302/200/404, `server: Cowboy` (Phoenix reaches us)
  - WAF-blocked requests: 403, `server: awselb/2.0` (blocked before Phoenix)

  Tagged `:external` — requires a live network connection to dev-green and
  a valid environment. Not run in normal CI; run manually with:

    mix test test/alerts_ui_web/tickets/1213534705218460_waf_firewall_test.exs --include external

  QA verdict: PASS. All attack-pattern requests returned HTTP 403 from
  `awselb/2.0`; all clean requests returned 302/404 from `Cowboy`.
  """
  use ExUnit.Case, async: false

  @moduletag :external

  @base_url "https://alerts-manager-dev-green.mbtace.com"

  # Helper: issue a GET and return {status_code, server_header}
  # In Req 0.5.x, response.headers is a map with lowercase keys and list values,
  # e.g. %{"server" => ["Cowboy"]} — we take the first value.
  defp get(path, opts \\ []) do
    headers = Keyword.get(opts, :headers, [])
    params = Keyword.get(opts, :params, [])

    url = "#{@base_url}#{path}"

    response =
      Req.get!(url,
        headers: headers,
        params: params,
        redirect: false,
        # Don't raise on 4xx
        retry: false
      )

    server =
      case response.headers["server"] do
        [v | _] -> v
        nil -> "unknown"
        v when is_binary(v) -> v
      end

    {response.status, server}
  end

  describe "WAF blocks known attack patterns (returns 403 from awselb, never from Cowboy)" do
    test "XSS payload in query parameter is blocked" do
      {status, server} = get("/", params: [test: "<script>alert(1)</script>"])

      assert status == 403,
             "Expected 403 for XSS payload but got #{status}"

      assert server == "awselb/2.0",
             "Expected WAF (awselb/2.0) to block request but got server: #{server}"
    end

    test "SQL injection pattern in query parameter is blocked" do
      {status, server} = get("/", params: [q: "1 OR 1=1--"])

      assert status == 403,
             "Expected 403 for SQL injection payload but got #{status}"

      assert server == "awselb/2.0",
             "Expected WAF (awselb/2.0) to block request but got server: #{server}"
    end

    test "known scanner user-agent (sqlmap) is blocked" do
      {status, server} = get("/", headers: [{"user-agent", "sqlmap/1.0"}])

      assert status == 403,
             "Expected 403 for sqlmap user-agent but got #{status}"

      assert server == "awselb/2.0",
             "Expected WAF (awselb/2.0) to block request but got server: #{server}"
    end

    test "known scanner user-agent (Nikto) is blocked" do
      {status, server} = get("/", headers: [{"user-agent", "Nikto/2.1.6"}])

      assert status == 403,
             "Expected 403 for Nikto user-agent but got #{status}"

      assert server == "awselb/2.0",
             "Expected WAF (awselb/2.0) to block request but got server: #{server}"
    end
  end

  describe "WAF does not block legitimate requests (server: Cowboy)" do
    test "clean GET / passes through to the Phoenix app" do
      {status, server} = get("/")

      # Phoenix redirects unauthenticated users to /auth/keycloak (302)
      assert status in [200, 302],
             "Expected 200 or 302 for clean request but got #{status}"

      assert server == "Cowboy",
             "Expected clean request to reach Phoenix (Cowboy) but got server: #{server}"
    end

    test "clean GET /api/v1/alerts passes through (404 from router)" do
      {status, server} = get("/api/v1/alerts")

      # Route doesn't exist as a public endpoint, Phoenix returns 404
      assert status in [200, 302, 404],
             "Expected 200/302/404 for clean API request but got #{status}"

      assert server == "Cowboy",
             "Expected clean request to reach Phoenix (Cowboy) but got server: #{server}"
    end
  end
end
