defmodule MeadowWeb.Resolvers.Ingest do
  @moduledoc """
  Absinthe GraphQL query resolver for Ingest Context

  """
  alias Meadow.Config
  alias Meadow.Data.ActionStates
  alias Meadow.Ingest.Bucket
  alias Meadow.Ingest.{Projects, Rows, Sheets, SheetsToWorks}
  alias Meadow.Ingest.Sheets
  alias Meadow.Ingest.Validator
  alias MeadowWeb.Schema.ChangesetErrors

  def projects(_, args, _) do
    {:ok, Projects.list_projects(args)}
  end

  def project(_, %{id: id}, _) do
    {:ok, Projects.get_project!(id)}
  end

  def create_project(_, args, _) do
    case Projects.create_project(args) do
      {:error, changeset} ->
        {:error,
         message: "Could not create project", details: ChangesetErrors.error_details(changeset)}

      {:ok, project} ->
        Config.ingest_bucket()
        |> Bucket.create_project_folder(project.folder)

        {:ok, project}
    end
  end

  def delete_project(_, args, _) do
    project = Projects.get_project!(args[:project_id])

    case Projects.delete_project(project) do
      {:error, changeset} ->
        {
          :error,
          message: "Could not delete project", details: ChangesetErrors.error_details(changeset)
        }

      {:ok, project} ->
        {:ok, project}
    end
  end

  def ingest_sheet(_, %{id: id}, _) do
    {:ok, Sheets.get_ingest_sheet!(id)}
  end

  def approve_ingest_sheet(_, %{id: id}, _) do
    id
    |> Sheets.get_ingest_sheet!()
    |> approve_ingest_sheet()
  end

  def approve_ingest_sheet(%{status: "valid"} = ingest_sheet) do
    case Sheets.update_ingest_sheet_status(ingest_sheet, "approved") do
      {:error, changeset} ->
        {
          :error,
          message: "Could not approve sheet", details: ChangesetErrors.error_details(changeset)
        }

      {:ok, ingest_sheet} ->
        {response, pid} =
          Meadow.Async.run_once("ingest:#{ingest_sheet.id}", fn ->
            ingest_sheet
            |> SheetsToWorks.create_works_from_ingest_sheet()
            |> SheetsToWorks.send_to_pipeline()
          end)

        pid_string = pid |> :erlang.pid_to_list() |> List.to_string()
        {:ok, %{message: to_string(response) <> " : " <> pid_string}}
    end
  end

  def approve_ingest_sheet(%{status: _}) do
    {
      :error,
      message: "Only valid ingest sheets can be approved"
    }
  end

  def ingest_sheet_validation_progress(_, %{id: id}, _) do
    {:ok, Sheets.get_sheet_validation_progress([id]) |> Map.get(id)}
  end

  def ingest_sheet_validations(_, _, _) do
    {:ok, %{validations: [%{id: "sheet", object: %{errors: [], status: "pending"}}]}}
  end

  def validate_ingest_sheet(_, args, _) do
    {response, pid} =
      Meadow.Async.run_once("validate:#{args[:sheet_id]}", fn ->
        args[:sheet_id] |> Validator.result()
      end)

    pid_string = pid |> :erlang.pid_to_list() |> List.to_string()
    {:ok, %{message: to_string(response) <> " : " <> pid_string}}
  end

  def create_ingest_sheet(_, args, _) do
    case Sheets.create_ingest_sheet(args) do
      {:error, changeset} ->
        {:error,
         message: "Could not create ingest sheet",
         details: ChangesetErrors.error_details(changeset)}

      {:ok, ingest_sheet} ->
        {:ok, ingest_sheet}
    end
  end

  @invalid_delete_status ["approved", "completed"]

  def delete_ingest_sheet(%{status: status}) when status in @invalid_delete_status do
    {
      :error,
      message: "Can't delete ingest sheet with status: " <> status
    }
  end

  def delete_ingest_sheet(%{status: _} = ingest_sheet) do
    case Sheets.delete_ingest_sheet(ingest_sheet) do
      {:error, changeset} ->
        {
          :error,
          message: "Could not delete ingest sheet",
          details: ChangesetErrors.error_details(changeset)
        }

      {:ok, ingest_sheet} ->
        {:ok, ingest_sheet}
    end
  end

  def delete_ingest_sheet(_, args, _) do
    args[:sheet_id]
    |> Sheets.get_ingest_sheet!()
    |> delete_ingest_sheet()
  end

  def get_presigned_url(_, _, _) do
    url = Bucket.presigned_s3_url(Config.upload_bucket())
    {:ok, %{url: url}}
  end

  def ingest_sheet_rows(_, args, _) do
    {
      :ok,
      args
      |> Rows.list_ingest_sheet_rows()
    }
  end

  def get_action_states(_, args, _) do
    {:ok,
     args[:object_id]
     |> ActionStates.get_states()
     |> Enum.map(&update_action_doc/1)}
  end

  def ingest_sheet_works(_, %{id: sheet_id}, _) do
    {:ok, sheet_id |> Sheets.list_ingest_sheet_works()}
  end

  def ingest_sheet_errors(_, %{id: sheet_id}, _) do
    {:ok, sheet_id |> Sheets.ingest_errors()}
  end

  defp update_action_doc(state) do
    with mod <- "Elixir.#{state.action}" |> String.to_atom() do
      if Code.ensure_loaded?(mod),
        do: %ActionStates.ActionState{state | action: mod.actiondoc()},
        else: state
    end
  end
end
