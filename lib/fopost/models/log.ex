defmodule FoPost.LogEntry do
  @moduledoc """
  One API request the key or a session made, with how it was answered.

  `:route` is the pattern (`/v1/posts/{id}`), `:path` what was actually called.
  `:message` carries the error text of a failed request.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :workspace_id,
    :time,
    :auth_method,
    :method,
    :route,
    :path,
    :status_code,
    :duration_ms,
    :platform,
    :message,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      workspace_id: fields["workspace_id"],
      time: Model.datetime(fields["time"]),
      auth_method: fields["auth_method"],
      method: fields["method"],
      route: fields["route"],
      path: fields["path"],
      status_code: fields["status_code"],
      duration_ms: fields["duration_ms"],
      platform: fields["platform"],
      message: fields["message"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.LogBucket do
  @moduledoc """
  Request and error counts for one interval of the window.
  """

  alias FoPost.Model

  defstruct [:at, :total, :errors, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      at: Model.datetime(fields["at"]),
      total: fields["total"],
      errors: fields["errors"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.LogSummary do
  @moduledoc """
  Totals for the whole window the page was read from, independent of the page.
  """

  alias FoPost.LogBucket
  alias FoPost.Model

  defstruct [:since, :total, :errors, :raw, buckets: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      since: Model.datetime(fields["since"]),
      total: fields["total"],
      errors: fields["errors"],
      buckets: Model.list(LogBucket, fields["buckets"]),
      raw: data
    }
  end

  def from_map(_data), do: %__MODULE__{}
end

defmodule FoPost.LogPage do
  @moduledoc """
  One page of request logs, newest first: the rows on `:data`, the window's totals on
  `:summary`, and the cursor for the next page on `:next_cursor`, `nil` at the end.
  """

  alias FoPost.LogEntry
  alias FoPost.LogSummary
  alias FoPost.Model

  defstruct data: [], next_cursor: nil, has_more: false, summary: %LogSummary{}

  @type t :: %__MODULE__{data: [LogEntry.t()], next_cursor: String.t() | nil}

  @doc false
  def from_map(body) when is_map(body) do
    meta = Model.normalize(Map.get(body, "meta"))

    %__MODULE__{
      data: Model.list(LogEntry, Map.get(body, "data")),
      next_cursor: meta["next_cursor"],
      has_more: meta["has_more"] || false,
      summary: LogSummary.from_map(Map.get(body, "summary"))
    }
  end

  def from_map(_body), do: %__MODULE__{}
end
