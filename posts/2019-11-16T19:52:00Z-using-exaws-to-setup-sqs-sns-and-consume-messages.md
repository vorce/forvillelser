---
%{
  title: "Using ExAws to setup SQS, SNS, and consume messages",
  description: "How to piece together ex_aws libraries for a working application",
  created_at: "2019-11-16T19:52:35.394278Z"
}
---

ExAws is a collection of Elixir libraries to interact with Amazon Web Services.

The [ExAws](https://github.com/ex-aws/ex_aws) documentation is in general very good, but I figured it would be nice to show example code of a concrete solution using a small subset of the functionality. Hopefully you can expand/modify the code to your own needs. I assume the reader is familiar with [Elixir](https://elixir-lang.org) and has some basic [AWS](https://aws.amazon.com/) knowledge.

In this post I will describe how to accomplish the following with Elixir and ExAws:

1. Create a SQS queue
2. Create a subscription to an existing SNS topic
3. Set SNS subscription attributes
4. Consume messages from the SQS queue

The presented code will be functioning but of prototype nature. That means tests, error handling and refactoring opportunities are left to the reader as an exercise ;-)

## Setup

First we need to add the ex_aws dependencies to our project:

In `mix.exs`:

```elixir
defp deps do
  [
    {:ex_aws, "~> 2.1"},
    {:ex_aws_sqs, "~> 3.0"},
    {:ex_aws_sns, "~> 2.0"},
    {:sweet_xml, "~> 0.6"}
  ]
end
```

## Create a SQS queue

This is fairly straight forward with [`ExAws.SQS.create_queue/2`](https://hexdocs.pm/ex_aws_sqs/ExAws.SQS.html#create_queue/2). Let's start with a fresh module to hold our functions that we will expand on as we go along.

```elixir
defmodule ExAwsExample do
  @moduledoc "Collection of functions demonstrating how to use ExAws.SQS and ExAws.SNS"

  alias ExAws.SQS

  def create_queue(queue_name, opts \\ []) do
    queue_name
    |> SQS.create_queue(opts)
    |> ExAws.request()
  end
end
```

`queue_name` is just a string, `opts` is an optional keyword list containing any extra options you might need (outlined [here](https://hexdocs.pm/ex_aws_sqs/ExAws.SQS.html#t:queue_attributes/0)) - leave it out completely or set it to the empty list (`[]`) if you don't need any attributes.

## Create a subscription to an existing SNS topic

To create a subscription we need to use [`ExAws.SNS.subscribe/3`](https://hexdocs.pm/ex_aws_sns/ExAws.SNS.html#subscribe/3). Since you can subscribe different things to a SNS topic, it’s not as self explanatory how to use it. You can get the `topic_arn` from the AWS console, this identifies the SNS topic you want to get messages from. It's not immediately clear what values we can use for the `protocol` parameter, looking at the AWS console we can see the following options:

<INSERT SCREENSHOT>

So far I know these values work: `"email"`, `"http"`, `"https"`, `"email"`, and `"sqs"` - in this example we will use `"sqs"`. The third
parameter to the `subscribe` function is a string called `endpoint`, this is where the message from the topic will go. In our SQS case this will be the ARN of the SQS queue we want the messages from the SNS topic to end up in. How do we get the ARN of the queue then? Ideally it would be returned in the response from the `create_queue` call, but it's not. We do get the queue URL back from that call though and we can transform it to the ARN.

With our new knowledge let's add a new alias and two functions to our module.

```elixir
alias ExAws.SNS

def create_sqs_subscription(topic_arn, queue_url) do
  queue_arn = queue_url_to_arn(queue_url)

  topic_arn
  |> SNS.subscribe("sqs", queue_arn)
  |> ExAws.request()
end

defp queue_url_to_arn(queue_url) do
  [_protocol, "", host, account_id, queue_name] = String.split(url, "/")
  [service, region, _, _] = String.split(host, ".")

  "arn:aws:#{service}:#{region}:#{account_id}:#{queue_name}"
end
```

Here's how to use our two functions to create a queue, and then set up a subscription:

```elixir
{:ok, %{body: %{queue_url: queue_url}}} = ExAwsExample.create_queue("my-great-queue")
{:ok, _} = ExAwsExample.create_sqs_subscription(my_topic_arn, queue_url)
```

After running this code you should see a queue in the SQS console called “my-great-queue”, and a subscription for it in the SNS console. At this point you might expect that you can publish messages to the topic and they end up in the queue - but not so fast.

### Permissions

We need to make sure that we give permission to the topic to publish to our queue. You can do this in the AWS SQS console - in fact it will automatically add the correct permissions if you manually add a subscription to a SNS topic. You can of course also accomplish the same thing with code which is handy. We have to add a `policy` option in the `create_queue` call. A policy is just a json document, more details in the [AWS docs](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-creating-custom-policies.html). The policy below will grant the topic permission to send messages to our particular queue.

```elixir
def queue_policy(region, account_id, queue_name, topic_arn) do
  ~s"""
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "*"
        },
        "Action": [
          "sqs:SendMessage"
        ],
        "Resource": "arn:aws:sqs:#{region}:#{account_id}:#{queue_name}",
        "Condition": {
          "ArnEquals": {
            "aws:SourceArn": "#{topic_arn}"
          }
        }
      }
    ]
  }
  """
end
```

The create_queue call now looks like this:

```elixir
my_policy = ExAwsExample.queue_policy("eu-west-1", "123456778900", "my-great-queue", my_topic_arn)
ExAwsExample.create_queue("my-great-queue", policy: my_policy)
...
```

You can now verify that messages end up in the queue by manually publishing something to the SNS topic in the AWS web console.

## Set SNS subscription attributes

A very useful attribute we can set when the subscription protocol is "sqs" is "RawMessageDelivery", this attribute will skip the metadata/envelope around the actual contents of the message. We definitely want this on our subscription. To make it happen we need to use `SNS.set_subscription_attributes/3`.

In some cases you only want to forward a subset of the messages that flows to the SNS topic to the queue. To accomplish that we need to apply a filter policy to the subscription.

Ok, so we have two propertiers we need to set on the SNS subscription -- time for another function:

```elixir
def set_subscription_attributes(subscription_arn, opts \\ []) do
  filter = Keyword.get(opts, :filter, "{}") # default to an empy filter json document
  raw_message_delivery = Keyword.get(opts, :raw_message_delivery, "true")

  "FilterPolicy"
  |> SNS.set_subscription_attributes(filter, subscription_arn)
  |> ExAws.request()

  "RawMessageDelivery"
  |> SNS.set_subscription_attributes(raw_message_delivery, subscription_arn)
  |> ExAws.request()
end
```

The subscription_arn is conveniently returned in the response from the `subscribe` function. How the filter option look depend on the messages you expect, but here’s an example:

```elixir
@filter_policy ~s"""
{
  "Source": ["MySystemX"],
  "PayloadType": ["user_event"],
  "PayloadVersion": [{"numeric": ["=", 1]}]
}
"""
```

## Consume messages from the SQS queue

Now that we have building blocks for setting up our infrastructure we can build the consumer for the queue that will get and process the messages that comes in. We want the message consumer to continuously poll the SQS queue, so let's create a worker and add it to our supervision tree.

### Consumer GenServer

We need a new module that will contain our queue consumer functionality.

```elixir
defmodule ExAwsExample.SQSConsumer do
  @moduledoc """
  Consumes messages from a SQS queue
  """
  alias ExAws.SQS

  require Logger

  use GenServer

  @queue_name "my-great-queue"
  @topic_arn "arn:aws:sns:eu-west-1:123456789000:MyAmazingTopic"

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    Logger.debug("Setting up queue #{@queue_name} and subscription to topic #{@topic_arn}")

    policy = ExAwsExample.queue_policy("eu-west-1", "123456789000", @queue_name, @topic_arn)
    {:ok, %{body: %{queue_url: queue_url}}} = ExAwsExample.create_queue(@queue_name, policy: policy)

    subscription_opts = [filter: @subscription_filter_policy, raw_message_delivery: "true"]
    {:ok, _} = ExAwsExample.create_sqs_subscription(@topic_arn, queue_url, subscription_opts)

    schedule_check()

    {:ok, %{queue_name: @queue_name, last_message_time: nil}}
  end

  def schedule_check(check_interval \\ 1_000) do
    Process.send_after(self(), :get_messages, check_interval)
  end

  def handle_messages() do
    case get_messages(@queue_name, wait_time_seconds: 5, max_number_of_messages: 10) do
      {:ok, []} ->
        :ok

      {:ok, messages} ->
        Logger.info("Received #{length(messages)} messages from queue #{@queue_name}, processing them...")
        process_messages(message)

      {:error, _} = unexpected ->
        Logger.error("Could not get messages from queue #{@queue_name}, reason: #{inspect(unexpected)}")
    end
  end

  defp get_messages(queue_name, opts) do
    queue_name
    |> SQS.receive_message(opts)
    |> ExAws.request()

    with {:ok, %{body: %{messages: messages}}} <- result, do: {:ok, messages}
  end

  def process_messages(messages) do
    Enum.each(messages, fn message ->
      Logger.info("Handling message: #{inspect(message)}")
      # do interesting stuff here
    end)
  end

  @impl GenServer
  def handle_info(:get_messages, state) do
    handle_messages()
    schedule_check()

    {:noreply, state}
  end
end
```

We are missing one thing though. After we are done with the message we should remove it so that no other consumer will also process it.

```elixir
def delete_message(queue, receipt) do
  queue
  |> SQS.delete_message(receipt)
  |> ExAws.request()
end
```

The `receipt` is an identifier for the message, contained in the message itself. Let's call `delete_message/2` after `process_messages/1`:

```elixir
messages
|> Enum.each(fn %{receipt_handle: receipt_handle} ->
  delete_message(@queue_name, receipt_handle)
end)
```

**Note:** You really want to only delete the message if the processing of it went well. If something goes wrong consider using [deadletter queues](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html).

## Putting it together

We now have most of the pieces we need to have a working application.
Full code and instructions on how to run it here: http://github.com/vorce/ex_aws_example

Happy Elixir hacking!
