# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     AlertsUI.Repo.insert!(%AlertsUI.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
[
  "UNKNOWN_CAUSE",
  "OTHER_CAUSE",
  "TECHNICAL_PROBLEM",
  "STRIKE",
  "DEMONSTRATION",
  "ACCIDENT",
  "HOLIDAY",
  "WEATHER",
  "MAINTENANCE",
  "CONSTRUCTION",
  "POLICE_ACTIVITY",
  "MEDICAL_EMERGENCY"
]
|> Enum.map(&AlertsUI.Repo.insert!(%AlertsUI.Models.Cause{name: &1}))

[
  "NO_SERVICE",
  "REDUCED_SERVICE",
  "SIGNIFICANT_DELAYS",
  "DETOUR",
  "ADDITIONAL_SERVICE",
  "MODIFIED_SERVICE",
  "OTHER_EFFECT",
  "UNKNOWN_EFFECT",
  "STOP_MOVED"
]
|> Enum.map(&AlertsUI.Repo.insert!(%AlertsUI.Models.Effect{name: &1}))
