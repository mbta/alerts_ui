defmodule AlertsUI.MixProject do
  use Mix.Project

  def project do
    [
      app: :alerts_ui,
      version: "0.1.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix_live_view] ++ Mix.compilers() ++ [:phoenix_swagger],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:laboratory]
      ],
      listeners: [Phoenix.CodeReloader],
      test_coverage: [
        ignore_modules: [
          AlertsUI.DataCase,
          AlertsUI.IBIAlertImporter,
          AlertsUI.IBIAlertImporter.IBIImportWorker,
          AlertsUIWeb.IBIImporterLive,
          AlertsUI.Models.LatestIBIAlert,
          AlertsUI.IBIAlertImportParser,
          AlertsUI.Models.IBIAlert,
          # Ignoring due to swagger definitions
          AlertsUIWeb.ApiController,
          AlertsUIWeb.ComponentsLive,
          AlertsUIWeb.DBPageLive,
          AlertsUIWeb.PageHTML,
          AlertsUIWeb.ErrorHTML,
          AlertsUIWeb.CoreComponents,
          AlertsUIWeb.SharedComponents,
          AlertsUIWeb.Layouts,
          AlertsUIWeb.Router,
          AlertsUIWeb.Telemetry,
          AlertsUI.Telemetry,
          AlertsUI.Application,
          AlertsUI.Support.Factory,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.Alert.Effect,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.Alert.SeverityLevel,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.TripUpdate.StopTimeUpdate.ScheduleRelationship,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.VehicleDescriptor.WheelchairAccessible,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.VehiclePosition.CongestionLevel,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.VehiclePosition.OccupancyStatus,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.VehiclePosition.VehicleStopStatus,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.Position,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.Shape,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.TripUpdate,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.TripUpdate.StopTimeEvent,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.TripUpdate.StopTimeUpdate,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.TripUpdate.StopTimeUpdate.StopTimeProperties,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.TripUpdate.TripProperties,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.VehicleDescriptor,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.VehiclePosition,
          AlertsUI.FeedOutput.GTFSProtobufDefinition.TransitRealtime.VehiclePosition.CarriageDetails,
          AlertsUI.FeedOutput.WriteToS3,
          AlertsUI.FeedOutput.WriteLocal,
          AlertsUIWeb.FeatureFlagsLive,
          AlertsUIWeb.SFTPDemoLive,
          AlertsUIWeb.VersionController,
          Test.Support.Helpers,
          Ueberauth.Strategy.FakeKeycloak
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
      included_applications: [:laboratory],
      extra_applications: [:logger, :runtime_tools]
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
      {:ecto, "~>  3.14.1"},
      {:ecto_psql_extras, "~> 0.8.8", only: :dev},
      {:ecto_sql, "~> 3.14.0"},
      {:ehmon, github: "mbta/ehmon", only: :prod},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_rds, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:ex_json_schema, "~> 0.5"},
      {:ex_machina, "~> 2.8.0", only: :test},
      {:gen_stage, "~> 1.3.2"},
      {:gettext, "~> 0.20"},
      {:finch, "~> 0.13"},
      {:floki, ">= 0.30.0", only: :test},
      {:flop_phoenix, "~> 0.27.0"},
      {:jason, "~> 1.2"},
      {:laboratory, github: "mbta/laboratory", ref: "master"},
      {:lazy_html, ">= 0.0.0", only: :test},
      {:live_debugger, "~> 1.0.2", only: :dev},
      {:live_isolated_component,
       git: "https://github.com/Serabe/live_isolated_component", ref: "886277a", only: :test},
      {:logster, "~> 1.1"},
      {:map_diff, "~> 1.3.4"},
      {:mbta_v3_api, git: "https://github.com/mbta/mbta_v3_api.git", branch: "main"},
      # Mock needs a newer version of meck to compile in erlang 29
      {:meck, "~> 1.2.0", only: :test, override: true},
      {:mock, "~> 0.3.9", only: :test},
      {:nimble_csv, "~> 1.3.0"},
      {:oban, "~> 2.16"},
      {:oban_web, "~> 2.11"},
      {:paper_trail, "~> 1.1.2"},
      {:phoenix, "~> 1.8.6"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:phoenix_live_dashboard, "~> 0.9.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.9"},
      {:phoenix_swagger, "~> 0.8"},
      {:plug_cowboy, "~> 2.7"},
      {:postgrex, ">= 0.0.0"},
      {:protox, "~> 2.0"},
      {:req, "~> 0.7.2"},
      {:sentry, "~> 13.0"},
      {:sftp_client, "~> 2.1"},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.4.0", only: :test},
      {:tailwind, "~> 0.5.1", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:unrooted_polytree, "~> 0.1.0"},
      {:tzdata, "~> 1.1"},
      {:ueberauth, "~> 0.10"},
      {:ueberauth_oidcc, "~> 0.4"}
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
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
      sobelow:
        "sobelow --skip --exit=low --ignore Config.HTTPS --ignore-files lib/alerts_ui/ibi_alert_importer.ex",
      check: [
        "compile --force --all-warnings --warnings-as-errors",
        "format",
        "credo --strict",
        "sobelow",
        "dialyzer"
      ]
    ]
  end

  def cli do
    [preferred_cli_env: ["ecto.test_setup": :test]]
  end
end
