# Changelog

All notable changes to this project are documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `FoPost.InboxItem` carries `:moderation_status` (the platform's own state for
  a comment: `"published"`, `"held"`, `"spam"`, `"rejected"`), and
  `FoPost.InboxAccount` carries `:reconnect_required` for an account connected
  before the inbox asked for a permission it needs.
- `FoPost.Accounts.slack_channels/2`, `slack_members/2`, `slack_identity/2`, and
  `update_slack_identity/3` read a Slack account's channels and workspace members and set
  the name and icon it posts under; a `nil` option clears a field (scope `accounts`).

## [0.3.0] - 2026-09-19

### Added

- `FoPost.Validate`: `post/2`, `length/2`, and `media/2` check content, text length, and a
  media URL against platform rules without creating a post (scope `posts`).
- `FoPost.AccountGroups`: `list/2`, `get/2`, `create/2`, `update/3`, `delete/2`, and
  `set_members/3` (scope `accounts`).
- `FoPost.Accounts.rename/3` and `move/3`, a `:group_id` filter on `list/2`, and
  `:platform_name` on `FoPost.Account`.
- `FoPost.Posts.create/2` accepts `:account_group_id`, which can stand in for `:accounts`.
- `FoPost.Accounts.create_telegram_connect_code/2` and `telegram_connect_status/2` connect a
  Telegram chat with a one-time code; `telegram_bot_commands/2`,
  `set_telegram_bot_commands/3`, and `delete_telegram_bot_commands/2` manage the bot's
  command menu in a connected chat (scope `accounts`).
- `FoPost.Inbox`: `like/2`, `unlike/2`, `pin/2`, `unpin/2`, `react/3`, `edit_comment/3`,
  `start_conversation/2`, and `set_typing/3` (scope `inbox`, plus `publish`).
- `FoPost.Inbox.reply/3` accepts `:media_ids` and `:quick_replies`; `:text` is optional
  when `:media_ids` is given.
- `FoPost.InboxItem`: `:liked`, `:pinned`, `:reaction`, `:edited_at`, `:can_like`,
  `:can_pin`, `:can_edit`, `:can_react`, `:can_send_media`, `:can_quick_reply`, and
  `:can_private_reply`. `FoPost.InboxAccount`: `:can_start_conversation`.
- `FoPost.Ads` campaign tree: `account_tree/3`, and create, get, update, delete, and
  duplicate for campaigns, ad sets, and network ads, plus `bulk_set_status/2` (scope `ads`;
  writes also need `publish`).
- `FoPost.Ads` creatives (`creatives/2`, `create_creative/2`, `get_creative/3`,
  `delete_creative/3`), audiences (`get_audience/3`, `update_audience/3`,
  `delete_audience/3`, `add_audience_users/3`), `estimate_reach/2`, `insights/2`, and
  `ad_insights/3`.
- `FoPost.Ads` lead forms and leads: `get_lead_form/3`, `archive_lead_form/3`,
  `leads_feed/2` (cursor paginated), `lead_pages/2`, `subscribe_lead_page/2`, and
  `unsubscribe_lead_page/3`.
- `FoPost.Ads.create/2` accepts `:url_tags`.

### Changed

- `FoPost.Inbox.delete/2` also deletes our own replies.

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

[0.3.0]: https://github.com/fopost/fopost-elixir/releases/tag/v0.3.0
[0.2.0]: https://github.com/fopost/fopost-elixir/releases/tag/v0.2.0
[0.1.0]: https://github.com/fopost/fopost-elixir/releases/tag/v0.1.0
