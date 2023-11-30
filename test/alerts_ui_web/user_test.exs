defmodule AlertsUIWeb.UserTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AlertsUIWeb.User

  doctest AlertsUIWeb.User

  describe "new" do
    test "generates a new User struct given an id, email, and role" do
      assert User.new("MOCK-ID", "MOCK-EMAIL", :admin) == %User{
               id: "MOCK-ID",
               email: "MOCK-EMAIL",
               role: :admin
             }
    end

    test "defaults to the user role" do
      assert User.new("MOCK-ID", "MOCK-EMAIL") == %User{
               id: "MOCK-ID",
               email: "MOCK-EMAIL",
               role: :user
             }
    end
  end
end
