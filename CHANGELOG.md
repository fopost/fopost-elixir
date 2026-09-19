# Changelog

All notable changes to this project are documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `FoPost.Validate`: `post/2`, `length/2`, and `media/2` check content, text length, and a
  media URL against platform rules without creating a post (scope `posts`).
- `FoPost.AccountGroups`: `list/2`, `get/2`, `create/2`, `update/3`, `delete/2`, and
  `set_members/3` (scope `accounts`).
- `FoPost.Accounts.rename/3` and `move/3`, a `:group_id` filter on `list/2`, and
  `:platform_name` on `FoPost.Account`.
- `FoPost.Posts.create/2` accepts `:account_group_id`, which can stand in for `:accounts`.

## [0.2.0] - 2026-09-19

### Added

- `FoPost.Inbox`: comments, mentions, and direct messages on connected accounts, thread
  and conversation lists, unread count, mark-read, refresh, state changes, replies, hide
  and unhide, delete, and drafted-reply approvals (scope `inbox`).
- `FoPost.Ads`: boosts, ads, external ads, boostable posts, connections and sources,
  Meta authorization, status changes, refresh, audiences, targeting search, lead forms,
  and leads (scope `ads`; spending calls also need `publish`).

## [0.1.0] - 2026-08-30

Initial release.

- `FoPost.new/1` client construction with explicit options, application config, and
  `FOPOST_API_KEY` / `FOPOST_BASE_URL` environment fallbacks.
- Resource modules: `FoPost.Posts`, `FoPost.Workspaces`, `FoPost.Accounts`,
  `FoPost.Communities`, `FoPost.Labels`, `FoPost.Webhooks`, `FoPost.Analytics`,
  `FoPost.Automations`, `FoPost.Media`.
- `FoPost.request/4` escape hatch for endpoints the SDK does not wrap.
- Automatic retries on 429, 5xx, and transport errors, honouring `Retry-After`.
- Webhook signature verification with a constant-time comparison.

[Unreleased]: https://github.com/fopost/fopost-elixir/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/fopost/fopost-elixir/releases/tag/v0.2.0
[0.1.0]: https://github.com/fopost/fopost-elixir/releases/tag/v0.1.0
