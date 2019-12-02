defmodule Meadow.Repo.Migrations.CreateRows do
  use Ecto.Migration

  def change do
    create table(:ingest_sheet_rows, primary_key: false) do
      add :state, :string
      add :errors, :jsonb
      add :fields, :jsonb

      add :sheet_id, references("ingest_sheets", on_delete: :delete_all),
        null: false,
        primary_key: true

      add :row, :integer, null: false, primary_key: true

      timestamps()
    end

    create unique_index(:ingest_sheet_rows, [:sheet_id, :row])
  end
end
