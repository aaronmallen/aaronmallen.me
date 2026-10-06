---
id: "0011"
title: Run jobs on Sidekiq in one worker that boots the app
status: active
created: 2026-09-28
area: [config, lib, activity, admin, analytics, contact, mcp, posts, projects, public, record, social, suggestions,
  tags, tasks]
issue: AA-649
amended: [AA-821]
tags: [sidekiq, sidekiq-scheduler, redis, jobs, queues, schedule, worker]
---

# ADR 0011: Run jobs on Sidekiq in one worker that boots the app

![Active][status]

## Context

Hanami ships no job layer, and the site has work that must not wait on a request: eleven jobs that run on the clock,
and jobs that carry one item, such as a repository to import or a post to cross-post (ADR 0012).

Redis already runs for Sidekiq: on the NAS in production (ADR 0006), and in `.config/compose.yml` in development.
It holds the queue and the schedule and nothing else (ADR 0020).

Work crosses slices. `Posts::Operations::PublishPost` enqueues `Social::Jobs::SyndicatePost` and
`Social::Jobs::SendWebmentions`, and `Posts::Operations::SavePost` enqueues the second (ADR 0003). The posts code
that publishes a post cannot run where the social slice has not loaded.

AA-310 asked that a walk through old commits never delay the daily sync: "with both queued, new commits import
first". Since AA-820, one walk per repository reads both new and old commits (ADR 0049).

## Decision

We run every job on Sidekiq, in one worker that boots the whole app.

- **A job lives in the slice that owns its work**, under `slices/<slice>/jobs`, and subclasses `Blog::Job`
  (`lib/blog/job.rb`), which mixes in `Sidekiq::Job` and `Dry::Monads[:result]`.
- **Its schedule lives in `config/sidekiq.yml.erb`**, under `:scheduler:`, where sidekiq-scheduler reads it. Each
  cron runs in `Blog::TimeZone::NAME` (ADR 0018).
- **One worker runs them all.** `scripts/dev/worker` starts Sidekiq with `config/sidekiq.rb`, which requires
  `hanami/boot`. Booting loads every slice and starts every provider: `:sidekiq` for the server's Redis options,
  and `:honeybadger` for the error handler (ADR 0010).
- **One queue.** Every job takes Sidekiq's `default`. We add a queue only with the job that needs it.
- **Enqueueing needs the `:sidekiq` provider started.** Only its `start` in `config/providers/sidekiq.rb` calls
  `Sidekiq.configure_client` and `Sidekiq.configure_server`, and each skips the process it does not belong to. The
  web process and the worker boot, so they have it. A process that only prepares must start the provider before
  it enqueues.

## Alternatives

**A queue in a Postgres table.** A job and its claim could then commit together, which Redis cannot offer
(ADR 0020). It lost because Redis already runs for Sidekiq, and sidekiq-scheduler supplies the cron.

**One worker per slice**, with `hanami/prepare` and `HANAMI_SLICES`, as the Hanami guide ("Slice loading")
suggests. It lost because posts enqueues social jobs. A worker that loads posts alone cannot publish a post, so the
slices cannot run in separate workers.

**A separate queue for walks through old commits**, weighted or in strict order, which AA-310's wording asks
for. It lost when one walk took over both new and old commits (AA-820): there is no second kind of commit job to
rank. AA-310 feared an old walk using up the GraphQL points the sync needs, and a chunk already stops under a
reserve of 1,000 points (ADR 0049).

**Keep the `critical` and `low` queues.** No job ever used either, so we removed them.

## Consequences

One process and one systemd unit run every job, and any job may enqueue another slice's job.

The worker loads admin, public and every other slice, even those with no job, and holds them all in memory on the Pi.

One queue promises less than AA-310 first asked. The first run on an empty database queues a walk for every
repository, so any other job waits its turn behind those chunks. The same threads, 5 in development and 10 in
production, serve every job, so a running chunk holds its thread until it ends.

`hanami console` prepares unless you pass `--boot`. A `perform_async` typed there goes to Sidekiq's own default
Redis, with no user and no password, which the compose Redis refuses since it turns the `default` user off. Start
the console with `--boot`, or call `Hanami.app.start(:sidekiq)` first.

A job sits in Redis and its claim in Postgres, and nothing commits the two together. ADR 0020 covers what that
costs.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
