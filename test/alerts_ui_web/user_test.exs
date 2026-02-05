defmodule AlertsUIWeb.UserTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AlertsUI.Models.User

  doctest AlertsUI.Models.User

  describe "new" do
    test "generates a new User struct given an id, email, and role" do
      assert User.new("MOCK-ID", "MOCK-EMAIL", "FIRSTNAME", "LASTNAME", [:viewer, :author]) ==
               %User{
                 keycloak_id: "MOCK-ID",
                 email: "MOCK-EMAIL",
                 first_name: "FIRSTNAME",
                 last_name: "LASTNAME",
                 roles: [:viewer, :author]
               }
    end

    test "defaults to no roles" do
      assert User.new("MOCK-ID", "MOCK-EMAIL", "FIRSTNAME", "LASTNAME") == %User{
               keycloak_id: "MOCK-ID",
               email: "MOCK-EMAIL",
               first_name: "FIRSTNAME",
               last_name: "LASTNAME",
               roles: []
             }
    end
  end
end
