defmodule Meadow.Repo.Migrations.ChangeSheetStateToStruct do
  use Ecto.Migration

  def change do
    alter table(:ingest_sheets) do
      remove :state
      add :state, :jsonb
    end
  end
end
