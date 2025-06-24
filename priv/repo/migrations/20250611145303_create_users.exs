defmodule AlertsUI.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    execute("CREATE TYPE roles AS ENUM ('user', 'admin');")

    create table(:users) do
      add :email, :string
      add :keycloak_id, :string
      add :first_name, :string
      add :last_name, :string
      add :role, :roles

      timestamps()
    end
  end
end
