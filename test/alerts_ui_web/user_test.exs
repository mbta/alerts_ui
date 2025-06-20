defmodule AlertsUIWeb.UserTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AlertsUI.Models.User

  doctest AlertsUI.Models.User

  describe "new" do
    test "generates a new User struct given an id, email, and role" do
      assert User.new("MOCK-ID", "MOCK-EMAIL", "FIRSTNAME", "LASTNAME", :admin) == %User{
               id: "MOCK-ID",
               email: "MOCK-EMAIL",
               first_name: "FIRSTNAME",
               last_name: "LASTNAME",
               role: :admin
             }
    end

    test "defaults to the user role" do
      assert User.new("MOCK-ID", "MOCK-EMAIL", "FIRSTNAME", "LASTNAME") == %User{
               id: "MOCK-ID",
               email: "MOCK-EMAIL",
               first_name: "FIRSTNAME",
               last_name: "LASTNAME",
               role: :user
             }
    end
  end
end
