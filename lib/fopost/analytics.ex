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

  alias FoPost.Analytics.CollectSummary
  alias FoPost.Analytics.Demographics
  alias FoPost.Analytics.LabelStats
  alias FoPost.Analytics.Overview
  alias FoPost.Analytics.PostsTable
  alias FoPost.Analytics.StreakDay
  alias FoPost.Analytics.TimeSeries
  alias FoPost.Analytics.TopPost
  alias FoPost.Client
  alias FoPost.Model
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

  defp get(client, path, opts) do
    Client.request(client, :get, path, params: Model.take_params(opts, @params))
  end
end
