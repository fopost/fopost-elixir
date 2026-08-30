defmodule FoPost.Analytics.Overview do
  @moduledoc """
  The headline roll-up across every account in scope.

  `:deltas` are period-over-period changes as fractions; a dimension with no earlier
  period to compare against is absent.
  """

  alias FoPost.Model

  defstruct [
    :total_accounts,
    :total_followers,
    :total_posts,
    :total_engagement,
    :total_impressions,
    :total_reach,
    :total_likes,
    :total_comments,
    :total_shares,
    :total_reposts,
    :total_saves,
    :total_clicks,
    :total_video_views,
    :total_profile_views,
    :engagement_rate,
    :deltas,
    :today_stats,
    :raw,
    platforms: [],
    accounts: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      total_accounts: fields["total_accounts"],
      total_followers: fields["total_followers"],
      total_posts: fields["total_posts"],
      total_engagement: fields["total_engagement"],
      total_impressions: fields["total_impressions"],
      total_reach: fields["total_reach"],
      total_likes: fields["total_likes"],
      total_comments: fields["total_comments"],
      total_shares: fields["total_shares"],
      total_reposts: fields["total_reposts"],
      total_saves: fields["total_saves"],
      total_clicks: fields["total_clicks"],
      total_video_views: fields["total_video_views"],
      total_profile_views: fields["total_profile_views"],
      engagement_rate: fields["engagement_rate"],
      deltas: Model.normalize(fields["deltas"]),
      today_stats: Model.normalize(fields["today_stats"]),
      platforms: Model.maps(fields["platforms"]),
      accounts: Model.maps(fields["accounts"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.Point do
  @moduledoc """
  One day of activity in a time series.
  """

  alias FoPost.Model

  defstruct [
    :date,
    :engagements,
    :impressions,
    :likes,
    :comments,
    :shares,
    :followers,
    :posts,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      date: fields["date"],
      engagements: fields["engagements"],
      impressions: fields["impressions"],
      likes: fields["likes"],
      comments: fields["comments"],
      shares: fields["shares"],
      followers: fields["followers"],
      posts: fields["posts"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.TimeSeries do
  @moduledoc """
  Daily activity over the requested window, one point per day.
  """

  alias FoPost.Analytics.Point
  alias FoPost.Model

  defstruct [:days, :raw, series: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      days: fields["days"],
      series: Model.list(Point, fields["series"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.TopPost do
  @moduledoc """
  One high-performing post.

  `:source` is `"fopost"` for a post published from here, or `"platform"` for one found on
  the account.
  """

  alias FoPost.Label
  alias FoPost.Model

  defstruct [
    :rank,
    :post_id,
    :external_post_id,
    :source,
    :preview,
    :permalink,
    :thumbnail_url,
    :status,
    :metrics,
    :created_at,
    :raw,
    platforms: [],
    labels: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      rank: fields["rank"],
      post_id: fields["post_id"],
      external_post_id: fields["external_post_id"],
      source: fields["source"],
      preview: fields["preview"],
      permalink: fields["permalink"],
      thumbnail_url: fields["thumbnail_url"],
      status: fields["status"],
      metrics: Model.normalize(fields["metrics"]),
      platforms: Model.maps(fields["platforms"]),
      labels: Model.list(Label, fields["labels"]),
      created_at: Model.datetime(fields["created_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.LabelStats do
  @moduledoc """
  One campaign label's performance over the window.
  """

  alias FoPost.Model

  defstruct [
    :label_id,
    :name,
    :color,
    :post_count,
    :impressions,
    :reach,
    :engagements,
    :likes,
    :comments,
    :shares,
    :engagement_rate,
    :follower_delta,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      label_id: fields["label_id"],
      name: fields["name"],
      color: fields["color"],
      post_count: fields["post_count"],
      impressions: fields["impressions"],
      reach: fields["reach"],
      engagements: fields["engagements"],
      likes: fields["likes"],
      comments: fields["comments"],
      shares: fields["shares"],
      engagement_rate: fields["engagement_rate"],
      follower_delta: fields["follower_delta"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.PostRow do
  @moduledoc """
  One row of the posts table: a post and how its deliveries went.
  """

  alias FoPost.Model

  defstruct [
    :post_id,
    :preview,
    :status,
    :created_at,
    :scheduled_at,
    :delivery_summary,
    :raw,
    platforms: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      post_id: fields["post_id"],
      preview: fields["preview"],
      status: fields["status"],
      created_at: Model.datetime(fields["created_at"]),
      scheduled_at: Model.datetime(fields["scheduled_at"]),
      platforms: Model.maps(fields["platforms"]),
      delivery_summary: Model.normalize(fields["delivery_summary"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.PostsTable do
  @moduledoc """
  A page of posts with their per-platform delivery breakdown.
  """

  alias FoPost.Analytics.PostRow
  alias FoPost.Model

  defstruct [:total, :page, :limit, :status_summary, :raw, posts: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      posts: Model.list(PostRow, fields["posts"]),
      total: fields["total"],
      page: fields["page"],
      limit: fields["limit"],
      status_summary: Model.normalize(fields["status_summary"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.StreakDay do
  @moduledoc """
  One day of posting activity in the year-long streak.
  """

  alias FoPost.Model

  defstruct [:date, :count, :published_count, :failed_count, :scheduled_count, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      date: fields["date"],
      count: fields["count"],
      published_count: fields["published_count"],
      failed_count: fields["failed_count"],
      scheduled_count: fields["scheduled_count"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.Bucket do
  @moduledoc """
  One slice of an audience: a value and its share of the whole.
  """

  alias FoPost.Model

  defstruct [:key, :value, :share, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      key: fields["key"],
      value: fields["value"],
      share: fields["share"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.Demographics do
  @moduledoc """
  An audience breakdown.

  `:dimensions` maps `"age"`, `"gender"`, `"country"`, and `"city"` onto lists of
  `FoPost.Analytics.Bucket`. `:unsupported_accounts` names the accounts whose platform
  does not report demographics at all.
  """

  alias FoPost.Analytics.Bucket
  alias FoPost.Model

  defstruct [
    :audience,
    :raw,
    dimensions: %{},
    contributing_accounts: [],
    unsupported_accounts: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      audience: fields["audience"],
      dimensions: dimensions(fields["dimensions"]),
      contributing_accounts: Model.maps(fields["contributing_accounts"]),
      unsupported_accounts: Model.maps(fields["unsupported_accounts"]),
      raw: data
    }
  end

  def from_map(_data), do: nil

  defp dimensions(data) when is_map(data) do
    data
    |> Model.normalize()
    |> Map.new(fn {key, value} -> {key, Model.list(Bucket, value)} end)
  end

  defp dimensions(_data), do: %{}
end

defmodule FoPost.Analytics.CollectSummary do
  @moduledoc """
  What a collection run refreshed, and what it could not.
  """

  alias FoPost.Model

  defstruct [:accounts, :posts, :demographics, :errors, :raw, error_details: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      accounts: fields["accounts"],
      posts: fields["posts"],
      demographics: fields["demographics"],
      errors: fields["errors"],
      error_details: Model.maps(fields["error_details"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
