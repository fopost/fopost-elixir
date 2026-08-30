# Changelog

All notable changes to this project are documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/fopost/fopost-elixir/releases/tag/v0.1.0
