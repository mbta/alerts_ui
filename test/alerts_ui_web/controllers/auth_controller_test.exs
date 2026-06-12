defmodule AlertsUIWeb.AuthControllerTest do
  use AlertsUIWeb.ConnCase

  import AlertsUI.UsersFixtures

  alias AlertsUI.Models.User
  alias Ueberauth.Auth
  alias Ueberauth.Auth.{Credentials, Extra, Info}

  describe "GET /auth/:provider" do
    test "redirects to the home page when already logged in", %{conn: conn} do
      conn =
        conn
        |> log_in_user()
        |> get(~p"/auth/keycloak")

      assert redirected_to(conn) == "/"
    end
  end

  describe "GET /auth/:provider/callback" do
    setup %{conn: conn} do
      # Building a user with string roles to mimic the type coming from Keycloak
      # Conversion to atoms happens during authentication in our app
      user = user_fixture(["viewer", "author"])

      {:ok, conn: conn, user: user}
    end

    test "given an ueberauth auth, stores the user in the session", %{conn: conn, user: user} do
      id = user.id
      email = user.email

      conn =
        conn
        |> assign(:ueberauth_auth, auth_for(user))
        |> get(~p"/auth/keycloak/callback")

      assert session_user = get_session(conn, :user)

      assert %User{
               keycloak_id: ^id,
               email: ^email,
               roles: [:viewer, :author]
             } = session_user
    end

    test "adds a logout URI to the session", %{conn: conn, user: user} do
      conn =
        conn
        |> assign(:ueberauth_auth, auth_for(user))
        |> get(~p"/auth/keycloak/callback")

      assert is_binary(get_session(conn, :logout_uri))
    end

    test "given an ueberauth auth, redirects to the home page", %{conn: conn, user: user} do
      conn =
        conn
        |> assign(:ueberauth_auth, auth_for(user))
        |> get(~p"/auth/keycloak/callback")

      assert redirected_to(conn) == "/"
    end

    test "redirects to the home page for an ueberauth failure", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{username: "test_username"})
        |> assign(:ueberauth_failure, "failed")
        |> get(~p"/auth/keycloak/callback")

      assert redirected_to(conn) == "/"
    end
  end

  @spec auth_for(User.t()) :: Auth.t()
  @spec auth_for(User.id(), String.t(), String.t() | nil) :: Auth.t()
  defp auth_for(%User{id: id, email: email, roles: roles}), do: auth_for(id, email, roles)

  defp auth_for(id, email, roles) do
    %Auth{
      uid: email,
      provider: :keycloak,
      strategy: Ueberauth.Strategy.FakeKeycloak,
      info: %Info{
        name: "John Rider",
        email: email
      },
      credentials: %Credentials{
        token: "FAKE TOKEN",
        refresh_token: "FAKE REFRESH TOKEN",
        expires_at: System.system_time(:second) + 1_000,
        other: %{
          id_token: "FAKE ID TOKEN"
        }
      },
      extra: %Extra{
        raw_info: %{
          claims: %{
            "sub" => id,
            "auth_time" => System.system_time(:second)
          },
          userinfo: %{
            "email" => email,
            "email_verified" => true,
            "family_name" => "Rider",
            "given_name" => "John",
            "name" => "John Rider",
            "phone_number" => "5551234567",
            "preferred_username" => email,
            "resource_access" => %{
              "alerts-ui" => %{
                "roles" => roles
              }
            }
          }
        }
      }
    }
  end
end
