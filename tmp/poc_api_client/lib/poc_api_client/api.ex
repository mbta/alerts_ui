defmodule PocApiClient.Api do
  @moduledoc """
  API Client
  """

  alias Req.Response

  def get_test(token) do
    url = api_base_url() <> "/api/test"
    headers = [authorization: "Bearer " <> token]

    with {:ok, %Response{status: 200, body: body}} = Req.get(url: url, headers: headers) do
      body
    end
  end

  defp api_base_url, do: System.fetch_env!("POC_API_BASE_URL")
end
