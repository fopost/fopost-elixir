defmodule FoPost do
  @moduledoc """
  The official Elixir SDK for the [FoPost](https://fopost.com) API.

  Connect social accounts once, then compose, schedule, and publish from your own
  application.

      client = FoPost.new(api_key: "fp_...")

      {:ok, workspaces} = FoPost.Workspaces.list(client)
      workspace = hd(workspaces)

      {:ok, accounts} = FoPost.Accounts.list(client, workspace_id: workspace.id)

      {:ok, post} =
        FoPost.Posts.create(client,
          workspace_id: workspace.id,
          content: "Hello from Elixir",
          accounts: Enum.map(accounts, & &1.id)
        )

      {:ok, _result} = FoPost.Posts.publish(client, post.id)

  ## Results

  Every function answers `{:ok, result}` or `{:error, %FoPost.Error{}}`, and every one has
  a bang variant that returns the result or raises the same error:

      post = FoPost.Posts.create!(client, workspace_id: id, content: "Hello")

  ## Resources

  `FoPost.Posts`, `FoPost.Workspaces`, `FoPost.Accounts`, `FoPost.Communities`,
  `FoPost.Labels`, `FoPost.Webhooks`, `FoPost.Analytics`, `FoPost.Automations`,
  `FoPost.Media`. Anything they do not wrap is reachable through `request/4`.
  """

  alias FoPost.Client
  alias FoPost.Result

  @doc """
  Builds a client.

  ## Options

    * `:api_key` — the key to authenticate with. Falls back to `config :fopost, :api_key`
      and then to the `FOPOST_API_KEY` environment variable. Required: without one this
      raises `ArgumentError`.
    * `:base_url` — defaults to `https://api.fopost.com/v1`, overridable through
      `config :fopost, :base_url` or the `FOPOST_BASE_URL` environment variable.
    * `:timeout` — how long one request may take to answer, in milliseconds.
      Defaults to `30_000`.
    * `:max_retries` — retries after the first attempt. Defaults to `2`, so three
      attempts in total. `0` disables retrying.
    * `:user_agent` — replaces the default `fopost-elixir/<version>`.
    * `:req_options` — options merged last into every Req request, so they win over
      everything above. Use it for a custom Finch pool, a proxy, or a test stub.

  Explicit options beat application config, which beats the environment.

      client = FoPost.new(api_key: "fp_...")
      client = FoPost.new()  # reads config or FOPOST_API_KEY
  """
  @spec new(keyword()) :: Client.t()
  def new(opts \\ []), do: Client.new(opts)

  @doc """
  The SDK version, as reported in the `User-Agent` header.
  """
  @spec version() :: String.t()
  def version, do: Client.version()

  @doc """
  Calls an endpoint the SDK does not wrap yet.

  The decoded body is returned exactly as the API sent it, envelope included. Pass
  `unwrap: true` to peel a `{"data": ...}` wrapper off it.

      {:ok, body} = FoPost.request(client, :get, "/platforms")
      {:ok, body} = FoPost.request(client, :post, "/posts/\#{id}/publish", json: %{})
      {:ok, body} = FoPost.request(client, :get, "/posts", params: [per_page: 5])

  Options are Req options, so `:params`, `:json`, and `:form_multipart` all work.
  """
  @spec request(Client.t(), atom(), String.t(), keyword()) ::
          {:ok, term()} | {:error, FoPost.Error.t()}
  def request(client, method, path, opts \\ []) do
    Client.request(client, method, path, Keyword.put_new(opts, :unwrap, false))
  end

  @doc """
  `request/4` that returns the body or raises `FoPost.Error`.
  """
  @spec request!(Client.t(), atom(), String.t(), keyword()) :: term()
  def request!(client, method, path, opts \\ []) do
    Result.unwrap!(request(client, method, path, opts))
  end
end
