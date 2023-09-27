defmodule AlertsUI.Repo do
  use Ecto.Repo,
    otp_app: :alerts_ui,
    adapter: Ecto.Adapters.Postgres
end
