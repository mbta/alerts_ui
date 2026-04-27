defprotocol AlertsUIWeb.CreateAlertMonoLive.Slice do
  @moduledoc """
  Protocols and etc. related to **slices**: logical subsets of
  alert data, modularized for ease of management and comprehension.

  To be a slice, a struct must implement the following callbacks:
  """

  @spec extract(t, Alert.t()) :: t
  def extract(slice, alert)

  @spec transform(t, Changeset.t()) :: Changeset.t()
  def transform(slice, changeset)

  @spec validate(t, Changeset.t()) :: Changeset.t()
  def validate(slice, changeset)
end
