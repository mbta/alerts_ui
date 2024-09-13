defmodule AlertsUI.Models.SeverityLevel do
  @moduledoc """
    Atoms to be used in the severity level field of Alerts.
  """

  @doc """
  Returns list of atoms allowed in severity level field of alert

  ## Examples
      iex> is_list(AlertsUI.Models.SeverityLevel.severity_levels)
      true
  """
  def severity_levels,
    do: [
      :UNKNOWN_SEVERITY,
      :INFO,
      :WARNING,
      :SEVERE
    ]

  @doc """
  Returns severity level given an integer

  ## Examples
      iex> AlertsUI.Models.SeverityLevel.severity_level_by_severity(nil)
      nil
      iex> AlertsUI.Models.SeverityLevel.severity_level_by_severity(0)
      nil
      iex> AlertsUI.Models.SeverityLevel.severity_level_by_severity(1)
      :INFO
      iex> AlertsUI.Models.SeverityLevel.severity_level_by_severity(2)
      nil
      iex> AlertsUI.Models.SeverityLevel.severity_level_by_severity(3)
      :WARNING
      iex> AlertsUI.Models.SeverityLevel.severity_level_by_severity(10)
      :SEVERE
  """
  @spec severity_level_by_severity(integer()) :: atom() | nil
  def severity_level_by_severity(severity) do
    severity_tuples()
    |> Enum.flat_map(fn {_, sev, level} ->
      case sev == severity do
        true -> [level]
        false -> []
      end
    end)
    |> case do
      [] -> nil
      [level] -> level
    end
  end

  @type severity_description :: String.t()
  @type severity :: integer()
  @type severity_level() :: atom
  @type severity_tuple ::
          {severity_description :: severity_description(), severity :: severity(),
           severity_level :: severity_level()}

  @spec severity_tuples() :: [severity_tuple()]
  def severity_tuples do
    [
      {"information", 1, :INFO},
      {"up to 10 minutes", 3, :WARNING},
      {"up to 15 minutes", 4, :WARNING},
      {"up to 20 minutes", 5, :WARNING},
      {"up to 25 minutes", 6, :SEVERE},
      {"up to 30 minutes", 7, :SEVERE},
      {"more than 30 minutes", 8, :SEVERE},
      {"more than an hour", 9, :SEVERE},
      {"High priority (deliver to T-Alert subscribers immediately)", 10, :SEVERE}
    ]
  end
end
