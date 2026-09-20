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

defmodule FoPost.Analytics.DecayBand do
  @moduledoc """
  One age band of the content decay report.

  `:share_of_final` is `nil` when nothing in the band had earned anything yet, which is
  not the same as zero.
  """

  alias FoPost.Model

  defstruct [
    :bucket,
    :label,
    :posts,
    :avg_engagements,
    :avg_impressions,
    :share_of_final,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      bucket: fields["bucket"],
      label: fields["label"],
      posts: fields["posts"],
      avg_engagements: fields["avg_engagements"],
      avg_impressions: fields["avg_impressions"],
      share_of_final: fields["share_of_final"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.ContentDecay do
  @moduledoc """
  How engagement accumulates as a post ages.

  `:half_life_bucket` names the first band where the average post had passed half its
  final engagement.
  """

  alias FoPost.Analytics.DecayBand
  alias FoPost.Model

  defstruct [:days, :posts_measured, :half_life_bucket, :raw, bands: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      days: fields["days"],
      posts_measured: fields["posts_measured"],
      half_life_bucket: fields["half_life_bucket"],
      bands: Model.list(DecayBand, fields["bands"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.FrequencyWeek do
  @moduledoc """
  One week of posting. `:week_start` is the Monday, UTC, as `YYYY-MM-DD`.
  """

  alias FoPost.Model

  defstruct [:week_start, :posts, :engagements, :avg_engagements_per_post, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      week_start: fields["week_start"],
      posts: fields["posts"],
      engagements: fields["engagements"],
      avg_engagements_per_post: fields["avg_engagements_per_post"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.FrequencyBand do
  @moduledoc """
  The weeks that shared a cadence, folded together.

  `:engagement_rate` is engagements over reach, impressions as the stand-in, and `nil`
  with neither.
  """

  alias FoPost.Model

  defstruct [
    :band,
    :label,
    :weeks,
    :posts,
    :avg_posts_per_week,
    :avg_engagements_per_post,
    :engagement_rate,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      band: fields["band"],
      label: fields["label"],
      weeks: fields["weeks"],
      posts: fields["posts"],
      avg_posts_per_week: fields["avg_posts_per_week"],
      avg_engagements_per_post: fields["avg_engagements_per_post"],
      engagement_rate: fields["engagement_rate"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.PostingFrequency do
  @moduledoc """
  Weekly cadence set against what each cadence earned per post.

  `:best` is the cadence that earned the most per post, and is `nil` without posts.
  """

  alias FoPost.Analytics.FrequencyBand
  alias FoPost.Analytics.FrequencyWeek
  alias FoPost.Model

  defstruct [:days, :best, :raw, weeks: [], bands: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      days: fields["days"],
      weeks: Model.list(FrequencyWeek, fields["weeks"]),
      bands: Model.list(FrequencyBand, fields["bands"]),
      best: FrequencyBand.from_map(fields["best"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.TimelineDelta do
  @moduledoc """
  What moved between one reading and the one before it.
  """

  alias FoPost.Model

  defstruct [:impressions, :reach, :engagements, :likes, :comments, :shares, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      impressions: fields["impressions"],
      reach: fields["reach"],
      engagements: fields["engagements"],
      likes: fields["likes"],
      comments: fields["comments"],
      shares: fields["shares"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.TimelinePoint do
  @moduledoc """
  One reading of a post. `:age_minutes` is `nil` when the network never said when the
  post went out.
  """

  alias FoPost.Analytics.TimelineDelta
  alias FoPost.Model

  defstruct [
    :at,
    :age_minutes,
    :impressions,
    :reach,
    :engagements,
    :likes,
    :comments,
    :shares,
    :video_views,
    :delta,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      at: Model.datetime(fields["at"]),
      age_minutes: fields["age_minutes"],
      impressions: fields["impressions"],
      reach: fields["reach"],
      engagements: fields["engagements"],
      likes: fields["likes"],
      comments: fields["comments"],
      shares: fields["shares"],
      video_views: fields["video_views"],
      delta: TimelineDelta.from_map(fields["delta"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.TimelineDelivery do
  @moduledoc """
  One delivery's readings: the same post on two networks decays differently.
  """

  alias FoPost.Analytics.TimelinePoint
  alias FoPost.Model

  defstruct [
    :account_id,
    :platform,
    :username,
    :external_post_id,
    :posted_at,
    :raw,
    points: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      account_id: fields["account_id"],
      platform: fields["platform"],
      username: fields["username"],
      external_post_id: fields["external_post_id"],
      posted_at: Model.datetime(fields["posted_at"]),
      points: Model.list(TimelinePoint, fields["points"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.PostTimeline do
  @moduledoc """
  Every reading held for one post, one timeline per delivery.

  `:post_id` is `nil` when the post was made natively on the network.
  """

  alias FoPost.Analytics.TimelineDelivery
  alias FoPost.Model

  defstruct [:post_id, :raw, deliveries: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      post_id: fields["post_id"],
      deliveries: Model.list(TimelineDelivery, fields["deliveries"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.MetricChange do
  @moduledoc """
  One reading, as the changes feed reports it. `:post_id` is `nil` for a post made
  natively on the network.
  """

  alias FoPost.Model

  defstruct [
    :account_id,
    :platform,
    :external_post_id,
    :post_id,
    :posted_at,
    :fetched_at,
    :impressions,
    :reach,
    :engagements,
    :likes,
    :comments,
    :shares,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      account_id: fields["account_id"],
      platform: fields["platform"],
      external_post_id: fields["external_post_id"],
      post_id: fields["post_id"],
      posted_at: Model.datetime(fields["posted_at"]),
      fetched_at: Model.datetime(fields["fetched_at"]),
      impressions: fields["impressions"],
      reach: fields["reach"],
      engagements: fields["engagements"],
      likes: fields["likes"],
      comments: fields["comments"],
      shares: fields["shares"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.MetricChangePage do
  @moduledoc """
  One page of readings. Feed `:cursor` back as the next `:since`; it is `nil` when
  nothing changed.
  """

  alias FoPost.Analytics.MetricChange
  alias FoPost.Model

  defstruct [:since, :cursor, :has_more, :raw, changes: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      since: Model.datetime(fields["since"]),
      cursor: Model.datetime(fields["cursor"]),
      has_more: fields["has_more"],
      changes: Model.list(MetricChange, fields["changes"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.CollectPostDelivery do
  @moduledoc """
  What the on-demand refresh did for one delivery. `:message` says why it did not happen.
  """

  alias FoPost.Model

  defstruct [
    :account_id,
    :platform,
    :external_post_id,
    :collected,
    :fetched_at,
    :message,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      account_id: fields["account_id"],
      platform: fields["platform"],
      external_post_id: fields["external_post_id"],
      collected: fields["collected"],
      fetched_at: Model.datetime(fields["fetched_at"]),
      message: fields["message"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.CollectPostResult do
  @moduledoc """
  What one post's refresh managed.
  """

  alias FoPost.Analytics.CollectPostDelivery
  alias FoPost.Model

  defstruct [:collected, :raw, deliveries: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      collected: fields["collected"],
      deliveries: Model.list(CollectPostDelivery, fields["deliveries"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Analytics.NativePost do
  @moduledoc """
  A post on the account that never went out through FoPost, with the freshest reading
  held for it under `:metrics`.
  """

  alias FoPost.Model

  defstruct [
    :external_post_id,
    :text,
    :permalink,
    :thumbnail_url,
    :media_type,
    :posted_at,
    :fetched_at,
    :metrics,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      external_post_id: fields["external_post_id"],
      text: fields["text"],
      permalink: fields["permalink"],
      thumbnail_url: fields["thumbnail_url"],
      media_type: fields["media_type"],
      posted_at: Model.datetime(fields["posted_at"]),
      fetched_at: Model.datetime(fields["fetched_at"]),
      metrics: Model.normalize(fields["metrics"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
