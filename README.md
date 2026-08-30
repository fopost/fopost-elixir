# FoPost Elixir SDK

[![Hex.pm](https://img.shields.io/hexpm/v/fopost.svg)](https://hex.pm/packages/fopost)
[![Documentation](https://img.shields.io/badge/hexdocs-fopost-8e5ea2.svg)](https://hexdocs.pm/fopost)
[![CI](https://img.shields.io/github/actions/workflow/status/fopost/fopost-elixir/ci.yml?branch=main&label=ci)](https://github.com/fopost/fopost-elixir/actions)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

The official Elixir SDK for the [FoPost](https://fopost.com) API. Connect social accounts
once, then compose, schedule, and publish to every network FoPost supports from your own
application.

Requires Elixir 1.15 or newer on OTP 25 or newer.

> **0.x release.** The public API is still settling and minor versions may contain
> breaking changes. Pin an exact version if that matters to you.

## Install

```elixir
def deps do
  [{:fopost, "~> 0.1"}]
end
```

Nothing needs to go in your supervision tree: requests go out over
[Req](https://hexdocs.pm/req), which pools connections through the Finch instance its own
application starts.

## Get an API key

Create one in the FoPost dashboard under **Settings → API Keys**. The full API reference
lives at [fopost.com/docs](https://fopost.com/docs).

## Quick start

```elixir
client = FoPost.new(api_key: "fp_...")   # or set FOPOST_API_KEY

{:ok, [workspace | _]} = FoPost.Workspaces.list(client)
{:ok, accounts} = FoPost.Accounts.list(client, workspace_id: workspace.id)

{:ok, post} =
  FoPost.Posts.create(client,
    workspace_id: workspace.id,
    content: "Hello from Elixir",
    accounts: Enum.map(accounts, & &1.id)
  )

{:ok, result} = FoPost.Posts.publish(client, post.id)
```

The client is a plain struct with no process behind it, so build it once and pass it
around — including across processes.

## Results and errors

Every function answers `{:ok, result}` or `{:error, %FoPost.Error{}}`:

```elixir
case FoPost.Posts.publish(client, post.id) do
  {:ok, result} ->
    Logger.info("queued: #{result.post_status}")

  {:error, %FoPost.Error{} = error} ->
    cond do
      FoPost.Error.rate_limited?(error) -> retry_in(error.retry_after)
      FoPost.Error.payment_required?(error) -> send_to(error.upgrade_url)
      FoPost.Error.validation?(error) -> report(error.body)
      true -> Logger.error(Exception.message(error))
    end
end
```

One struct covers every failure. `:status` is the HTTP status, `:code` the API's
machine-readable error, `:message` its explanation, and `:body` the decoded body exactly
as it arrived, so a field the SDK does not model yet is still reachable. A connection that
never produced a response is the same struct with `status: nil` and
`code: "transport_error"` — you never have to match on two shapes.

Predicates: `unauthorized?/1`, `payment_required?/1`, `forbidden?/1`, `not_found?/1`,
`validation?/1`, `rate_limited?/1`, `server_error?/1`, `transport_error?/1`.

Every function also has a bang variant that returns the result or raises the same error:

```elixir
post = FoPost.Posts.create!(client, workspace_id: workspace.id, content: "Hello")
```

## Composing

`:content` takes a string for a single block, or a list for a thread. A block may also be
a map of `text` plus `media`:

```elixir
FoPost.Posts.create(client,
  workspace_id: workspace.id,
  accounts: [account.id],
  content: [
    "First post in the thread",
    %{text: "Second one, with an image", media: [%{type: "image", url: url}]}
  ]
)
```

`:accounts` takes account ids, `FoPost.Account` structs, or maps carrying an `id`.

## Scheduling

`:status` is `"draft"` or `"scheduled"`; a scheduled post needs `:schedule_at`, which
accepts a `DateTime`, a `NaiveDateTime`, or an ISO 8601 string.

```elixir
FoPost.Posts.create(client,
  workspace_id: workspace.id,
  accounts: [account.id],
  status: "scheduled",
  schedule_at: ~U[2026-09-01 10:00:00Z],
  content: "Scheduled with the SDK"
)
```

To send something out now, create it and call `publish/3`. Publishing answers when
delivery is **queued**, not when the post is live — poll `FoPost.Posts.deliveries/2` or
subscribe a webhook for the outcome.

## Pagination

`FoPost.Posts.list/2` answers one page: rows on `:data`, counters on `:meta`.

```elixir
{:ok, page} = FoPost.Posts.list(client, workspace_id: workspace.id, per_page: 50)
IO.puts("#{page.meta.total} posts")
```

`stream/2` walks every page for you, lazily. Because a stream cannot answer with an error
tuple, a failed page raises.

```elixir
client
|> FoPost.Posts.stream(workspace_id: workspace.id, status: "published")
|> Stream.map(& &1.id)
|> Enum.take(100)
```

## Media

```elixir
{:ok, [asset]} =
  FoPost.Media.upload(client, workspace_id: workspace.id, files: ["chart.png"])

FoPost.Posts.create(client,
  workspace_id: workspace.id,
  accounts: [account.id],
  content: %{text: "The numbers", media: [FoPost.MediaAsset.to_media_item(asset)]}
)
```

A file is a path, a `{filename, content}` tuple, or a map of `:filename`, `:content`, and
optionally `:content_type`.

## Webhooks

A delivery carries `X-FoPost-Signature` (`sha256=<hex>`), `X-FoPost-Event`, and
`X-FoPost-Delivery`. Verify against the **raw** body, before any JSON decoding:

```elixir
{:ok, raw, conn} = Plug.Conn.read_body(conn)
[signature] = Plug.Conn.get_req_header(conn, "x-fopost-signature")

case FoPost.Webhooks.verify_and_parse(raw, signature, secret) do
  {:ok, event} -> handle(event)
  {:error, :invalid_signature} -> Plug.Conn.send_resp(conn, 401, "")
  {:error, :invalid_payload} -> Plug.Conn.send_resp(conn, 400, "")
end
```

The comparison is constant time. No timestamp is mixed into the signature, so there is no
replay window to enforce — deduplicate on `X-FoPost-Delivery` if you need it.

## Retries

Every request is attempted up to three times: the original plus two retries. Only HTTP
429, HTTP 5xx, and transport failures are retried. Backoff is 500 ms doubling per attempt,
capped at 60 seconds; a `Retry-After` header on a 429 wins, also capped at 60 seconds.

```elixir
FoPost.new(api_key: key, max_retries: 0)   # off
FoPost.new(api_key: key, max_retries: 4)   # five attempts
```

## Configuration

Explicit options beat application config, which beats the environment.

```elixir
config :fopost,
  api_key: System.get_env("FOPOST_API_KEY"),
  base_url: "https://api.fopost.com/v1",
  timeout: 30_000,
  max_retries: 2
```

`FOPOST_API_KEY` and `FOPOST_BASE_URL` are read when nothing else supplies them.

`:req_options` is merged last into every request, so it wins over everything the SDK sets.
Use it for a custom Finch pool, a proxy, or a test stub:

```elixir
FoPost.new(api_key: key, req_options: [finch: MyApp.Finch, connect_options: [timeout: 5_000]])
```

## Anything the SDK does not wrap

```elixir
{:ok, body} = FoPost.request(client, :get, "/platforms")
{:ok, body} = FoPost.request(client, :post, "/posts/#{id}/publish", json: %{})
```

The body comes back exactly as the API sent it, envelope included. Options are Req
options, so `:params`, `:json`, and `:form_multipart` all work.

## Resources

`FoPost.Posts` · `FoPost.Workspaces` · `FoPost.Accounts` · `FoPost.Communities` ·
`FoPost.Labels` · `FoPost.Webhooks` · `FoPost.Analytics` · `FoPost.Automations` ·
`FoPost.Media`

## Examples

[`examples/create_post.exs`](examples/create_post.exs) creates a draft, preflights it, and
publishes it.

## Development

```bash
mix deps.get
mix test                    # offline, against a local stub server
mix format
mix credo --strict
mix dialyzer
```

Tests never reach the real API.

## Support

Questions and bug reports go to
[GitHub issues](https://github.com/fopost/fopost-elixir/issues); anything else to
[fopost.com/contact](https://fopost.com/contact).

## License

MIT © Porter Bridge, LLC. See [LICENSE](LICENSE).
