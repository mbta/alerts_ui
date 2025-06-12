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
    |> Enum.find_value(fn
      {_, ^severity, level} -> level
      _ -> nil
    end)
  end

  @doc """
  Returns severity description given an integer

  ## Examples
      iex> AlertsUI.Models.SeverityLevel. severity_description_by_severity(nil)
      nil
      iex> AlertsUI.Models.SeverityLevel. severity_description_by_severity(0)
      nil
      iex> AlertsUI.Models.SeverityLevel. severity_description_by_severity(1)
      "information"
      iex> AlertsUI.Models.SeverityLevel. severity_description_by_severity(2)
      nil
      iex> AlertsUI.Models.SeverityLevel. severity_description_by_severity(3)
      "about 10 minutes"
      iex> AlertsUI.Models.SeverityLevel. severity_description_by_severity(4)
      "about 15 minutes"
      iex> AlertsUI.Models.SeverityLevel. severity_description_by_severity(5)
      "about 20 minutes"
      iex> AlertsUI.Models.SeverityLevel. severity_description_by_severity(6)
      "about 25 minutes"
      iex> AlertsUI.Models.SeverityLevel. severity_description_by_severity(7)
      "about 30 minutes"
      iex> AlertsUI.Models.SeverityLevel. severity_description_by_severity(8)
      "more than 30 minutes"
      iex> AlertsUI.Models.SeverityLevel. severity_description_by_severity(9)
      "more than an hour"
      iex> AlertsUI.Models.SeverityLevel. severity_description_by_severity(10)
      "High priority (deliver to T-Alert subscribers immediately)"
  """
  @spec severity_description_by_severity(integer()) :: String.t() | nil
  def severity_description_by_severity(severity) do
    severity_tuples()
    |> Enum.find_value(fn
      {severity_description, ^severity, _} -> severity_description
      _ -> nil
    end)
  end

  @doc """
  Returns severity string given an integer 

  ## Examples
      iex> AlertsUI.Models.SeverityLevel.severity_string_by_severity(nil)
      nil
      iex> AlertsUI.Models.SeverityLevel.severity_string_by_severity(0)
      nil
      iex> AlertsUI.Models.SeverityLevel.severity_string_by_severity(1)
      "(1 - INFO)"
      iex> AlertsUI.Models.SeverityLevel.severity_string_by_severity(2)
      nil
      iex> AlertsUI.Models.SeverityLevel.severity_string_by_severity(3)
      "(3 - WARNING)"
      iex> AlertsUI.Models.SeverityLevel.severity_string_by_severity(10)
      "(10 - SEVERE)"
  """
  @spec severity_string_by_severity(integer()) :: String.t() | nil
  def severity_string_by_severity(severity) do
    severity_tuples()
    |> Enum.find_value(fn
      {_, ^severity, level} -> "(#{severity} - #{Atom.to_string(level)})"
      _ -> nil
    end)
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
      {"about 10 minutes", 3, :WARNING},
      {"about 15 minutes", 4, :WARNING},
      {"about 20 minutes", 5, :WARNING},
      {"about 25 minutes", 6, :SEVERE},
      {"about 30 minutes", 7, :SEVERE},
      {"more than 30 minutes", 8, :SEVERE},
      {"more than an hour", 9, :SEVERE},
      {"High priority (deliver to T-Alert subscribers immediately)", 10, :SEVERE}
    ]
  end
end
