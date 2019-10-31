defmodule Meadow.Ingest.PipelineTest do
  use ExUnit.Case
  alias Meadow.Ingest.Pipeline

  test "child_spec" do
    assert(
      Pipeline.child_spec(test: true).start ==
        {Meadow.Ingest.Pipeline, :start_link, [[test: true]]}
    )
  end

  test "queue_config" do
    assert(is_list(Pipeline.queue_config()))
  end
end
