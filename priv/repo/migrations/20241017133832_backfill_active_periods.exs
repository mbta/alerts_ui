defmodule AlertsUI.Repo.Migrations.BackfillActivePeriods do
  use Ecto.Migration

  def change do
    execute(
      "INSERT INTO active_period (id, alert_id, \"start\", \"end\", created_at, updated_at)
      SELECT gen_random_uuid(), alerts.id, jsonb_to_record.start, jsonb_to_record.end, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM alerts, unnest(alerts.active_period) AS ap, jsonb_to_record(ap) as (\"start\" timestamp without time zone, \"end\" timestamp without time zone)"
    )

    alter table("alerts") do
      remove :active_period
    end
  end

  def down do
    alter table("alerts") do
      add :active_period, {:array, :integer}
    end

    execute("WITH ap_agg AS (
      select array_agg(json_build_object('start', cast(extract(epoch from \"start\") as integer), 'end', cast(extract(epoch from \"end\") as integer))) as ap
      FROM active_period)
      UPDATE alerts
      SET active_period = ap_agg.ap
      FROM ap_agg, active_period
      where active_period.alert_id = alerts.id;")
  end
end
