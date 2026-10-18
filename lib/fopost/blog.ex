defmodule FoPost.Blog do
  @moduledoc """
  Blog articles: the workspace's own website content, planned from keywords,
  written on request and published to a target.

  A post goes to a social network; an article goes to a website. The target is
  set on the settings (`:target_kind`): `"product_blog"`, a connected
  `"account"`, or a `"website"` that receives each published article as a
  signed request (see `FoPost.Webhooks.verify/3`).

  Every function takes the workspace id first; the API scopes each route to it.
  Reads, settings, keyword edits and `submit_article/3` need the `posts` scope;
  `suggest_seeds/3`, `plan_keywords/3`, `request_article/3` and
  `regenerate_article/3` spend AI credits and need `ai`, answering `402` when the
  balance is empty; `publish_article/3` needs `publish`.

  Nothing publishes without approval: a draft is submitted with
  `submit_article/3`, which moves it to `"in_review"`, and only then published
  or scheduled.
  """

  alias FoPost.BlogArticle
  alias FoPost.BlogArticleFull
  alias FoPost.BlogKeyword
  alias FoPost.BlogSettings
  alias FoPost.BlogWebsiteTest
  alias FoPost.Client
  alias FoPost.Model
  alias FoPost.Result

  @workspace {:workspace_id, "workspaceId"}

  @settings_body [
    @workspace,
    {:site_url, "siteUrl"},
    :topic,
    :audience,
    :goal,
    {:focus_topics, "focusTopics"},
    {:avoid_topics, "avoidTopics"},
    :language,
    {:location_code, "locationCode"},
    {:cadence_per_week, "cadencePerWeek"},
    {:review_hold_days, "reviewHoldDays"},
    {:image_tier, "imageTier"},
    {:in_body_images, "inBodyImages"},
    {:min_words, "minWords"},
    {:max_words, "maxWords"},
    {:brand_voice_id, "brandVoiceId"},
    {:target_kind, "targetKind"},
    {:target_account_id, "targetAccountId"},
    {:website_url, "websiteUrl"}
  ]

  @list_params [:status, :limit]
  @keyword_body [@workspace, :keyword, {:planned_for, "plannedFor"}]
  @keyword_update_body [:status, {:planned_for, "plannedFor"}]
  @article_body [@workspace, :title, :keyword, {:keyword_id, "keywordId"}, :instructions]

  @article_update_body [
    :title,
    :slug,
    :excerpt,
    {:meta_title, "metaTitle"},
    {:meta_description, "metaDescription"},
    {:body_markdown, "bodyMarkdown"},
    :tags,
    {:publish_at, "publishAt"}
  ]

  ## Settings

  @doc """
  The workspace's blog settings.
  """
  @spec settings(Client.t(), String.t()) :: {:ok, BlogSettings.t()} | {:error, FoPost.Error.t()}
  def settings(client, workspace_id) do
    with {:ok, data} <-
           Client.request(client, :get, "/blog/settings", params: workspace(workspace_id)) do
      {:ok, BlogSettings.from_map(data)}
    end
  end

  @doc """
  Changes the settings. Every option is optional and a `nil` clears the field.

  Options: `:site_url`, `:topic`, `:audience`, `:goal` (`"traffic"`, `"leads"`,
  `"sales"`, `"signups"` or `"authority"`), `:focus_topics`, `:avoid_topics`,
  `:language`, `:location_code`, `:cadence_per_week` (0 turns planning off),
  `:review_hold_days` (days before its planned date that a picked keyword starts
  being written), `:image_tier`, `:in_body_images`, `:min_words`, `:max_words`,
  `:brand_voice_id`, `:target_kind`, `:target_account_id`, `:website_url`.

  Setting `:website_url` for the first time issues the signing secret, returned
  on `:website_secret` once and never again.
  """
  @spec update_settings(Client.t(), String.t(), keyword()) ::
          {:ok, BlogSettings.t()} | {:error, FoPost.Error.t()}
  def update_settings(client, workspace_id, opts) do
    body = Model.take_body([{:workspace_id, workspace_id} | opts], @settings_body)

    # `website_secret` rides beside the settings, so `from_map/1` picks it up.
    with {:ok, data} <- Client.request(client, :patch, "/blog/settings", json: body) do
      {:ok, BlogSettings.from_map(data)}
    end
  end

  @doc """
  Replaces the website signing secret. The old one stops verifying at once.
  """
  @spec rotate_website_secret(Client.t(), String.t()) ::
          {:ok, String.t()} | {:error, FoPost.Error.t()}
  def rotate_website_secret(client, workspace_id) do
    with {:ok, data} <-
           Client.request(client, :post, "/blog/settings/website-secret",
             json: %{"workspaceId" => workspace_id}
           ) do
      {:ok, Map.get(data, "website_secret")}
    end
  end

  @doc """
  Sends a signed `article.test` request to the website target and reports how
  the site answered. A site that did not answer 2xx comes back as an error
  carrying the same body.
  """
  @spec test_website(Client.t(), String.t()) ::
          {:ok, BlogWebsiteTest.t()} | {:error, FoPost.Error.t()}
  def test_website(client, workspace_id) do
    with {:ok, data} <-
           Client.request(client, :post, "/blog/settings/website-test",
             json: %{"workspaceId" => workspace_id}
           ) do
      {:ok, BlogWebsiteTest.from_map(data)}
    end
  end

  ## Keywords

  @doc """
  The keyword plan.

  Options: `:status` (one of `"suggested"`, `"planned"`, `"written"`,
  `"dismissed"`, or several comma-separated) and `:limit` (up to 500).
  """
  @spec list_keywords(Client.t(), String.t(), keyword()) ::
          {:ok, [BlogKeyword.t()]} | {:error, FoPost.Error.t()}
  def list_keywords(client, workspace_id, opts \\ []) do
    params = workspace(workspace_id) ++ Model.take_params(opts, @list_params)

    with {:ok, data} <- Client.request(client, :get, "/blog/keywords", params: params) do
      {:ok, Model.list(BlogKeyword, data)}
    end
  end

  @doc """
  Suggests about ten search terms from the blog goal and topics, to edit before
  `plan_keywords/3`. Answers the list of terms.

  Options: `:seeds`, the current terms to refine, and `:prompt` (up to 500
  characters) to steer. Needs the `ai` scope.
  """
  @spec suggest_seeds(Client.t(), String.t(), keyword()) ::
          {:ok, [String.t()]} | {:error, FoPost.Error.t()}
  def suggest_seeds(client, workspace_id, opts \\ []) do
    body =
      Model.take_body([{:workspace_id, workspace_id} | opts], [@workspace, :seeds, :prompt])

    with {:ok, data} <- Client.request(client, :post, "/blog/keywords/suggest", json: body) do
      {:ok, List.wrap(Map.get(data, "seeds"))}
    end
  end

  @doc """
  Queues a research run over the search terms. Answers `"queued"`.

  Results land as `"suggested"` keywords and do not fill the calendar; setting a
  keyword's status to `"planned"` picks it, and it takes the next free date.
  Follow the run on the settings' `:plan_run`.

  Options: `:seeds`, the terms to research; derived from the settings when
  omitted. Needs the `ai` scope.
  """
  @spec plan_keywords(Client.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, FoPost.Error.t()}
  def plan_keywords(client, workspace_id, opts \\ []) do
    body = Model.take_body([{:workspace_id, workspace_id} | opts], [@workspace, :seeds])

    with {:ok, data} <- Client.request(client, :post, "/blog/keywords/plan", json: body) do
      {:ok, Map.get(data, "status")}
    end
  end

  @doc """
  Adds a keyword to the plan by hand.

  Required: `:keyword`. Optional: `:planned_for`, a `Date` or `YYYY-MM-DD`.
  """
  @spec add_keyword(Client.t(), String.t(), keyword()) ::
          {:ok, BlogKeyword.t()} | {:error, FoPost.Error.t()}
  def add_keyword(client, workspace_id, opts) do
    body = Model.take_body([{:workspace_id, workspace_id} | opts], @keyword_body)

    with {:ok, data} <- Client.request(client, :post, "/blog/keywords", json: body) do
      {:ok, BlogKeyword.from_map(data)}
    end
  end

  @doc """
  Changes a keyword's `:status` or `:planned_for` (`nil` takes it off the calendar).
  Setting `:status` to `"planned"` picks the keyword for the next free date.
  """
  @spec update_keyword(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, BlogKeyword.t()} | {:error, FoPost.Error.t()}
  def update_keyword(client, workspace_id, id, opts) do
    body = Model.take_body(opts, @keyword_update_body)

    with {:ok, data} <-
           Client.request(client, :patch, keyword_path(id),
             params: workspace(workspace_id),
             json: body
           ) do
      {:ok, BlogKeyword.from_map(data)}
    end
  end

  @doc """
  Removes a keyword from the plan.
  """
  @spec delete_keyword(Client.t(), String.t(), String.t()) ::
          {:ok, term()} | {:error, FoPost.Error.t()}
  def delete_keyword(client, workspace_id, id) do
    Client.request(client, :delete, keyword_path(id), params: workspace(workspace_id))
  end

  ## Articles

  @doc """
  Articles, newest first, without their bodies.

  Options: `:status` (one or several comma-separated) and `:limit` (up to 200).
  """
  @spec list_articles(Client.t(), String.t(), keyword()) ::
          {:ok, [BlogArticle.t()]} | {:error, FoPost.Error.t()}
  def list_articles(client, workspace_id, opts \\ []) do
    params = workspace(workspace_id) ++ Model.take_params(opts, @list_params)

    with {:ok, data} <- Client.request(client, :get, "/blog/articles", params: params) do
      {:ok, Model.list(BlogArticle, data)}
    end
  end

  @doc """
  Queues an article to be written. It comes back `"queued"`; poll
  `get_article/3` for the draft.

  One of `:title`, `:keyword` or `:keyword_id` (a keyword from the plan) is
  required. Optional: `:instructions`. Needs the `ai` scope.
  """
  @spec request_article(Client.t(), String.t(), keyword()) ::
          {:ok, BlogArticle.t()} | {:error, FoPost.Error.t()}
  def request_article(client, workspace_id, opts) do
    body = Model.take_body([{:workspace_id, workspace_id} | opts], @article_body)

    with {:ok, data} <- Client.request(client, :post, "/blog/articles", json: body) do
      {:ok, BlogArticle.from_map(data)}
    end
  end

  @doc """
  One article with its body, outline, brief and images.
  """
  @spec get_article(Client.t(), String.t(), String.t()) ::
          {:ok, BlogArticleFull.t()} | {:error, FoPost.Error.t()}
  def get_article(client, workspace_id, id) do
    with {:ok, data} <-
           Client.request(client, :get, article_path(id), params: workspace(workspace_id)) do
      {:ok, BlogArticleFull.from_map(data)}
    end
  end

  @doc """
  Edits a draft or scheduled article. Any other state answers `409`.

  Options: `:title`, `:slug`, `:excerpt`, `:meta_title`, `:meta_description`,
  `:body_markdown`, `:tags`, `:publish_at` (puts an article in review on the
  calendar; `nil` returns it to review). A `:publish_at` on a draft answers
  `409` until it is submitted with `submit_article/3`.
  """
  @spec update_article(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, BlogArticleFull.t()} | {:error, FoPost.Error.t()}
  def update_article(client, workspace_id, id, opts) do
    body = Model.take_body(opts, @article_update_body)

    with {:ok, data} <-
           Client.request(client, :patch, article_path(id),
             params: workspace(workspace_id),
             json: body
           ) do
      {:ok, BlogArticleFull.from_map(data)}
    end
  end

  @doc """
  Writes the article again from its brief. Needs the `ai` scope.
  """
  @spec regenerate_article(Client.t(), String.t(), String.t()) ::
          {:ok, BlogArticle.t()} | {:error, FoPost.Error.t()}
  def regenerate_article(client, workspace_id, id) do
    action(client, workspace_id, id, "regenerate")
  end

  @doc """
  Moves a draft, failed or rejected article to `"in_review"`, ready for
  approval. Any other state answers `409`.
  """
  @spec submit_article(Client.t(), String.t(), String.t()) ::
          {:ok, BlogArticle.t()} | {:error, FoPost.Error.t()}
  def submit_article(client, workspace_id, id) do
    action(client, workspace_id, id, "submit")
  end

  @doc """
  Approves an article in review and publishes it to the target now. A draft
  answers `409` until it is submitted with `submit_article/3`, and `no_target`
  when the settings name none. Needs the `publish` scope.
  """
  @spec publish_article(Client.t(), String.t(), String.t()) ::
          {:ok, BlogArticle.t()} | {:error, FoPost.Error.t()}
  def publish_article(client, workspace_id, id) do
    action(client, workspace_id, id, "publish")
  end

  @doc """
  Marks a draft rejected so it never publishes.
  """
  @spec reject_article(Client.t(), String.t(), String.t()) ::
          {:ok, BlogArticle.t()} | {:error, FoPost.Error.t()}
  def reject_article(client, workspace_id, id) do
    action(client, workspace_id, id, "reject")
  end

  @doc """
  Removes an article. A published copy on the target stays where it is.
  """
  @spec delete_article(Client.t(), String.t(), String.t()) ::
          {:ok, term()} | {:error, FoPost.Error.t()}
  def delete_article(client, workspace_id, id) do
    Client.request(client, :delete, article_path(id), params: workspace(workspace_id))
  end

  @doc "Same as `settings/2`, but raises `FoPost.Error`."
  def settings!(client, workspace_id), do: Result.unwrap!(settings(client, workspace_id))

  @doc "Same as `update_settings/3`, but raises `FoPost.Error`."
  def update_settings!(client, workspace_id, opts) do
    Result.unwrap!(update_settings(client, workspace_id, opts))
  end

  @doc "Same as `rotate_website_secret/2`, but raises `FoPost.Error`."
  def rotate_website_secret!(client, workspace_id) do
    Result.unwrap!(rotate_website_secret(client, workspace_id))
  end

  @doc "Same as `test_website/2`, but raises `FoPost.Error`."
  def test_website!(client, workspace_id), do: Result.unwrap!(test_website(client, workspace_id))

  @doc "Same as `list_keywords/3`, but raises `FoPost.Error`."
  def list_keywords!(client, workspace_id, opts \\ []) do
    Result.unwrap!(list_keywords(client, workspace_id, opts))
  end

  @doc "Same as `suggest_seeds/3`, but raises `FoPost.Error`."
  def suggest_seeds!(client, workspace_id, opts \\ []) do
    Result.unwrap!(suggest_seeds(client, workspace_id, opts))
  end

  @doc "Same as `plan_keywords/3`, but raises `FoPost.Error`."
  def plan_keywords!(client, workspace_id, opts \\ []) do
    Result.unwrap!(plan_keywords(client, workspace_id, opts))
  end

  @doc "Same as `add_keyword/3`, but raises `FoPost.Error`."
  def add_keyword!(client, workspace_id, opts) do
    Result.unwrap!(add_keyword(client, workspace_id, opts))
  end

  @doc "Same as `update_keyword/4`, but raises `FoPost.Error`."
  def update_keyword!(client, workspace_id, id, opts) do
    Result.unwrap!(update_keyword(client, workspace_id, id, opts))
  end

  @doc "Same as `delete_keyword/3`, but raises `FoPost.Error`."
  def delete_keyword!(client, workspace_id, id) do
    Result.unwrap!(delete_keyword(client, workspace_id, id))
  end

  @doc "Same as `list_articles/3`, but raises `FoPost.Error`."
  def list_articles!(client, workspace_id, opts \\ []) do
    Result.unwrap!(list_articles(client, workspace_id, opts))
  end

  @doc "Same as `request_article/3`, but raises `FoPost.Error`."
  def request_article!(client, workspace_id, opts) do
    Result.unwrap!(request_article(client, workspace_id, opts))
  end

  @doc "Same as `get_article/3`, but raises `FoPost.Error`."
  def get_article!(client, workspace_id, id) do
    Result.unwrap!(get_article(client, workspace_id, id))
  end

  @doc "Same as `update_article/4`, but raises `FoPost.Error`."
  def update_article!(client, workspace_id, id, opts) do
    Result.unwrap!(update_article(client, workspace_id, id, opts))
  end

  @doc "Same as `regenerate_article/3`, but raises `FoPost.Error`."
  def regenerate_article!(client, workspace_id, id) do
    Result.unwrap!(regenerate_article(client, workspace_id, id))
  end

  @doc "Same as `submit_article/3`, but raises `FoPost.Error`."
  def submit_article!(client, workspace_id, id) do
    Result.unwrap!(submit_article(client, workspace_id, id))
  end

  @doc "Same as `publish_article/3`, but raises `FoPost.Error`."
  def publish_article!(client, workspace_id, id) do
    Result.unwrap!(publish_article(client, workspace_id, id))
  end

  @doc "Same as `reject_article/3`, but raises `FoPost.Error`."
  def reject_article!(client, workspace_id, id) do
    Result.unwrap!(reject_article(client, workspace_id, id))
  end

  @doc "Same as `delete_article/3`, but raises `FoPost.Error`."
  def delete_article!(client, workspace_id, id) do
    Result.unwrap!(delete_article(client, workspace_id, id))
  end

  defp action(client, workspace_id, id, name) do
    with {:ok, data} <-
           Client.request(client, :post, article_path(id) <> "/" <> name,
             params: workspace(workspace_id),
             json: %{}
           ) do
      {:ok, BlogArticle.from_map(data)}
    end
  end

  defp workspace(workspace_id), do: [{"workspace_id", workspace_id}]

  defp keyword_path(id), do: "/blog/keywords/" <> encode(id)
  defp article_path(id), do: "/blog/articles/" <> encode(id)

  defp encode(id), do: URI.encode(to_string(id), &URI.char_unreserved?/1)
end
