defmodule FoPost.Webhook do
  @moduledoc """
  One webhook subscription.

  `:secret` is only ever returned by `FoPost.Webhooks.create/2`, and only once — it signs
  every delivery, so store it then.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :workspace_id,
    :url,
    :active,
    :secret,
    :last_triggered_at,
    :failure_count,
    :created_at,
    :raw,
    events: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      workspace_id: fields["workspace_id"],
      url: fields["url"],
      active: fields["active"],
      secret: fields["secret"],
      events: List.wrap(fields["events"]),
      last_triggered_at: Model.datetime(fields["last_triggered_at"]),
      failure_count: fields["failure_count"],
      created_at: Model.datetime(fields["created_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.WebhookEvent do
  @moduledoc """
  A decoded webhook delivery: which event fired, its payload, and when.
  """

  alias FoPost.Model

  defstruct [:event, :data, :timestamp, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      event: fields["event"],
      data: fields["data"],
      timestamp: Model.datetime(fields["timestamp"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.WebhookDelivery do
  @moduledoc """
  One attempt to deliver an event to a subscription.

  Every attempt of one event shares `:delivery_key` (the `X-FoPost-Delivery` header);
  `:attempt` counts up through retries and redeliveries. `:payload` is the body exactly
  as it was sent, filled only by `FoPost.Webhooks.delivery/3`.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :webhook_id,
    :event,
    :delivery_key,
    :attempt,
    :status,
    :response_status,
    :response_snippet,
    :duration_ms,
    :payload_hash,
    :next_retry_at,
    :created_at,
    :payload,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      webhook_id: fields["webhook_id"],
      event: fields["event"],
      delivery_key: fields["delivery_key"],
      attempt: fields["attempt"],
      status: fields["status"],
      response_status: fields["response_status"],
      response_snippet: fields["response_snippet"],
      duration_ms: fields["duration_ms"],
      payload_hash: fields["payload_hash"],
      next_retry_at: Model.datetime(fields["next_retry_at"]),
      created_at: Model.datetime(fields["created_at"]),
      payload: fields["payload"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end
