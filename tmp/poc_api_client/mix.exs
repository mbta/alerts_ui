defmodule PocApiClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :poc_api_client,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {PocApiClient.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.2"},
      {:oidcc, "~> 3.1"},
      {:req, "~> 0.4.0"}
    ]
  end
end
