# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## Read This First: Nothing Here Has Ever Been Compiled

**The machine this SDK was written on had no Elixir, no Mix, and no Erlang installed.**
Nothing in this repository has been compiled, formatted, linted, type-checked, or tested
locally — not once. Every claim about it being correct is a claim from careful reading,
not from a green run.

The **first CI run is the first real verification**. Expect it to surface things a
compiler would have caught in a second:

- a struct field referenced by the wrong name, or an arity that does not line up
- `mix format --check-formatted` disagreeing with hand-formatted code — the likeliest
  failure by far, and always a trivial fix (`mix format` and commit)
- a `mix credo --strict` check that `.credo.exs` does not already disable
- a Req option or callback shape that differs from what the docs implied

When you first get a working toolchain, **run `mix deps.get && mix format && mix compile
&& mix test && mix credo --strict && mix dialyzer` before anything else**, commit the
result, and then delete this section. Do not add features on top of an unverified base.

There is also **no `mix.lock` committed**, for the same reason. Generate one with
`mix deps.get` and commit it in that same first pass — a library should ship a lock file
so CI resolves the same tree twice.

## What This Is

Hex package [`fopost`](https://hex.pm/packages/fopost), app `:fopost`, version `0.1.0` —
the official Elixir client for the FoPost REST API (`fopost.com`). Elixir `~> 1.15`,
OTP 25+.

Runtime dependencies are [`req`](https://hexdocs.pm/req) and `jason`, nothing else. There
is no supervision tree and no application callback module: a client is a plain struct and
Req's own application owns the connection pool.

## Brand Rules

- The product is **FoPost** (`fopost.com`). Never write "OwlStack" — retired Aug 2026.
- Never write an email address. Support is https://fopost.com/contact and GitHub issues.
- Never name AI providers/models, infrastructure vendors, or any person.
- Never type a platform count in a doc comment or the README.

## Architecture

| Path | Contents |
| :--- | :--- |
| `lib/fopost.ex` | `FoPost` — `new/1`, `version/0`, and the `request/4` escape hatch |
| `lib/fopost/client.ex` | `FoPost.Client` — the struct, config resolution, the Req pipeline, the retry policy |
| `lib/fopost/error.ex` | `FoPost.Error` — one `defexception` struct plus the status predicates |
| `lib/fopost/model.ex` | `@moduledoc false` decoding helpers: key normalisation, timestamps, request-body building |
| `lib/fopost/result.ex` | `@moduledoc false` — `unwrap!/1`, which backs every bang variant |
| `lib/fopost/page.ex` | `FoPost.Page` and `FoPost.PageMeta` |
| `lib/fopost/content.ex` | `FoPost.MediaItem`, `FoPost.ContentBlock`, and `FoPost.Content` (post body building) |
| `lib/fopost/models/*.ex` | One response struct per API shape, each with `from_map/1` |
| `lib/fopost/<resource>.ex` | One module per resource: posts, workspaces, accounts, communities, labels, webhooks, analytics, automations, media |

A request flows: a resource function builds its params with `Model.take_params/2` and its
body with `Model.take_body/2` → `Client.request(client, method, path, opts)` → `Req.new/1`
→ `Req.request/1` → `Client.handle/2` → the `{"data": ...}` envelope is peeled →
`Struct.from_map/1`.

### Rules the code follows, and why

- **Every public function answers `{:ok, result}` or `{:error, %FoPost.Error{}}`**, and
  every one has a `!` twin defined as `Result.unwrap!(the_non_bang_call)`. When you add a
  function, add its bang variant in the same commit — the pairing is the convention here.
- **Never return a raw map with string keys from the public API.** A new response shape
  gets a struct in `lib/fopost/models/` with an explicit `from_map/1`. Deeply nested
  free-form objects (`settings`, `trigger_config`, `action_config`) are the documented
  exception and pass through untouched, because their keys are user data.
- **The API's wire casing is inconsistent** — posts are snake_case, accounts camelCase,
  workspaces a mix — so `Model.normalize/1` snake-cases every key before a struct reads
  it, and every struct keeps the decoded body on `:raw`. Going the other way,
  `Model.take_body/2` and `take_params/2` accept `{:workspace_id, "workspaceId"}` pairs
  for the endpoints that expect camelCase. Check the endpoint before assuming.
- **One error type, not nine.** The brief lists a subclass per status; Elixir does not
  need one. `%FoPost.Error{}` carries `:status` and `:code`, and
  `FoPost.Error.rate_limited?/1` and friends cover what callers actually branch on. Do
  not "fix" this into a module hierarchy.
- **`take_body/2` keeps a key passed as `nil` and drops a key that was never passed**, so
  a `PUT` stays a partial update and `nil` is how a field is cleared. `take_params/2`
  drops `nil` instead: there is no such thing as clearing a filter nobody applied.

## API Contract

- Base URL `https://api.fopost.com/v1`, overridden by `:base_url`,
  `config :fopost, :base_url`, or `FOPOST_BASE_URL`.
- Auth is the header **`X-API-Key`**, never a bearer token. The key comes from `:api_key`,
  then `config :fopost, :api_key`, then `FOPOST_API_KEY`; none of them raises
  `ArgumentError` from `FoPost.new/1`.
- Headers sent: `accept: application/json`, `x-api-key`, `user-agent:
  fopost-elixir/<version>`. Req adds the content type for a JSON or multipart body.
- Timeout: `receive_timeout` 30 s, from `:timeout`.
- **Retries: two, so three attempts.** `:max_retries` is the number of *retries* (Req's
  own meaning), not attempts. See the mapping below.
- Success envelope: `{"data": ...}` is peeled by `Client.request/4` unless the caller
  passes `unwrap: false`. Paginated lists pass `false` so `meta` survives, and build a
  `FoPost.Page`. `FoPost.request/4` — the public escape hatch — defaults to `false`, so a
  caller sees exactly what the API sent.
- Error envelope: `{"error": "<code>", "message": "<text>"}` becomes `:code` and
  `:message`; a 402's `upgrade_url` and a 429's `Retry-After` are lifted onto the struct.

### How the retry contract maps onto Req

The brief asks for three attempts, retrying only 429 / 5xx / transport, exponential from
500 ms capped at 60 s, honouring `Retry-After`. That is expressed as Req options in
`Client.build/4` rather than a hand-rolled loop:

| Contract | Req option |
| :--- | :--- |
| 3 attempts total | `max_retries: 2` (Req counts *retries*) |
| only 429, >= 500, transport errors | `retry: &Client.retry?/2` |
| 500 ms · 2^attempt, capped at 60 s | `retry_delay: &Client.retry_delay/1` (Req's attempt is 0-based) |
| honour `Retry-After` | Req honours it on a 429 by itself |
| cap `Retry-After` at 60 s | a prepended response step, `Client.cap_retry_after_step/1` |

That last row is the only piece Req cannot express: `:retry_delay` receives the attempt
number, not the response, so it cannot see the header. The step rewrites an oversized
`Retry-After` to `60` **before** Req's own retry step reads it — hence
`prepend_response_steps`, not `append`. If Req's pipeline order ever changes, the failure
mode is benign: the cap stops applying and Req still honours the header as sent.

`:req_options` on the client is merged **last**, so a caller can override any of this.
That is also how the test suite forces a zero backoff.

## Commands

```bash
mix deps.get
mix compile
mix test                        # offline; Bypass stands up a local server per test
mix test test/fopost/posts_test.exs
mix format                      # CI runs mix format --check-formatted
mix credo --strict
mix dialyzer
mix docs
mix run examples/create_post.exs
```

## Conventions

- `mix format` is the authority, 98-column lines, and CI fails on a file it would change.
- Aliases are alphabetical (Credo's `AliasOrder` is on) and every module has a
  `@moduledoc`; internal ones use `@moduledoc false`.
- `@spec` on every public function. `Credo.Check.Readability.Specs` is not enabled, but
  Dialyzer is only as useful as the specs it reads.
- `.credo.exs` disables four checks on purpose, each with the reason in a comment. The
  load-bearing one is `Design.DuplicatedCode`: one near-identical `from_map/1` per
  response struct is the design, not an accident. Do not replace them with a macro — a
  field list you can read beside the API docs is worth the repetition.
- **Tests never reach the network.** Bypass serves every request from `localhost`, and
  `test/test_helper.exs` clears `FOPOST_API_KEY` and `FOPOST_BASE_URL` so a developer's
  own environment cannot leak into a run. `FoPost.TestSupport.client/2` builds a client
  pointed at the Bypass port with a zero retry delay.
- The SDK version lives in **two** places: `@version` in `mix.exs` (what Hex ships) and
  `@version` in `lib/fopost/client.ex` (what the `User-Agent` reports). `FoPostTest`
  asserts they match, so bumping one and not the other fails the suite.

## Releasing

Bump `@version` in `mix.exs` **and** in `lib/fopost/client.ex`, add a `CHANGELOG.md`
entry, tag `v<version>`, and push the tag. `.github/workflows/release.yml` verifies the
tag against `mix.exs`, runs format, Credo, and the tests, then `mix hex.publish --yes`.

Requires:

- the repository secret **`HEX_API_KEY`**, generated with `mix hex.user key generate`
  (a key with the `api:write` permission), and
- the package name `fopost` **claimed on hex.pm first** — the first publish must be done
  by a human from a machine with the toolchain, or the workflow will fail on an
  unclaimed-name error. Everything after that is the tag.

The workflow publishes from a `hex` GitHub environment, so commit access alone does not
grant the ability to cut a release.

## Git

Conventional Commits (`<type>(<scope>): <description>`), atomic — one logical change per
commit. Branch `feature/<description>` off a fresh `main`, merge via PR. Never
`gh pr create` — push the branch and hand over the compare link
(`https://github.com/fopost/fopost-elixir/compare/main...<branch>`).
