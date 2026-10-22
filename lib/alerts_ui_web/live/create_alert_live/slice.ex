defprotocol AlertsUIWeb.CreateAlertLive.Slice do
  alias AlertsUIWeb.CreateAlertLive.AlertData
  alias Ecto.Changeset
  alias Phoenix.LiveView.Socket

  @moduledoc """
  Protocols and etc. related to **slices**: logical subsets of
  alert data, modularized for ease of management and comprehension.

  To be a slice, a struct must implement the following callbacks:
  """
  @spec mount(t, Socket.t(), map()) :: Socket.t()
  def mount(slice, socket, params)

  @spec extract(t, AlertData.t() | nil, map()) :: t
  def extract(slice, alert, params)

  @spec transform(t, Changeset.t(), map(), Socket.t()) :: Changeset.t()
  def transform(slice, changeset, params, socket)

  @spec validate(t, Changeset.t(), map(), Socket.t()) :: Changeset.t()
  def validate(slice, changeset, params, socket)

  @spec assigns(t, Socket.t(), map()) :: Socket.t()
  def assigns(slice, socket, params)
end
