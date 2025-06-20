defmodule AlertsUI.UsersTest do
  use AlertsUI.DataCase

  alias AlertsUI.DBContexts.Users

  describe "users" do
    alias AlertsUI.Models.User

    import AlertsUI.UsersFixtures

    @invalid_attrs %{email: nil, first_name: nil, last_name: nil}

    test "list_users/0 returns all users" do
      user = create_db_user()
      assert Users.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = create_db_user()
      assert Users.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      valid_attrs = %{
        email: "some email",
        first_name: "some first_name",
        last_name: "some last_name",
        role: :user
      }

      assert {:ok, %User{} = user} = Users.create_user(valid_attrs)
      assert user.email == "some email"
      assert user.first_name == "some first_name"
      assert user.last_name == "some last_name"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = create_db_user()

      update_attrs = %{
        email: "some updated email",
        first_name: "some updated first_name",
        last_name: "some updated last_name",
        role: :admin
      }

      assert {:ok, %User{} = user} = Users.update_user(user, update_attrs)
      assert user.email == "some updated email"
      assert user.first_name == "some updated first_name"
      assert user.last_name == "some updated last_name"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = create_db_user()
      assert {:error, %Ecto.Changeset{}} = Users.update_user(user, @invalid_attrs)
      assert user == Users.get_user!(user.id)
    end

    test "change_user/1 returns a user changeset" do
      user = create_db_user()
      assert %Ecto.Changeset{} = Users.change_user(user)
    end
  end
end
