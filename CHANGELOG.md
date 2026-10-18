# Changelog

All notable changes to this project are documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `FoPost.Ads` pixels: `pixels/2`, `create_pixel/2`, `pixel/3`, `update_pixel/3`,
  `share_pixel/3`, `pixel_stats/3`, and `event_match_quality/3` (scope `ads`).
- `FoPost.Ads.send_pixel_conversions/3`: the Conversions API send with a required
  `Idempotency-Key`; a replay answers `replayed: true`. `conversion_batches/2` lists the
  stored uploads with their hashed events.
- `FoPost.Ads` custom conversions: `custom_conversions/2`, `create_custom_conversion/2`,
  `custom_conversion/3`, `update_custom_conversion/3`, and `delete_custom_conversion/3`.
- `FoPost.Ads.upload_conversions/2` accepts `:idempotency_key` and the new per-event
  fields (`eventId`, `actionSource`, `sourceUrl`, `externalId`, `clientIpAddress`,
  `clientUserAgent`, `clickId`, `browserId`, `contentIds`).
- `FoPost.Client.request/4` accepts `:headers` for extra request headers.

### Changed

- `FoPost.Ads.upload_conversions/2` answers a `FoPost.ConversionUploadResult` (`:id`,
  `:accepted`, `:event_count`, `:replayed`) instead of the accepted count alone.

## [0.4.0] - 2026-10-18

### Added

- `FoPost.Queue`, the posting queue: `list_slots/2`, `create_slot/2`, `update_slot/3`,
  `delete_slot/2`, `next/3` and `preview/3`, with `FoPost.QueueSlot`, `FoPost.QueueMove`
  and `FoPost.QueueSlotDeletion`. `FoPost.Posts.create/2` and `update/3` take
  `schedule: "queue"` to drop a post into the next free slot (scope `posts`).
- `FoPost.Posts.unpublish/2` takes a published post down from every network it is live
  on, answering a `FoPost.UnpublishResult` with one `FoPost.UnpublishDelivery` per
  network (scope `publish`).
- `FoPost.ConnectSessions.create/2` and `get/2`, hosted connect links your own users open
  to connect an account, with `FoPost.ConnectSession` and
  `FoPost.ConnectSessionBranding` (scope `accounts`).
- `FoPost.Webhooks.deliveries/3`, `delivery/3` and `redeliver/3` read a subscription's
  delivery log and send an attempt again, with `FoPost.WebhookDelivery`.
- `FoPost.Automations.versions/3`, `version/3` and `restore_version/3`, with
  `FoPost.AutomationVersion`, `FoPost.AutomationVersionNodeRef`, `FoPost.WorkflowGraph`,
  `FoPost.WorkflowNode`, `FoPost.WorkflowEdge` and `FoPost.AutomationRestore`.
- `FoPost.Logs.list/2` reads the request log with the window's totals, answering a
  `FoPost.LogPage` of `FoPost.LogEntry` rows and a `FoPost.LogSummary` (scope
  `workspaces`).
- `FoPost.Analytics.inbox/2` reports inbox volume, reply rate and response time as a
  `FoPost.Analytics.InboxAnalytics` (scope `analytics`).
- Every function that builds its path from a helper now names the API operation it wraps
  in its documentation.

## [0.3.0] - 2026-10-18

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
- `FoPost.Blog.suggest_seeds/3` suggests about ten search terms from the blog goal and
  topics; pass `:seeds` to refine and `:prompt` to steer. Spends AI credits.
- `FoPost.Blog.submit_article/3` moves a draft, failed or rejected article to
  `"in_review"`.
- `FoPost.BlogSettings` gains `:goal`, `:focus_topics`, `:avoid_topics` and `:plan_run`
  (`FoPost.BlogPlanRun`), and `update_settings/3` takes the first three.
  `FoPost.BlogKeyword` gains `:fit_reason`, and article statuses gain `"in_review"`.
- `FoPost.Whatsapp` for a WhatsApp Business connection: the business profile
  (`profile/2`, `update_profile/3`, `request_display_name/3`, `set_username/3`),
  message templates including the platform's own library (`templates/3`,
  `create_template/3`, `import_template/3`, …), groups, blocking, commerce settings
  and flows (`create_flow/3`, `upload_flow_json/4`, `publish_flow/3`,
  `flow_responses/2`, …), plus `account_events/2`. All need the `accounts` scope.
- `FoPost.Whatsapp.create_sandbox_session/2` and `sandbox_sessions/2` invite a tester
  to the platform-owned WhatsApp test number. Inviting sends a template, so it needs
  the `publish` scope.
- `FoPost.Media.limits/2` answers a `FoPost.UploadLimits`: the largest file the
  account may upload by any route, the multipart ceiling per file, the files per call,
  the accepted types, and the next tier.
- `FoPost.Posts.create/2` and `update/3` take `:files`, a list of paths or maps of
  `:filename`, `:mime_type`, and `:path` or `:data`. Files within the multipart ceiling
  travel with the post in one request; larger ones are direct-uploaded first and attached
  to the first content block.
- `FoPost.Media.presign/2` takes `:folder_id`, `:origin`, `:brand_role`,
  `:brand_voice_id`, and `:person_consent`, and `FoPost.PresignedUpload` carries
  `:max_file_bytes`.
- `FoPost.Media.upload_direct/6` streams a file given as `{:file, path}` instead of
  holding it in memory, and takes the optional presign fields.
- An oversize file is a `413` with `code: "file_too_large"`; `error.body` carries
  `max_file_bytes`, `file_bytes`, and `upgrade_url`.
- `FoPost.Blog`, articles for a website rather than posts for a network: `settings/2`,
  `update_settings/3`, `rotate_website_secret/2`, `test_website/2`, `list_keywords/3`,
  `plan_keywords/3`, `add_keyword/3`, `update_keyword/4`, `delete_keyword/3`,
  `list_articles/3`, `request_article/3`, `get_article/3`, `update_article/4`,
  `regenerate_article/3`, `publish_article/3`, `reject_article/3`, `delete_article/3`,
  with `FoPost.BlogSettings`, `FoPost.BlogKeyword`, `FoPost.BlogArticle`,
  `FoPost.BlogArticleFull`, `FoPost.BlogArticleImage` and `FoPost.BlogWebsiteTest`.
  Planning, requesting and regenerating need `ai`; publishing needs `publish`.
- `FoPost.Webhooks.verify/4` verifies a delivery from its raw body and request headers,
  preferring the timestamped `X-FoPost-Signature-256` with a 300 second tolerance and
  falling back to `X-FoPost-Signature` only when no timestamp header is present, plus
  `timestamped_signature/3` for testing a handler. `article.published` joins `events/0`,
  and `FoPost.BlogArticlePublished` types its payload.
- `FoPost.InboxItem` carries `:moderation_status` (the platform's own state for
  a comment: `"published"`, `"held"`, `"spam"`, `"rejected"`), and
  `FoPost.InboxAccount` carries `:reconnect_required` for an account connected
  before the inbox asked for a permission it needs.
- `FoPost.Broadcasts` — one message into every conversation the workspace already
  has with a segment of its contacts: `list/2`, `get/2`, `create/2`, `update/3`,
  `delete/2`, `send/2`, `cancel/2`, `recipients/3`. Reading needs `inbox`; `send/2`
  and `cancel/2` also need `publish`.
- `FoPost.Sequences` — a series of messages on a delay: `list/2`, `get/2`,
  `create/2`, `update/3`, `delete/2`, `enroll/3`, `unenroll/3`, `enrollments/3`.
  `enroll/3` and `unenroll/3` need `publish`.
- Both honour each network's messaging window server-side. Messenger and Instagram
  take a business-initiated message only within 24 hours of the contact's last one,
  so recipients outside it come back skipped with `"window_closed"` and nothing is
  attempted — the number sent is often lower than the audience.
- `FoPost.Contacts` — the people behind the inbox: `list/2`, `get/2`, `create/2`,
  `update/3`, `delete/2`, `conversations/3` and `import/3`, plus `list_fields/2`,
  `create_field/3`, `update_field/3` and `delete_field/2` for the columns a workspace
  keeps about a person (scope `inbox`).
- `FoPost.Contacts.conversation_analytics/2` — inbox volume and reply time per thread
  (scope `analytics`). Each row's `:key` is an opaque handle for the thread rather than
  the id or handle the inbox groups on.
- Meta messaging settings on `FoPost.Accounts`: `ice_breakers/2`, `set_ice_breakers/3`, and
  `delete_ice_breakers/2` (Facebook Pages and Instagram), plus `persistent_menu/2`,
  `set_persistent_menu/3`, `delete_persistent_menu/2`, `greeting/2`, `set_greeting/3`, and
  `delete_greeting/2` (Facebook Pages). A network without a field answers 400.
- `FoPost.Accounts.webhook_subscription/2` reports whether the network is still delivering
  events for an account, and `resubscribe_webhook/2` puts a lapsed subscription back.
- `FoPost.Inbox.handover/4` passes a Messenger thread to another Meta app, or takes it back
  when no `:app_id` is given (scope `inbox`, plus `publish`).
- `FoPost.Accounts.slack_channels/2`, `slack_members/2`, `slack_identity/2`, and
  `update_slack_identity/3` read a Slack account's channels and workspace members and set
  the name and icon it posts under; a `nil` option clears a field (scope `accounts`).
- The Discord bot surface on `FoPost.Accounts`: `discord_channels/2`,
  `switch_discord_channel/3`, `discord_identity/2`, `update_discord_identity/3`,
  `discord_pins/2`, `delete_discord_message/3`, `pin_discord_message/3`,
  `unpin_discord_message/3`, `crosspost_discord_message/3`, `create_discord_thread/4`,
  `send_discord_direct_message/4`, `discord_events/2`, `discord_event/3`,
  `create_discord_event/3`, `update_discord_event/4`, `delete_discord_event/3`,
  `discord_members/3`, `discord_member/3`, `discord_roles/2`, `create_discord_role/3`,
  `update_discord_role/4`, `delete_discord_role/3`, `add_discord_member_role/4` and
  `remove_discord_member_role/4` (scope `accounts`, plus `publish` for anything that
  posts). A connection made with a webhook answers `409 webhook_connection`.
- `FoPost.DiscordChannel` carries `:can_post`, false when a channel permission in
  Discord shuts the bot out; `switch_discord_channel/3` answers
  `409 channel_not_writable` for one.
- Per-network extras on `FoPost.Accounts`, all under the `accounts` scope: Pinterest
  boards (`pinterest_boards/2`, `create_pinterest_board/3`), YouTube playlists and
  captions (`youtube_playlists/2`, `create_youtube_playlist/3`,
  `set_default_youtube_playlist/3`, `youtube_captions/3`, `upload_youtube_captions/4`,
  `youtube_transcript/3`), Bluesky post languages (`bluesky_languages/2`,
  `set_bluesky_languages/3`), TikTok creator info, music and place search and video
  lookup (`tiktok_creator_info/2`, `tiktok_music/4`, `tiktok_locations/4`,
  `tiktok_video_lookup/3`), Instagram audio, publishing limit and stories
  (`instagram_audio/3`, `instagram_publishing_limit/2`, `instagram_stories/3`,
  `instagram_story_insights/3`), and LinkedIn mentions (`linkedin_mentions/3`).
- `FoPost.Accounts.reddit_subreddits/2`, `reddit_subreddit_rules/3`, `reddit_flairs/3`, and
  `set_reddit_default_subreddit/3` read the subreddits a Reddit account is in, a
  subreddit's rules and post flairs, and set where posts go when a post names none (scope
  `accounts`).
- `FoPost.Validate.subreddit/2` answers whether a subreddit exists and takes a post from an
  account, before a post exists (scope `posts`).
- `FoPost.Inbox.vote/3` votes an item up or down, or takes the vote back with `"none"`
  (scopes `inbox` and `publish`).
- `:reconnect_required` on `FoPost.Account`, and `:vote` and `:can_vote` on an inbox item.

### Changed

- `FoPost.Inbox.delete/2` also deletes our own replies.
- Signature comparison in `FoPost.Webhooks` now uses `:crypto.hash_equals/2`.
- Direct uploads no longer stop at 50 MB; the ceiling is the account's `limits/2`.
- `FoPost.Blog.plan_keywords/3` no longer fills the calendar: results land as
  `"suggested"` keywords, and setting one to `"planned"` picks it for the next free
  date. `:review_hold_days` is now the days before its planned date that a picked
  keyword starts being written.
- `FoPost.Blog.publish_article/3` and a `:publish_at` on a draft answer `409` until the
  article is submitted with `submit_article/3`.

### Removed

- **Breaking:** `:auto_publish` is gone from `FoPost.BlogSettings` and
  `FoPost.Blog.update_settings/3`. Nothing publishes without approval.

### Fixed

- `FoPost.Blogs.delete_article!/4` returns `:ok` on success instead of raising.

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
