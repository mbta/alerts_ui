defmodule AlertsUI.IBIAlertImporter.CauseMapper do
  @aliases %{
    {2, "Amtrak"} => "AMTRAK_TRAIN_TRAFFIC",
    {2, "an earlier mechanical problem"} => "MECHANICAL_ISSUE",
    {2, "an earlier signal problem"} => "SIGNAL_ISSUE",
    {2, "crossing malfunction"} => "CROSSING_ISSUE",
    {4, "ice in harbour"} => "ICE_IN_HARBOR",
    {2, "mechanical failure"} => "MECHANICAL_ISSUE",
    {4, "mechanical failure"} => "MECHANICAL_PROBLEM",
    {2, "mechanical problem"} => "MECHANICAL_ISSUE",
    {1, "signal failure"} => "SIGNAL_ISSUE",
    {2, "signal problem"} => "SIGNAL_ISSUE",
    {2, "switch problem"} => "SWITCH_ISSUE"
  }

  def cause_name_to_am_detail(mode, name) do
    case Map.get(@aliases, {mode, name}) do
      nil -> name |> String.replace(~r/\s/, "_") |> String.upcase
      am_detail -> am_detail
    end
  end
end

