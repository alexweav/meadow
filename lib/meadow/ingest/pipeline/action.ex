defmodule Meadow.Ingest.Pipeline.Action do
  @moduledoc ~S"""
  `Pipeline.Action` wraps a [`Broadway SQS`](https://hexdocs.pm/broadway/amazon-sqs.html)
  processing pipeline to allow for the simple creation of multi-stage `SQS -> Broadway -> SNS`
  pipelines.

  ## Getting Started

  First, follow the [Create a SQS queue](https://hexdocs.pm/broadway/amazon-sqs.html#create-a-sqs-queue)
  and [Configure the project](https://hexdocs.pm/broadway/amazon-sqs.html#configure-the-project)
  sections of the Broadway Amazon SQS guide.

  Also make sure `config.exs` contains a valid [`ExAws`](https://hexdocs.pm/ex_aws/) configuration.

  ## Implement the processing callback

  This is where we depart from Broadway's default implementation. Pipeline.Action makes several
  opinionated assumptions about the AWS environment as well as the shape of the incoming
  message data.

  ### Processor

  `Pipeline.Action` assumes that all message data is JSON, deserializing it before `process`
  and serializing it again on the way out. Instead of implementing `handle_message/3`,
  we're just going to implement our own `process/1`:

      defmodule MyApplication.MyPipeline do
        use Pipeline.Action, queue_name: "my-pipeline"

        def process(data) do
          data
          |> Map.get_and_update!(:value, fn n -> n * n end)
        end
      end

  ### Batcher

  `Pipeline.Action` sends processed data to an [AWS Simple Notification Service](https://aws.amazon.com/sns/)
  topic, allowing it to be dispatched to another queue (and into another `Pipeline.Action`),
  an AWS Lambda, an arbitrary webhook, or even an email or SMS message.

  ## Configuration Options

  `Pipeline.Action` attempts to use sane defaults, inheriting most of them from `Broadway` itself.
  However, several can be overriden in the application configuration.

  ### Options

  `Pipeline.Action` is configured by passing options to the `use` macro. The only
  required option is `queue_name`. Valid options are:

    * `:queue_name` - Required. The name of the SQS queue to poll for messages.

    * `:producer_stages` - Optional. The number of producer stages to
      be created by Broadway. Analogous to Broadway's producer `:stages`
      option. Default value is 1.

    * `:processor_stages` - Optional. The number of processor stages to
      be created by Broadway. Analogous to Broadway's producer `:stages`
      option. Default value is 1.

    * `:max_demand` - Optional. Set the maximum demand of all processors
      stages. Analogous to Broadway's processor `:max_demand` option.
      Default value is 10.

    * `:min_demand` - Optional. Set the minimum demand of all processors
      stages. Analogous to Broadway's processor `:min_demand` option.
      Default value is 5.

    * `:batcher_stages` - Optional. The number of batcher stages to
      be created by Broadway. Analogous to Broadway's batcher `:stages`
      option. Default value is 1.

    * `:batch_size` - Optional. The size of generated batches. Analogous to
      Broadway's batcher `:batch_size` option. Default value is `100`.

    * `:batch_timeout` - Optional. The time, in milliseconds, that the
      batcher waits before flushing the list of messages. Analogous to
      Broadway's batcher `:batch_timeout` option. Default value is `1000`.
  """

  use Broadway
  alias Broadway.Message
  require Logger

  @required_topics [:ok, :error]
  @callback process(data :: any()) :: {atom(), any()}

  defmacro __using__(_) do
    quote location: :keep, bind_quoted: [module: __CALLER__.module] do
      @behaviour Meadow.Ingest.Pipeline.Action

      @doc false
      def child_spec(arg) do
        default = %{
          id: unquote(module),
          start: {__MODULE__, :start_link, [arg]},
          shutdown: :infinity
        }

        Supervisor.child_spec(default, [])
      end
    end
  end

  @spec start_link(module :: module(), opts :: keyword()) :: {:ok, pid()}
  def start_link(module, opts) do
    opts = validate_config(opts)

    Broadway.start_link(
      __MODULE__,
      name: module,
      producers: [
        default: [
          module:
            {BroadwaySQS.Producer,
             queue_name: opts.queue_name, receive_interval: opts.receive_interval},
          stages: opts.producer_stages
        ]
      ],
      processors: [
        default: [
          stages: opts.processor_stages,
          min_demand: opts.min_demand,
          max_demand: opts.max_demand
        ]
      ],
      batchers: [
        sns: [
          stages: opts.batcher_stages,
          batch_size: opts.batch_size,
          batch_timeout: opts.batch_timeout
        ]
      ],
      context: %{
        module: module,
        queue_name: opts.queue_name,
        sns_topics: opts.sns_topics
      }
    )
  end

  @impl true
  def handle_message(_, message, context) do
    message
    |> Message.put_batcher(:sns)
    |> Message.update_data(fn data ->
      data
      |> extract_data()
      |> around_process(context)
    end)
  end

  @impl true
  def handle_batch(:sns, messages, _, %{sns_topics: sns_topics}) do
    messages
    |> Enum.each(fn %Message{data: {status, data}} ->
      topic_arn = Map.get(sns_topics, status)
      Logger.debug("Sending #{byte_size(data)} bytes to #{topic_arn}")

      data
      |> ExAws.SNS.publish(topic_arn: topic_arn)
      |> ExAws.request!()
    end)

    messages
  end

  defp extract_data(data) do
    case Jason.decode(data) do
      {:ok, %{"Type" => "Notification", "Message" => d}} -> d
      _ -> data
    end
  rescue
    ArgumentError -> data
  end

  defp around_process(data, %{module: module}) do
    {status, result} =
      data
      |> Jason.decode!()
      |> module.process()

    {status, result |> Jason.encode!()}
  end

  defp ensure_sns_topics(context) do
    context
    |> Map.update!(:sns_topics, fn arns ->
      new_arns =
        Enum.reduce(@required_topics, arns, fn status, result ->
          status |> ensure_sns_topic(result, context)
        end)

      new_arns |> Enum.into(%{})
    end)
  end

  defp ensure_sns_topic(status, arns, context) do
    case arns[status] do
      t when is_binary(t) ->
        arns

      _ ->
        arns
        |> Keyword.put_new(
          status,
          (context[:queue_name]
           |> ExAws.SQS.get_queue_attributes([:queue_arn])
           |> ExAws.request!()
           |> Map.get(:body)
           |> Map.get(:attributes)
           |> Map.get(:queue_arn)
           |> String.replace(":sqs:", ":sns:")) <> "-" <> to_string(status)
        )
    end
  end

  defp validate_config(opts) do
    result =
      case opts |> Broadway.Options.validate(configuration_spec()) do
        {:error, err} ->
          raise %ArgumentError{message: err}

        {:ok, validated} ->
          validated
          |> Enum.into(%{})
          |> ensure_sns_topics()
      end

    case result do
      %{queue_name: queue_name} when not is_binary(queue_name) ->
        {:error, "expected :queue_name to be a binary, got: #{queue_name}"}

      _ ->
        result
    end
  end

  defp configuration_spec do
    [
      sns_topics: [type: :keyword_list, default: []],
      batch_size: [type: :pos_integer, default: 100],
      batch_timeout: [type: :pos_integer, default: 1000],
      batcher_stages: [type: :non_neg_integer, default: 1],
      max_demand: [type: :non_neg_integer, default: 10],
      min_demand: [type: :non_neg_integer, default: 5],
      processor_stages: [type: :non_neg_integer, default: System.schedulers_online() * 2],
      producer_stages: [type: :non_neg_integer, default: 1],
      receive_interval: [type: :non_neg_integer, default: 5000],
      queue_name: [required: true, type: :any]
    ]
  end
end
