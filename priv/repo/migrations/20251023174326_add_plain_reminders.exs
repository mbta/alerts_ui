defmodule AlertsUI.Repo.Migrations.AddPlainReminders do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :plaintext_reminder_selections, :string
    end
  end
end
