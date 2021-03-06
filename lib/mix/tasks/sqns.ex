defmodule Mix.Tasks.Meadow.Pipeline.Setup do
  @moduledoc "Creates resources for the ingest pipeline"
  alias Meadow.Pipeline
  use Mix.Task

  @shortdoc @moduledoc
  def run(_) do
    [:ex_aws, :hackney] |> Enum.each(&Application.ensure_all_started/1)
    Pipeline.queue_config() |> Sequins.setup()
  end
end
