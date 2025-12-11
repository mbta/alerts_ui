defmodule AlertsUI.Repo.Migrations.AddImageFieldsToIbiAlerts do
  use Ecto.Migration

  def change do
    alter table(:ibi_alerts) do
      add :alert_image_url, :text
      add :alert_image_description, :text
    end
  end
end
