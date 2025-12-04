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
    |> Repo.insert_or_update()
    |> case do
      {:ok, user} -> {:ok, user}
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
  @spec get_user!(String.t() | nil) :: map() | User.t()
  def get_user!(nil), do: %{}
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

  def create_or_update_user_from_session(current_user) do
    existing_user = get_by_keycloak_id(current_user.keycloak_id) || %User{}
    {:ok, user} = create_or_update_user(Map.from_struct(current_user), existing_user)
    user
  end
end
