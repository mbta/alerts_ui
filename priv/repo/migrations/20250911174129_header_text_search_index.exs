defmodule AlertsUI.Repo.Migrations.HeaderTextSearchIndex do
  use Ecto.Migration

  def change do
    alter table("alerts") do
      add :header_text_index_col, :tsvector,
        generated: "ALWAYS AS (to_tsvector('english', replace(header_text, '/', ' '))) STORED"
    end

    create index("alerts", [:header_text_index_col], name: :header_text_index, using: "GIN")
  end
end
