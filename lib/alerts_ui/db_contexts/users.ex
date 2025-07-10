defmodule AlertsUI.DBContexts.Users do
  @moduledoc """
  The Users context.
  """

  import Ecto.Query, warn: false
  alias AlertsUI.Repo

  alias AlertsUI.Models.User

  def create_or_update_user(params, existing_user \\ %User{}) do
    existing_user
    |> User.changeset(params)
    |> PaperTrail.insert_or_update()
    |> case do
      {:ok, %{model: user}} -> {:ok, user}
      {:error, result} -> {:error, result}
    end
  end

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  def get_by_keycloak_id(keycloak_id) do
    users = Repo.all_by(User, keycloak_id: keycloak_id)

    if Enum.empty?(users) do
      nil
    else
      hd(users)
    end
  end
end
