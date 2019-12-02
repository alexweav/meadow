defmodule Meadow.Repo.Migrations.ChangeSheetsFileErrorsToText do
  use Ecto.Migration

  def change do
    alter table(:ingest_sheets) do
      modify :file_errors, {:array, :text}, default: []
    end
  end
end
