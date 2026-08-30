defmodule FoPost.Posts do
  @moduledoc """
  Create, schedule, publish, and inspect posts.

      {:ok, post} =
        FoPost.Posts.create(client,
          workspace_id: workspace.id,
          content: "Hello from Elixir",
          accounts: [account.id]
        )

      {:ok, result} = FoPost.Posts.publish(client, post.id)

  `:content` takes a string for a single block, or a list for a thread. A block may also
  be a map of `text` plus `media`:

      FoPost.Posts.create(client,
        workspace_id: workspace.id,
        accounts: [account.id],
        content: [
          "First post in the thread",
          %{text: "Second one, with an image", media: [%{type: "image", url: url}]}
        ]
      )

  `:accounts` takes account ids, `FoPost.Account` structs, or maps carrying an `id`.

  `:status` is `"draft"` or `"scheduled"`; a scheduled post needs `:schedule_at`, which
  accepts a `DateTime`, a `NaiveDateTime`, or an ISO 8601 string. To send something out
  now, create it and call `publish/3` — publishing answers when delivery is queued, not
  when the post is live.
  """

  alias FoPost.Account
  alias FoPost.BulkImportResult
  alias FoPost.BulkImportValidation
  alias FoPost.BulkResult
  alias FoPost.Client
  alias FoPost.Content
  alias FoPost.Delivery
  alias FoPost.Message
  alias FoPost.Model
  alias FoPost.Page
  alias FoPost.PageMeta
  alias FoPost.Post
  alias FoPost.PostAnalytics
  alias FoPost.PreflightResult
  alias FoPost.PublishResult
  alias FoPost.PublishRun
  alias FoPost.Result

  @default_per_page 30

  @list_params [
    :page,
    :per_page,
    :workspace_id,
    :status,
    :search,
    :platform,
    :label,
    :account_id,
    :date,
    :from,
    :to,
    :sort
  ]

  @post_fields [
    :content_type,
    :artifact_type,
    :status,
    :repeatable,
    :repeatable_times,
    :repeatable_gap,
    :repeatable_gap_unit,
    :labels,
    :title,
    :internal_title,
    :summary,
    :auto_plug,
    :auto_plug_content,
    :settings,
    :source_ids,
    :companion_of
  ]

  @doc """
  One page of posts.

  Filters: `:workspace_id`, `:status`, `:search`, `:platform`, `:label`, `:account_id`,
  `:date`, `:from`, `:to`, `:sort`. Paging: `:page`, `:per_page`. Anything left out keeps
  the API's own default.

      {:ok, page} = FoPost.Posts.list(client, workspace_id: id, status: "published")
      page.meta.total
  """
  @spec list(Client.t(), keyword()) :: {:ok, Page.t()} | {:error, FoPost.Error.t()}
  def list(client, opts \\ []) do
    params = Model.take_params(opts, @list_params)

    with {:ok, data} <- Client.request(client, :get, "/posts", params: params, unwrap: false) do
      {:ok, Page.from_map(data, Post)}
    end
  end

  @doc """
  Every matching post as a lazy stream, fetching one page at a time.

  Takes the same filters as `list/2`. Because a stream cannot answer with an error tuple,
  a failed page raises `FoPost.Error`.

      client
      |> FoPost.Posts.stream(workspace_id: id)
      |> Stream.filter(&(&1.status == "published"))
      |> Enum.take(10)
  """
  @spec stream(Client.t(), keyword()) :: Enumerable.t()
  def stream(client, opts \\ []) do
    per_page = Keyword.get(opts, :per_page) || @default_per_page

    Stream.resource(
      fn -> Keyword.get(opts, :page) || 1 end,
      fn page -> walk(client, opts, page, per_page) end,
      fn _state -> :ok end
    )
  end

  @doc """
  One post.
  """
  @spec get(Client.t(), String.t()) :: {:ok, Post.t()} | {:error, FoPost.Error.t()}
  def get(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id)) do
      {:ok, Post.from_map(data)}
    end
  end

  @doc """
  Composes a draft or a scheduled post.

  Required: `:workspace_id`, `:content`, `:accounts`. Optional: `:status`,
  `:schedule_at`, `:content_type`, `:artifact_type`, `:labels`, `:title`,
  `:internal_title`, `:summary`, `:auto_plug`, `:auto_plug_content`, `:settings`,
  `:repeatable`, `:repeatable_times`, `:repeatable_gap`, `:repeatable_gap_unit`,
  `:source_ids`, `:companion_of`.
  """
  @spec create(Client.t(), keyword()) :: {:ok, Post.t()} | {:error, FoPost.Error.t()}
  def create(client, opts) do
    body =
      opts
      |> Model.take_body(@post_fields)
      |> Map.put("workspace_id", Keyword.get(opts, :workspace_id))
      |> Map.put("content", Content.normalize(Keyword.get(opts, :content)))
      |> Map.put("accounts", account_ids(Keyword.get(opts, :accounts)))
      |> put_schedule_at(opts)

    with {:ok, data} <- Client.request(client, :post, "/posts", json: body) do
      {:ok, Post.from_map(data)}
    end
  end

  @doc """
  Edits a post that has not been published.

  Only the keys you pass are sent, so this stays a partial update. Passing a key as `nil`
  sends null, which is how a field is cleared.
  """
  @spec update(Client.t(), String.t(), keyword()) :: {:ok, Post.t()} | {:error, FoPost.Error.t()}
  def update(client, id, opts) do
    body =
      opts
      |> Model.take_body(@post_fields)
      |> put_content(opts)
      |> put_accounts(opts)
      |> put_schedule_at(opts)

    with {:ok, data} <- Client.request(client, :put, path(id), json: body) do
      {:ok, Post.from_map(data)}
    end
  end

  @doc """
  Removes a post.
  """
  @spec delete(Client.t(), String.t()) :: {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete(client, id) do
    with {:ok, data} <- Client.request(client, :delete, path(id)) do
      {:ok, Message.from_map(data)}
    end
  end

  @doc """
  Copies a post into a new draft.
  """
  @spec duplicate(Client.t(), String.t()) :: {:ok, Post.t()} | {:error, FoPost.Error.t()}
  def duplicate(client, id) do
    with {:ok, data} <- Client.request(client, :post, path(id, "duplicate")) do
      {:ok, Post.from_map(data)}
    end
  end

  @doc """
  Queues a post for delivery to its accounts.

  Nothing reaches a platform without this call or a schedule the user set. Options:

    * `:account_ids` — publish to a subset of the post's accounts
    * `:dry_run` — validate everything without sending anything to a platform
  """
  @spec publish(Client.t(), String.t(), keyword()) ::
          {:ok, PublishResult.t()} | {:error, FoPost.Error.t()}
  def publish(client, id, opts \\ []) do
    body =
      %{}
      |> Model.put_present("accountIds", account_id_list(opts[:account_ids]))
      |> put_dry_run(opts)

    with {:ok, data} <- Client.request(client, :post, path(id, "publish"), json: body) do
      {:ok, PublishResult.from_map(data)}
    end
  end

  @doc """
  Stops the deliveries that have not gone out yet.

  Pass `:account_ids` to cancel only some of them.
  """
  @spec cancel(Client.t(), String.t(), keyword()) ::
          {:ok, PublishResult.t()} | {:error, FoPost.Error.t()}
  def cancel(client, id, opts \\ []) do
    body = Model.put_present(%{}, "accountIds", account_id_list(opts[:account_ids]))

    with {:ok, data} <- Client.request(client, :post, path(id, "cancel"), json: body) do
      {:ok, PublishResult.from_map(data)}
    end
  end

  @doc """
  Re-sends the deliveries that failed, leaving the successful ones alone.

  Options: `:account_ids`, `:include_published`.
  """
  @spec retry(Client.t(), String.t(), keyword()) ::
          {:ok, PublishResult.t()} | {:error, FoPost.Error.t()}
  def retry(client, id, opts \\ []) do
    body =
      %{}
      |> Model.put_present("accountIds", account_id_list(opts[:account_ids]))
      |> Model.put_present("includePublished", opts[:include_published])

    with {:ok, data} <- Client.request(client, :post, path(id, "retry"), json: body) do
      {:ok, PublishResult.from_map(data)}
    end
  end

  @doc """
  Checks a post against every platform it targets, without publishing.
  """
  @spec preflight(Client.t(), String.t()) ::
          {:ok, PreflightResult.t()} | {:error, FoPost.Error.t()}
  def preflight(client, id) do
    with {:ok, data} <- Client.request(client, :post, path(id, "preflight")) do
      {:ok, PreflightResult.from_map(data)}
    end
  end

  @doc """
  The current delivery record for each account the post targets.
  """
  @spec deliveries(Client.t(), String.t()) :: {:ok, [Delivery.t()]} | {:error, FoPost.Error.t()}
  def deliveries(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id, "deliveries")) do
      {:ok, Model.list(Delivery, data)}
    end
  end

  @doc """
  Every publish attempt made for a post, newest first.
  """
  @spec publish_runs(Client.t(), String.t()) ::
          {:ok, [PublishRun.t()]} | {:error, FoPost.Error.t()}
  def publish_runs(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id, "publish-runs")) do
      {:ok, Model.list(PublishRun, data)}
    end
  end

  @doc """
  A post's performance across the platforms it reached.
  """
  @spec analytics(Client.t(), String.t()) :: {:ok, PostAnalytics.t()} | {:error, FoPost.Error.t()}
  def analytics(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id, "analytics")) do
      {:ok, PostAnalytics.from_map(data)}
    end
  end

  @doc """
  Moves a selection's schedule by `:offset_minutes`, which may be negative but never zero.

  Only drafts and scheduled posts can be shifted, and one ineligible post in the selection
  changes nothing at all.
  """
  @spec bulk_shift(Client.t(), keyword()) :: {:ok, BulkResult.t()} | {:error, FoPost.Error.t()}
  def bulk_shift(client, opts) do
    bulk(client, opts, %{
      "action" => "shift",
      "offset_minutes" => Keyword.get(opts, :offset_minutes)
    })
  end

  @doc """
  Relabels a selection.

  `:mode` is `"replace"` (the default, where an empty `:label_ids` clears them), `"add"`,
  or `"remove"`.
  """
  @spec bulk_label(Client.t(), keyword()) :: {:ok, BulkResult.t()} | {:error, FoPost.Error.t()}
  def bulk_label(client, opts) do
    body =
      %{"action" => "label", "label_ids" => Keyword.get(opts, :label_ids, [])}
      |> Model.put_present("mode", opts[:mode])

    bulk(client, opts, body)
  end

  @doc """
  Removes a selection of posts in one transaction.
  """
  @spec bulk_delete(Client.t(), keyword()) :: {:ok, BulkResult.t()} | {:error, FoPost.Error.t()}
  def bulk_delete(client, opts) do
    bulk(client, opts, %{"action" => "delete"})
  end

  @doc """
  Dry-runs a CSV import and reports per-row results without creating anything.

  `:file` is a path, a `{filename, content}` tuple, or a map of `:filename` and
  `:content`.
  """
  @spec validate_bulk_import(Client.t(), keyword()) ::
          {:ok, BulkImportValidation.t()} | {:error, FoPost.Error.t()}
  def validate_bulk_import(client, opts) do
    with {:ok, data} <- upload_csv(client, "/posts/bulk-import/validate", opts) do
      {:ok, BulkImportValidation.from_map(data)}
    end
  end

  @doc """
  Creates the posts a CSV describes. Keep the batch id to roll the import back.
  """
  @spec commit_bulk_import(Client.t(), keyword()) ::
          {:ok, BulkImportResult.t()} | {:error, FoPost.Error.t()}
  def commit_bulk_import(client, opts) do
    with {:ok, data} <- upload_csv(client, "/posts/bulk-import/commit", opts) do
      {:ok, BulkImportResult.from_map(data)}
    end
  end

  @doc """
  Deletes every post a committed batch created.
  """
  @spec rollback_bulk_import(Client.t(), String.t()) ::
          {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def rollback_bulk_import(client, batch_id) do
    url_path = "/posts/bulk-import/" <> segment(batch_id)

    with {:ok, data} <- Client.request(client, :delete, url_path) do
      {:ok, Message.from_map(data)}
    end
  end

  @doc "Same as `list/2`, but returns the page or raises `FoPost.Error`."
  def list!(client, opts \\ []), do: Result.unwrap!(list(client, opts))

  @doc "Same as `get/2`, but returns the post or raises `FoPost.Error`."
  def get!(client, id), do: Result.unwrap!(get(client, id))

  @doc "Same as `create/2`, but returns the post or raises `FoPost.Error`."
  def create!(client, opts), do: Result.unwrap!(create(client, opts))

  @doc "Same as `update/3`, but returns the post or raises `FoPost.Error`."
  def update!(client, id, opts), do: Result.unwrap!(update(client, id, opts))

  @doc "Same as `delete/2`, but raises `FoPost.Error`."
  def delete!(client, id), do: Result.unwrap!(delete(client, id))

  @doc "Same as `duplicate/2`, but raises `FoPost.Error`."
  def duplicate!(client, id), do: Result.unwrap!(duplicate(client, id))

  @doc "Same as `publish/3`, but raises `FoPost.Error`."
  def publish!(client, id, opts \\ []), do: Result.unwrap!(publish(client, id, opts))

  @doc "Same as `cancel/3`, but raises `FoPost.Error`."
  def cancel!(client, id, opts \\ []), do: Result.unwrap!(cancel(client, id, opts))

  @doc "Same as `retry/3`, but raises `FoPost.Error`."
  def retry!(client, id, opts \\ []), do: Result.unwrap!(retry(client, id, opts))

  @doc "Same as `preflight/2`, but raises `FoPost.Error`."
  def preflight!(client, id), do: Result.unwrap!(preflight(client, id))

  @doc "Same as `deliveries/2`, but raises `FoPost.Error`."
  def deliveries!(client, id), do: Result.unwrap!(deliveries(client, id))

  @doc "Same as `publish_runs/2`, but raises `FoPost.Error`."
  def publish_runs!(client, id), do: Result.unwrap!(publish_runs(client, id))

  @doc "Same as `analytics/2`, but raises `FoPost.Error`."
  def analytics!(client, id), do: Result.unwrap!(analytics(client, id))

  @doc "Same as `bulk_shift/2`, but raises `FoPost.Error`."
  def bulk_shift!(client, opts), do: Result.unwrap!(bulk_shift(client, opts))

  @doc "Same as `bulk_label/2`, but raises `FoPost.Error`."
  def bulk_label!(client, opts), do: Result.unwrap!(bulk_label(client, opts))

  @doc "Same as `bulk_delete/2`, but raises `FoPost.Error`."
  def bulk_delete!(client, opts), do: Result.unwrap!(bulk_delete(client, opts))

  @doc "Same as `validate_bulk_import/2`, but raises `FoPost.Error`."
  def validate_bulk_import!(client, opts) do
    Result.unwrap!(validate_bulk_import(client, opts))
  end

  @doc "Same as `commit_bulk_import/2`, but raises `FoPost.Error`."
  def commit_bulk_import!(client, opts) do
    Result.unwrap!(commit_bulk_import(client, opts))
  end

  @doc "Same as `rollback_bulk_import/2`, but raises `FoPost.Error`."
  def rollback_bulk_import!(client, batch_id) do
    Result.unwrap!(rollback_bulk_import(client, batch_id))
  end

  defp walk(_client, _opts, nil, _per_page), do: {:halt, nil}

  defp walk(client, opts, page, per_page) do
    result = list!(client, Keyword.merge(opts, page: page, per_page: per_page))

    case result.data do
      [] -> {:halt, nil}
      data -> {data, next_page(result.meta, page, length(data), per_page)}
    end
  end

  defp next_page(%PageMeta{last_page: last}, page, _count, _per_page) when is_integer(last) do
    if page >= last, do: nil, else: page + 1
  end

  defp next_page(_meta, page, count, per_page) do
    if count < per_page, do: nil, else: page + 1
  end

  defp bulk(client, opts, body) do
    body =
      body
      |> Map.put("workspace_id", Keyword.get(opts, :workspace_id))
      |> Map.put("post_ids", Keyword.get(opts, :post_ids, []))

    with {:ok, data} <- Client.request(client, :post, "/posts/bulk", json: body) do
      {:ok, BulkResult.from_map(data)}
    end
  end

  defp upload_csv(client, path, opts) do
    {filename, content} = csv_file(Keyword.fetch!(opts, :file))

    form = [
      workspace_id: Keyword.get(opts, :workspace_id),
      file: {content, [filename: filename, content_type: "text/csv"]}
    ]

    Client.request(client, :post, path, form_multipart: form)
  end

  defp csv_file(path) when is_binary(path), do: {Path.basename(path), File.read!(path)}
  defp csv_file({filename, content}), do: {filename, content}

  defp csv_file(%{} = file) do
    {Map.get(file, :filename) || "posts.csv", Map.fetch!(file, :content)}
  end

  defp put_content(body, opts) do
    case Keyword.fetch(opts, :content) do
      {:ok, value} -> Map.put(body, "content", Content.normalize(value))
      :error -> body
    end
  end

  defp put_accounts(body, opts) do
    case Keyword.fetch(opts, :accounts) do
      {:ok, value} -> Map.put(body, "accounts", account_ids(value))
      :error -> body
    end
  end

  defp put_schedule_at(body, opts) do
    case Keyword.fetch(opts, :schedule_at) do
      {:ok, value} -> Map.put(body, "schedule_at", Model.to_iso8601(value))
      :error -> body
    end
  end

  defp put_dry_run(body, opts) do
    if opts[:dry_run] do
      Map.put(body, "options", %{"dryRun" => true})
    else
      body
    end
  end

  defp account_id_list(nil), do: nil
  defp account_id_list([]), do: nil
  defp account_id_list(accounts), do: account_ids(accounts)

  defp account_ids(nil), do: []
  defp account_ids(accounts) when is_list(accounts), do: Enum.map(accounts, &account_id/1)
  defp account_ids(account), do: [account_id(account)]

  defp account_id(%Account{id: id}), do: id
  defp account_id(%{"id" => id}), do: id
  defp account_id(%{id: id}), do: id
  defp account_id(id), do: id

  defp path(id), do: "/posts/" <> segment(id)
  defp path(id, action), do: path(id) <> "/" <> action

  defp segment(value), do: URI.encode(to_string(value), &URI.char_unreserved?/1)
end
