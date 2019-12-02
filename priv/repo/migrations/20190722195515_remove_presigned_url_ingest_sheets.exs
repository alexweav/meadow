defmodule Meadow.Repo.Migrations.RemovePresignedUrlSheets do
  use Ecto.Migration

  def change do
    alter table(:ingest_sheets) do
      remove :presigned_url
    end
  end
end
