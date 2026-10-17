defmodule FoPost.Analytics do
  @moduledoc """
  Cross-account reporting.

  Every read takes the same window and scope options, and leaves out what you do not
  pass so the API applies its own default:

    * `:workspace_id` — narrow to one workspace
    * `:account_id` — narrow to one account
    * `:days` — a rolling window, or use `:from` and `:to` (both `YYYY-MM-DD`)
    * `:limit`, `:page` — where the endpoint paginates
    * `:sort`, `:label` — where the endpoint ranks or groups

  For example:

      {:ok, overview} = FoPost.Analytics.overview(client, workspace_id: id, days: 30)
      overview.total_followers
  """

  alias FoPost.Analytics.CollectPostResult
  alias FoPost.Analytics.CollectSummary
  alias FoPost.Analytics.ContentDecay
  alias FoPost.Analytics.Demographics
  alias FoPost.Analytics.LabelStats
  alias FoPost.Analytics.MetricChangePage
  alias FoPost.Analytics.NativePost
  alias FoPost.Analytics.Overview
  alias FoPost.Analytics.PostingFrequency
  alias FoPost.Analytics.PostsTable
  alias FoPost.Analytics.PostTimeline
  alias FoPost.Analytics.StreakDay
  alias FoPost.Analytics.TimeSeries
  alias FoPost.Analytics.TopPost
  alias FoPost.Client
  alias FoPost.Model
  alias FoPost.Page
  alias FoPost.Result

  @params [
    {:account_id, "accountId"},
    :workspace_id,
    :days,
    :from,
    :to,
    :limit,
    :sort,
    :label,
    :page,
    {:per_page, "per_page"},
    :since,
    :audience
  ]

  @doc """
  The headline numbers for the window.
  """
  @spec overview(Client.t(), keyword()) :: {:ok, Overview.t()} | {:error, FoPost.Error.t()}
  def overview(client, opts \\ []) do
    with {:ok, data} <- get(client, "/analytics/overview", opts) do
      {:ok, Overview.from_map(data)}
    end
  end

  @doc """
  One point per day in the window.
  """
  @spec time_series(Client.t(), keyword()) :: {:ok, TimeSeries.t()} | {:error, FoPost.Error.t()}
  def time_series(client, opts \\ []) do
    with {:ok, data} <- get(client, "/analytics/time-series", opts) do
      {:ok, TimeSeries.from_map(data)}
    end
  end

  @doc """
  The best performing posts in the window. `sort: "recent"` orders by date instead.
  """
  @spec top_posts(Client.t(), keyword()) :: {:ok, [TopPost.t()]} | {:error, FoPost.Error.t()}
  def top_posts(client, opts \\ []) do
    with {:ok, data} <- get(client, "/analytics/top-posts", opts) do
      {:ok, Model.list(TopPost, data)}
    end
  end

  @doc """
  A per-label campaign roll-up.
  """
  @spec labels(Client.t(), keyword()) :: {:ok, [LabelStats.t()]} | {:error, FoPost.Error.t()}
  def labels(client, opts \\ []) do
    with {:ok, data} <- get(client, "/analytics/labels", opts) do
      {:ok, Model.list(LabelStats, data)}
    end
  end

  @doc """
  Posts with their per-platform delivery breakdown, paginated.
  """
  @spec posts_table(Client.t(), keyword()) :: {:ok, PostsTable.t()} | {:error, FoPost.Error.t()}
  def posts_table(client, opts \\ []) do
    with {:ok, data} <- get(client, "/analytics/posts-table", opts) do
      {:ok, PostsTable.from_map(data)}
    end
  end

  @doc """
  An audience breakdown.

  `:audience` is `"followers"` (the default), `"engaged"`, or `"reached"`.
  """
  @spec demographics(Client.t(), keyword()) ::
          {:ok, Demographics.t()} | {:error, FoPost.Error.t()}
  def demographics(client, opts \\ []) do
    with {:ok, data} <- get(client, "/analytics/demographics", opts) do
      {:ok, Demographics.from_map(data)}
    end
  end

  @doc """
  A year of posting activity, one entry per day.
  """
  @spec posting_streak(Client.t(), keyword()) ::
          {:ok, [StreakDay.t()]} | {:error, FoPost.Error.t()}
  def posting_streak(client, opts \\ []) do
    with {:ok, data} <- get(client, "/analytics/posting-streak", opts) do
      {:ok, Model.list(StreakDay, Model.normalize(data)["streak"])}
    end
  end

  @doc """
  Pulls fresh numbers from the platforms.

  Rate limited harder than the reads, since every call reaches out to a network. Narrow
  it with `:account_id`.
  """
  @spec collect(Client.t(), keyword()) :: {:ok, CollectSummary.t()} | {:error, FoPost.Error.t()}
  def collect(client, opts \\ []) do
    params = Model.take_params(opts, @params)

    with {:ok, data} <- Client.request(client, :post, "/analytics/collect", params: params) do
      {:ok, CollectSummary.from_map(data)}
    end
  end

  @doc """
  How long a post keeps earning.

  Engagement is grouped by the post's age at each reading, so every band says where the
  average post had got to by then and what share of its final engagement that was.
  `:days` selects posts by publish time, not reading time.

      {:ok, decay} = FoPost.Analytics.decay(client, days: 30)
      decay.half_life_bucket
  """
  @spec decay(Client.t(), keyword()) :: {:ok, ContentDecay.t()} | {:error, FoPost.Error.t()}
  def decay(client, opts \\ []) do
    with {:ok, data} <- get(client, "/analytics/decay", opts) do
      {:ok, ContentDecay.from_map(data)}
    end
  end

  @doc """
  Whether posting more earned more.

  Weeks run Monday to Sunday in UTC and are grouped by their own post count, so a
  four-post week is compared against other four-post weeks rather than the average.
  """
  @spec frequency(Client.t(), keyword()) ::
          {:ok, PostingFrequency.t()} | {:error, FoPost.Error.t()}
  def frequency(client, opts \\ []) do
    with {:ok, data} <- get(client, "/analytics/frequency", opts) do
      {:ok, PostingFrequency.from_map(data)}
    end
  end

  @doc """
  Every reading held for one post, oldest first, one timeline per delivery.

  `id_or_permalink` is a FoPost post id, or the permalink of a post made natively on the
  network.
  """
  @spec timeline(Client.t(), String.t()) :: {:ok, PostTimeline.t()} | {:error, FoPost.Error.t()}
  def timeline(client, id_or_permalink) do
    path = "/analytics/posts/#{URI.encode_www_form(id_or_permalink)}/timeline"

    with {:ok, data} <- Client.request(client, :get, path) do
      {:ok, PostTimeline.from_map(data)}
    end
  end

  @doc """
  Readings recorded after `:since`, oldest first, with a cursor to continue.

  Poll it to mirror the metrics into your own store instead of refetching the whole
  history. Leaving `:since` unset asks for the last seven days.
  """
  @spec changes(Client.t(), keyword()) ::
          {:ok, MetricChangePage.t()} | {:error, FoPost.Error.t()}
  def changes(client, opts \\ []) do
    with {:ok, data} <- get(client, "/analytics/changes", opts) do
      {:ok, MetricChangePage.from_map(data)}
    end
  end

  @doc """
  Re-reads one post from the network now.

  Spends the same per-user budget as `collect/2`, so a burst answers 429.
  `id_or_permalink` is a FoPost post id, or the permalink of a post made natively on the
  network.
  """
  @spec collect_post(Client.t(), String.t()) ::
          {:ok, CollectPostResult.t()} | {:error, FoPost.Error.t()}
  def collect_post(client, id_or_permalink) do
    path = "/posts/#{URI.encode_www_form(id_or_permalink)}/analytics/collect"

    with {:ok, data} <- Client.request(client, :post, path) do
      {:ok, CollectPostResult.from_map(data)}
    end
  end

  @doc """
  Posts on the account that never went out through FoPost, newest first.

  Paging: `:page`, `:per_page`. `:days` keeps only posts published recently.
  """
  @spec native_posts(Client.t(), String.t(), keyword()) ::
          {:ok, Page.t()} | {:error, FoPost.Error.t()}
  def native_posts(client, account_id, opts \\ []) do
    params = Model.take_params(opts, @params)
    path = "/accounts/#{account_id}/native-posts"

    with {:ok, data} <- Client.request(client, :get, path, params: params, unwrap: false) do
      {:ok, Page.from_map(data, NativePost)}
    end
  end

  @doc "Same as `overview/2`, but raises `FoPost.Error`."
  def overview!(client, opts \\ []), do: Result.unwrap!(overview(client, opts))

  @doc "Same as `time_series/2`, but raises `FoPost.Error`."
  def time_series!(client, opts \\ []), do: Result.unwrap!(time_series(client, opts))

  @doc "Same as `top_posts/2`, but raises `FoPost.Error`."
  def top_posts!(client, opts \\ []), do: Result.unwrap!(top_posts(client, opts))

  @doc "Same as `labels/2`, but raises `FoPost.Error`."
  def labels!(client, opts \\ []), do: Result.unwrap!(labels(client, opts))

  @doc "Same as `posts_table/2`, but raises `FoPost.Error`."
  def posts_table!(client, opts \\ []), do: Result.unwrap!(posts_table(client, opts))

  @doc "Same as `demographics/2`, but raises `FoPost.Error`."
  def demographics!(client, opts \\ []), do: Result.unwrap!(demographics(client, opts))

  @doc "Same as `posting_streak/2`, but raises `FoPost.Error`."
  def posting_streak!(client, opts \\ []) do
    Result.unwrap!(posting_streak(client, opts))
  end

  @doc "Same as `collect/2`, but raises `FoPost.Error`."
  def collect!(client, opts \\ []), do: Result.unwrap!(collect(client, opts))

  @doc "Same as `decay/2`, but raises `FoPost.Error`."
  def decay!(client, opts \\ []), do: Result.unwrap!(decay(client, opts))

  @doc "Same as `frequency/2`, but raises `FoPost.Error`."
  def frequency!(client, opts \\ []), do: Result.unwrap!(frequency(client, opts))

  @doc "Same as `timeline/2`, but raises `FoPost.Error`."
  def timeline!(client, id_or_permalink) do
    Result.unwrap!(timeline(client, id_or_permalink))
  end

  @doc "Same as `changes/2`, but raises `FoPost.Error`."
  def changes!(client, opts \\ []), do: Result.unwrap!(changes(client, opts))

  @doc "Same as `collect_post/2`, but raises `FoPost.Error`."
  def collect_post!(client, id_or_permalink) do
    Result.unwrap!(collect_post(client, id_or_permalink))
  end

  @doc "Same as `native_posts/3`, but raises `FoPost.Error`."
  def native_posts!(client, account_id, opts \\ []) do
    Result.unwrap!(native_posts(client, account_id, opts))
  end

  defp get(client, path, opts) do
    Client.request(client, :get, path, params: Model.take_params(opts, @params))
  end
end
