defprotocol AlertsUIWeb.CreateAlertMonoLive.Slice do
  @moduledoc """
  Protocols and etc. related to **slices**: logical subsets of
  alert data, modularized for ease of management and comprehension.

  To be a slice, a struct must implement the following callbacks:
  """

  @spec extract(t, Alert.t() | nil) :: t
  def extract(slice, alert)

  @spec transform(t, Changeset.t(), map()) :: Changeset.t()
  def transform(slice, changeset, params)

  @spec validate(t, Changeset.t(), map()) :: Changeset.t()
  def validate(slice, changeset, params)

  @spec assigns(t, Socket.t(), map()) :: Socket.t()
  def assigns(slice, socket, params)
end
