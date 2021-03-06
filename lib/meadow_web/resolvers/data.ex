defmodule MeadowWeb.Resolvers.Data do
  @moduledoc """
  Absinthe GraphQL query resolver for Data Context

  """
  alias Meadow.Data.FileSets
  alias Meadow.Data.Works
  alias MeadowWeb.Schema.ChangesetErrors

  def works(_, args, _) do
    {:ok, Works.list_works(args)}
  end

  def work(_, %{id: id}, _) do
    {:ok, Works.get_work!(id)}
  end

  def work(_, %{accession_number: accession_number}, _) do
    {:ok, Works.get_work_by_accession_number!(accession_number)}
  end

  def create_work(_, args, _) do
    case Works.create_work(args) do
      {:error, changeset} ->
        {:error,
         message: "Could not create work", details: ChangesetErrors.error_details(changeset)}

      {:ok, work} ->
        {:ok, work}
    end
  end

  def create_file_set(_, args, _) do
    case FileSets.create_file_set(args) do
      {:error, changeset} ->
        {:error,
         message: "Could not create file set", details: ChangesetErrors.error_details(changeset)}

      {:ok, file_set} ->
        {:ok, file_set}
    end
  end

  def delete_work(_, args, _) do
    work = Works.get_work!(args[:work_id])

    case Works.delete_work(work) do
      {:error, changeset} ->
        {
          :error,
          message: "Could not delete work", details: ChangesetErrors.error_details(changeset)
        }

      {:ok, work} ->
        {:ok, work}
    end
  end

  def file_sets(_, _args, _) do
    {:ok, FileSets.list_file_sets()}
  end

  def file_set(_, %{id: id}, _) do
    {:ok, FileSets.get_file_set!(id)}
  end

  def file_set(_, %{accession_number: accession_number}, _) do
    {:ok, FileSets.get_file_set_by_accession_number!(accession_number)}
  end

  def delete_file_set(_, args, _) do
    file_set = FileSets.get_file_set!(args[:file_set_id])

    case FileSets.delete_file_set(file_set) do
      {:error, changeset} ->
        {
          :error,
          message: "Could not delete file_set", details: ChangesetErrors.error_details(changeset)
        }

      {:ok, file_set} ->
        {:ok, file_set}
    end
  end
end
