defmodule AlertsUI.Repo.Migrations.Add1000000ToAlertId do
  use Ecto.Migration

  def change do
    execute("UPDATE ALERTS SET alert_id = alert_id::integer + 1000000")
    # If no alerts exist, the first one should be 1000000, so set the 
    # current value to 999999 if there's nothing higher.
    execute("""
      SELECT SETVAL(
        'alert_id_seq',
        (SELECT GREATEST(MAX(alert_id::integer), 999999) FROM alerts),
        true
      )
    """)
  end
end
