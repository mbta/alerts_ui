defmodule AlertsUI.Models.CustomFiltersKnownBugsTest do
  @moduledoc """
  Demonstrates a bug found while building the Playwright regression harness
  (see docs/playwright-e2e-proving-slice-report.md).

  Tagged `:known_bug` and excluded from the default run; see it with
  `mix test --include known_bug`. The test asserts the INTENDED behavior, so it
  stays red until the bug is fixed and turns green when it is.
  """
  use AlertsUI.DataCase

  import AlertsUI.Support.Factory
  import Ecto.Query

  alias AlertsUI.Models.{Alert, CustomFilters}
  alias AlertsUI.Repo

  @tag :known_bug
  test "search treats LIKE wildcards as literals (alert_id ilike is unescaped)" do
    insert(:alert, %{alert_id: "1000001", header_text: "Red Line delay"})
    insert(:alert, %{alert_id: "1000002", header_text: "Orange Line detour"})

    results =
      from(a in Alert)
      |> CustomFilters.multi_column_search_filter(%Flop.Filter{value: "%"}, [])
      |> Repo.all()

    # "%" is not part of any alert_id, so a correct search returns nothing.
    # BUG: `ilike(a.alert_id, ^value)` in multi_column_search_filter/3 passes the
    # raw term as a LIKE pattern, so "%" matches every row. The fix is to escape
    # `%`/`_` (or match the id exactly) before building the pattern.
    assert results == []
  end
end
