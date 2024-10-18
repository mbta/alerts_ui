defmodule AlertsUI.Repo.Migrations.AddRecurrenceDays do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE weekdays AS ENUM ('sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday');"
    )

    alter table("alerts") do
      add :recurrence_days, {:array, :weekdays}
    end
  end
end
