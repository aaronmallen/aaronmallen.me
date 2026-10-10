---
id: "0010"
title: Configure Honeybadger from settings in a provider, not from honeybadger.yml
status: active
created: 2026-09-28
area: [config, lib, mcp]
issue: AA-660
amended: [AA-819, "#237", "#467", "#1012"]
tags: [honeybadger, errors, providers, settings, sidekiq, privacy]
---

# ADR 0010: Configure Honeybadger from settings in a provider, not from honeybadger.yml

![Active][status]

## Context

AA-329 asked for every error to reach Honeybadger: a web request, a Sidekiq job, the webmention endpoint and the MCP
server, most of which fail where nobody watches. It asked for the key to live in settings and never in
`honeybadger.yml`, for nothing to report from development or test, and for the parameters that carry a secret or a
person to be filtered. AA-353 keeps the settings files as the one source of config, with only secrets left to the
environment.

The gem answers `require "honeybadger"` with its own Hanami hook (`honeybadger-6.9.2/lib/honeybadger/init/hanami.rb`).
The hook configures the gem from `honeybadger.yml` and the environment, and mounts its middleware as the app loads.

## Decision

The `:honeybadger` provider (`config/providers/honeybadger.rb`) configures the gem from `settings.honeybadger`
through `Blog::Providers::HoneybadgerProvider.agent`, then calls `load_plugins!` and `install_at_exit_callback`
and registers `honeybadger.agent`. The app requires `honeybadger/ruby`, never `honeybadger`, so the hook never runs.

- **The web process** mounts the gem's `Honeybadger::Rack::ErrorNotifier` in `config/app.rb`, outside
  `Blog::ParamsGuard`. Given no agent, it takes `Honeybadger::Agent.instance` at request time, which the provider
  has configured by then, though `config.middleware.use` runs before the container exists.
- **The worker** gets its error handler from the gem's Sidekiq plugin, which `load_plugins!` registers when the
  provider starts. `config/sidekiq.rb` requires `hanami/boot` so the provider starts. A job that retries reports
  only on its last try, through `attempt_threshold`. A Redis connection error raised on Sidekiq's scheduler thread
  (`sidekiq.scheduler`) reports nothing: the poller logs it and tries again, a short drop never reaches a job, and
  a long one still reports from the processors that fetch work and from whatever enqueues a job.
- **The MCP server** reports what the SDK catches. `MCP::Protocol::Handler#report` sends a tool or prompt error to
  `honeybadger.agent`, since the SDK turns it into a response and no middleware sees it.
- `report_data` is on in production and off elsewhere, unless `honeybadger.report_data` says otherwise.
- `FILTER_KEYS` is a list kept by hand, and `config/app.rb` hands it to the logger's filters too. Honeybadger matches
  each entry as a substring with no regard to case, so `token` covers `refresh_token`. Add a key when a setting
  holding a secret gets a name no entry covers, or when a request carries a credential or a person's details under
  a new name, the way AA-483 added `code` and `state` and AA-531 added `salt`. Private notes count too: #467 added
  `note`, `problem`, `parts`, `markdown` and the people fields.
- The logger alone filters `ip`, the visitor address Hanami's request logger writes on each line. Honeybadger
  already drops the address through `remote_addr` and `x_forwarded_for`, and as a substring `ip` would filter
  `description` and `recipient`.

## Alternatives

**`honeybadger.yml` and the gem's Hanami hook.** It is what `honeybadger install` writes and what AA-329 first
asked for, and it needs no provider. It lost because it puts config in a second file beside the settings, against
AA-353, and AA-329 kept the key out of it by name.

**An explicit `error_handlers` line in `config/sidekiq.rb`.** The worker could then prepare rather than boot. It
lost because the plugin's handler already carries what a bare `Honeybadger.notify` would drop: it skips a job's
early retries against `attempt_threshold`, clears the context between jobs, and turns itself off when reporting is
off. A hand-written handler would copy that code.

## Consequences

Settings are the one source, and a spec can stub them and read the config the agent holds. #1012 dropped the
options hash the provider built first, so the agent sets each value straight onto the gem's config.

`config/sidekiq.rb` must boot, not prepare. The Hanami guides point a worker at `hanami/prepare`. Under it the
provider never starts, the plugin never registers, and every job error goes unreported. No spec would notice:
the suite runs jobs in its own process, never through `config/sidekiq.rb` (AA-819). The record on the Sidekiq
worker (AA-649) covers why it boots the whole app.

`FILTER_KEYS` can drift from what the app handles. `spec/requests/secrets_spec.rb` sends the GitHub callback, the
MCP token exchange, the MCP authorize request, a task, a decision and a visit to the home page, and fails when a
secret, a note or the visitor address they carry reaches the log or an error report. Nothing checks a setting that
holds a secret, or a request that parameter list does not name. A secret passed to a job as a positional argument is
not filtered either. Every job takes ids today.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
