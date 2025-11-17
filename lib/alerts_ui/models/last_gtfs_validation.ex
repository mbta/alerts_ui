defmodule AlertsUI.Models.LastGTFSValidation do
  @moduledoc """
    Each row stores the datetime of a GTFS validation, the newest row has the most recent time.
    Includes context functions.
  """

  use AlertsUI.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias AlertsUI.Repo

  @type t :: %__MODULE__{
          datetime_of_last_validation: DateTime.t() | nil
        }

  schema "last_gtfs_validation" do
    field :datetime_of_last_validation, :utc_datetime
    timestamps()
  end

  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = last_validation, params) do
    last_validation
    |> cast(params, [:datetime_of_last_validation])
    |> validate_required([:datetime_of_last_validation], message: "is required")
  end

  @spec store_last_gtfs_validation(DateTime.t()) :: {:ok | :error, any()}
  def store_last_gtfs_validation(datetime \\ DateTime.utc_now()) do
    %__MODULE__{}
    |> changeset(%{datetime_of_last_validation: datetime})
    |> Repo.insert()
    |> case do
      {:ok, %{datetime_of_last_validation: datetime}} -> {:ok, datetime}
      {:error, result} -> {:error, result}
    end
  end

  @spec get_most_recent_validation() :: DateTime.t()
  def get_most_recent_validation do
    result = __MODULE__ |> last(:datetime_of_last_validation) |> Repo.one()

    if result do
      result.datetime_of_last_validation
    else
      nil
    end
  end
end
