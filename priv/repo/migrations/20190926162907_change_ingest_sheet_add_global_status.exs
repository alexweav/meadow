defmodule Meadow.Repo.Migrations.ChangeSheetAddGlobalStatus do
  use Ecto.Migration

  def change do
    alter table(:ingest_sheets) do
      add :status, :string
    end
  end
end
