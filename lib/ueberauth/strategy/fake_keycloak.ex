defmodule Ueberauth.Strategy.FakeKeycloak do
  @moduledoc """
  A fake ueberauth strategy for development purposes.
  """
  use Ueberauth.Strategy, ignores_csrf_attack: true

  alias Ueberauth.Strategy
  alias Ueberauth.Auth.{Credentials, Extra, Info}

  @mbta_uuid "acad6280-8cb9-4e00-999c-c6d141adf0a6"
  @email "fake@example.com"
  @roles ["user"]
  @token "fake_access_token"

  @impl Strategy
  def handle_request!(conn) do
    conn
    |> redirect!("/auth/keycloak/callback")
    |> halt()
  end

  @impl Strategy
  def handle_callback!(conn) do
    conn
  end

  @impl Strategy
  def uid(_conn) do
    "fake_uid"
  end

  @impl Strategy
  def credentials(conn) do
    %Credentials{
      token: @token,
      expires: true,
      expires_at: expires_at(conn),
      other: %{
        id_token: @token,
        provider: :keycloak,
        user_info: %{
          "email" => @email,
          "email_verified" => true,
          "family_name" => "Name",
          "given_name" => "Fake",
          "mbta_uuid" => @mbta_uuid,
          "name" => "Fake Name",
          "phone_number" => "+15555555555",
          "preferred_username" => @email,
          "sub" => "7eaf0809-88da-4895-97e0-c83444ab310f"
        }
      },
      refresh_token: nil,
      scopes: [],
      secret: nil,
      token_type: "Bearer"
    }
  end

  @impl Strategy
  def info(_conn) do
    %Info{
      email: @email
    }
  end

  @impl Strategy
  def extra(conn) do
    %Extra{
      raw_info: %{
        claims: %{
          "exp" => expires_at(conn),
          "sub" => @mbta_uuid
        },
        opts: %{
          client_id: "fake_client",
          issuer: "fake_issuer"
        },
        userinfo: %{
          "resource_access" => %{
            "alerts-ui" => %{
              "roles" => @roles
            }
          }
        }
      }
    }
  end

  @impl Strategy
  def handle_cleanup!(conn) do
    conn
  end

  # Support configuring a specific expiration_datetime for testing.
  # Otherwise, default to 9 hours from now.
  @spec expires_at() :: integer
  @spec expires_at(Plug.Conn.t()) :: integer
  defp expires_at(conn) do
    case expiration_datetime_from_session(conn) do
      nil ->
        expires_at()

      expiration_datetime ->
        DateTime.to_unix(expiration_datetime)
    end
  end

  defp expires_at do
    nine_hours_in_seconds = 9 * 60 * 60

    expiration_datetime = DateTime.add(DateTime.utc_now(), nine_hours_in_seconds)

    DateTime.to_unix(expiration_datetime)
  end

  @spec expiration_datetime_from_session(Plug.Conn.t()) :: any()
  defp expiration_datetime_from_session(conn) do
    conn
    |> fetch_session()
    |> get_session(:expiration_datetime)
  end
end
