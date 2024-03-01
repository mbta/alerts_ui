defmodule PocApiClient do
  @moduledoc """
  A proof-of-concept mock client demonstrating a request for client credentials from Keycloak, and then an authorized request to our API.
  """

  alias PocApiClient.{Api, Keycloak}

  def test do
    {:ok, token} = Keycloak.token()

    result = Api.get_test(token)

    IO.inspect(result, label: "result")

    :ok
  end
end
