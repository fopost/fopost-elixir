defmodule FoPost.PostAccount do
  @moduledoc """
  One account a post targets, with the outcome of its delivery.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :platform,
    :username,
    :name,
    :avatar,
    :publish_status,
    :posted_at,
    :platform_post_id,
    :external_url,
    :error_code,
    :error_message,
    :attempts,
    :max_attempts,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      platform: fields["platform"],
      username: fields["username"],
      name: fields["name"],
      avatar: fields["avatar"],
      publish_status: fields["publish_status"],
      posted_at: Model.datetime(fields["posted_at"]),
      platform_post_id: fields["platform_post_id"],
      external_url: fields["external_url"],
      error_code: fields["error_code"],
      error_message: fields["error_message"],
      attempts: fields["attempts"],
      max_attempts: fields["max_attempts"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Post do
  @moduledoc """
  A composed post: its content, the accounts it targets, and its schedule.
  """

  alias FoPost.ContentBlock
  alias FoPost.Label
  alias FoPost.Model
  alias FoPost.PostAccount

  defstruct [
    :id,
    :workspace_id,
    :status,
    :content_type,
    :schedule_at,
    :repeatable,
    :repeatable_times,
    :repeatable_gap,
    :repeatable_gap_unit,
    :remaining_posts,
    :title,
    :summary,
    :auto_plug,
    :auto_plug_content,
    :settings,
    :created_at,
    :updated_at,
    :raw,
    content: [],
    accounts: [],
    labels: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      workspace_id: fields["workspace_id"],
      status: fields["status"],
      content_type: fields["content_type"],
      schedule_at: Model.datetime(fields["schedule_at"]),
      repeatable: fields["repeatable"],
      repeatable_times: fields["repeatable_times"],
      repeatable_gap: fields["repeatable_gap"],
      repeatable_gap_unit: fields["repeatable_gap_unit"],
      remaining_posts: fields["remaining_posts"],
      title: fields["title"],
      summary: fields["summary"],
      auto_plug: fields["auto_plug"],
      auto_plug_content: fields["auto_plug_content"],
      settings: fields["settings"],
      content: Model.list(ContentBlock, fields["content"]),
      accounts: Model.list(PostAccount, fields["accounts"]),
      labels: Model.list(Label, fields["labels"]),
      created_at: Model.datetime(fields["created_at"]),
      updated_at: Model.datetime(fields["updated_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Delivery do
  @moduledoc """
  One post-to-account delivery.

  The same struct backs `FoPost.Posts.deliveries/2`, the per-account rows a publish or a
  retry answers with, and the rows inside a `FoPost.PublishRun`. Those three views carry
  overlapping but not identical fields, so a field the endpoint did not report is `nil`.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :account_id,
    :account_name,
    :username,
    :platform,
    :status,
    :error_code,
    :error_message,
    :attempts,
    :max_attempts,
    :attempt_number,
    :scheduled_publish_at,
    :delay_reason,
    :delay_message,
    :posted_at,
    :last_attempt_at,
    :started_at,
    :completed_at,
    :duration_ms,
    :platform_post_id,
    :external_url,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      account_id: fields["account_id"],
      account_name: fields["account_name"],
      username: fields["username"],
      platform: fields["platform"],
      status: fields["status"],
      error_code: fields["error_code"],
      error_message: fields["error_message"],
      attempts: fields["attempts"],
      max_attempts: fields["max_attempts"],
      attempt_number: fields["attempt_number"],
      scheduled_publish_at: Model.datetime(fields["scheduled_publish_at"]),
      delay_reason: fields["delay_reason"],
      delay_message: fields["delay_message"],
      posted_at: Model.datetime(fields["posted_at"]),
      last_attempt_at: Model.datetime(fields["last_attempt_at"]),
      started_at: Model.datetime(fields["started_at"]),
      completed_at: Model.datetime(fields["completed_at"]),
      duration_ms: fields["duration_ms"],
      platform_post_id: fields["platform_post_id"],
      external_url: fields["external_url"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.PublishResult do
  @moduledoc """
  What a publish, a retry, or a cancel queued.

  Publishing answers when delivery is queued, not when the post is live. Poll
  `FoPost.Posts.deliveries/2` or subscribe a webhook to learn the outcome.
  """

  alias FoPost.Delivery
  alias FoPost.Model

  defstruct [:dry_run, :post_status, :post, :raw, deliveries: [], health_warnings: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      dry_run: fields["dry_run"],
      post_status: fields["post_status"],
      post: Model.normalize(fields["post"]),
      deliveries: Model.list(Delivery, fields["deliveries"]),
      health_warnings: Model.maps(fields["health_warnings"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.PreflightAccount do
  @moduledoc """
  One account's readiness. `:issues` block publishing; `:signals` are advisory.
  """

  alias FoPost.Model

  defstruct [:account_id, :platform, :username, :ready, :score, :raw, issues: [], signals: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      account_id: fields["account_id"],
      platform: fields["platform"],
      username: fields["username"],
      ready: fields["ready"],
      score: fields["score"],
      issues: List.wrap(fields["issues"]),
      signals: Model.maps(fields["signals"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.PreflightResult do
  @moduledoc """
  A post checked against every platform it targets, without publishing anything.
  """

  alias FoPost.Model
  alias FoPost.PreflightAccount

  defstruct [:ready, :post, :raw, accounts: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      ready: fields["ready"],
      post: Model.normalize(fields["post"]),
      accounts: Model.list(PreflightAccount, fields["accounts"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.PublishRun do
  @moduledoc """
  One attempt at publishing a post, with its per-account results.
  """

  alias FoPost.Delivery
  alias FoPost.Model

  defstruct [:id, :run_number, :status, :started_at, :completed_at, :raw, deliveries: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      run_number: fields["run_number"],
      status: fields["status"],
      started_at: Model.datetime(fields["started_at"]),
      completed_at: Model.datetime(fields["completed_at"]),
      deliveries: Model.list(Delivery, fields["deliveries"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.PostAnalytics do
  @moduledoc """
  A post's performance, totalled and broken down per platform.
  """

  alias FoPost.Model

  defstruct [:post_id, :totals, :last_fetched_at, :raw, platforms: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      post_id: fields["post_id"],
      totals: Model.normalize(fields["totals"]),
      platforms: Model.maps(fields["platforms"]),
      last_fetched_at: Model.datetime(fields["last_fetched_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Message do
  @moduledoc """
  The bare acknowledgement several deletes and side-effect endpoints answer with.
  """

  alias FoPost.Model

  defstruct [:message, :deleted, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      message: fields["message"],
      deleted: fields["deleted"],
      raw: data
    }
  end

  def from_map(_data), do: %__MODULE__{}
end
