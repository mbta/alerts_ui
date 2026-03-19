defmodule AlertsUI.Models.FeatureFlag do
  @moduledoc """
  Represent feature flags in the database that represent app-wide features, not
  per-user features
  """

  use AlertsUI.Schema
  import Ecto.Changeset

  @permitted_fields ~w(
    name
    enabled
  )a

  @type t :: %__MODULE__{
          name: String.t(),
          enabled: boolean()
        }

  schema "feature_flags" do
    field :name, :string
    field :enabled, :boolean, default: false
    timestamps()
  end

  @spec build(String.t()) :: Ecto.Changeset.t()
  def build(name, enabled \\ false) do
    changeset(%__MODULE__{}, %{name: name, enabled: enabled})
  end

  @spec toggle(t()) :: Ecto.Changeset.t()
  def toggle(%__MODULE__{} = feature_flag) do
    feature_flag |> changeset(%{enabled: !feature_flag.enabled})
  end

  @spec changeset(any(), map(), keyword()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = feature_flag, params, _options \\ []) do
    feature_flag
    |> cast(params, @permitted_fields)
  end
end
