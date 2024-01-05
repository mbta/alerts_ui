defmodule AlertsUI.MixProject do
  use Mix.Project

  def project do
    [
      app: :alerts_ui,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [
        ignore_modules: [
          AlertsUI.DataCase,
          AlertsUIWeb.PageHTML,
          AlertsUIWeb.ErrorHTML,
          AlertsUIWeb.CoreComponents,
          AlertsUIWeb.Layouts,
          AlertsUIWeb.Router,
          AlertsUIWeb.Telemetry,
          AlertsUI.Telemetry,
          AlertsUI.Application,
          AlertsUI.Support.Factory,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.Position,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.Shape,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TripUpdate,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TripUpdate.StopTimeEvent,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TripUpdate.StopTimeUpdate,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TripUpdate.StopTimeUpdate.StopTimeProperties,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TripUpdate.TripProperties,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.VehicleDescriptor,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.VehiclePosition,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.VehiclePosition.CarriageDetails,
          AlertsUI.FeedOutput.WriteToS3,
          AlertsUI.FeedOutput.WriteLocal
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {AlertsUI.Application, []},
      extra_applications: [:logger, :runtime_tools, :exprotobuf]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:credo, "~> 1.7.1", only: [:dev, :test]},
      {:dialyxir, "~> 1.4.1", only: [:dev, :test], runtime: false},
      {:ecto_sql, "~> 3.10"},
      {:ehmon, github: "mbta/ehmon", only: :prod},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_rds, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:ex_machina, "~> 2.7.0", only: :test},
      {:exprotobuf, "~> 1.2.17"},
      {:gen_stage, "~> 1.2.1"},
      {:gettext, "~> 0.20"},
      {:finch, "~> 0.13"},
      {:floki, ">= 0.30.0", only: :test},
      {:hackney, "1.20.1"},
      {:jason, "~> 1.2"},
      {:map_diff, "~> 1.3.4"},
      {:oban, "~> 2.16"},
      {:phoenix, "~> 1.7.7"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.0"},
      {:plug_cowboy, "~> 2.5"},
      {:postgrex, ">= 0.0.0"},
      {:req, "~> 0.4.0"},
      {:stream_data, "~> 0.6.0", only: :test},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:ueberauth, "~> 0.10"},
      {:ueberauth_oidcc, "~> 0.3.0"},
      {:flop_phoenix, "~> 0.22.4"},
      {:tzdata, "~> 1.1"},
      {:ecto_psql_extras, "~> 0.6", only: :dev}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "ecto.test_setup": ["ecto.create", "ecto.migrate"],
      "ecto.test_reset": ["ecto.drop", "ecto.test_setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
