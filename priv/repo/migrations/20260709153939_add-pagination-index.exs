defmodule :"Elixir.AlertsUI.Repo.Migrations.AddPaginationIndex" do
  use Ecto.Migration

  @columns [
    :closed_timestamp,
    :draft,
    :effect_name,
    :primary_service_type,
    :notification_period_start,
    :active_period_start,
    :active_period_end
  ]

  @index_name "idx_alerts_paginated"

  def up do
    # try to speed up list_alerts_paginated
    create index(:alerts, @columns, name: @index_name, where: "closed_timestamp IS NULL")
  end

  def down do
    drop index(:alerts, @columns, name: @index_name)
  end
end
