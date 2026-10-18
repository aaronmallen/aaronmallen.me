---
id: "0138"
title: Read dead jobs from the Sidekiq dead set in an activity query
status: active
created: 2026-10-09
area: [activity, admin, api]
issue: "#869"
amended: ["#1731", "#1732", "#1733", "#1734", "#1776"]
tags: [activity, attention, sidekiq, redis, jobs, dead-set]
---

# ADR 0138: Read dead jobs from the Sidekiq dead set in an activity query

![Active][status]

## Context

The spec in #865 puts jobs that have run out of retries on the attention card and in `list_attention`, with their
name, when they died and their error. I retry or discard them from the card.

[ADR 0095][0095] builds the attention list from the `attention` view in Postgres, read through an `activity` query
that `admin` and `api` import. Sidekiq keeps a dead job in its dead set, in Redis ([ADR 0011][0011]), so no view can
join it.

## Decision

An `activity` query reads Sidekiq's dead set through `Sidekiq::DeadSet` and hands back its rows beside the rows
`stalled` reads from the view. `activity` exports it, and `admin` and `api` import it the way they import the
stalled list, so the card and `list_attention` read the same dead jobs. It builds each one as the `SetJob` the jobs
tab builds, and the card links the rest to the tab's dead set rather than to a page of its own.

Sidekiq stays the only record of a dead job. Retry and discard act on the dead set itself, so a job leaves the card
when it leaves the set. One `activity` operation, `act_on_set_job`, does every action on a job in a set, from the card
and from the jobs tab: run now and delete on a scheduled job, retry now, kill and delete on a retry, and retry and
discard on a dead job. Each finds the job by its jid and takes it out of its set through the set's own `remove_job`,
which hands over the job only when it was still there. Then it pushes the job to its queue, moves it to the dead set
or drops it. The card's retry and discard post to the tab's route, so a job that left its set first, even between the
lookup and the act, changes nothing, and a toast says so. Each row also carries one button on hover, retry or run now,
as each cron row does.

`activity` reads every other Sidekiq set the same way. The `:sidekiq` provider registers each read from `sidekiq/api`
as a `sidekiq.*` key: stats and their daily history, processes, work, queues, retries and scheduled, and
sidekiq-scheduler's next run times and paused states. `sidekiq.queue_jobs` reads one page of a queue's jobs, oldest
first, and `sidekiq.set_jobs` one page of the retry, dead or scheduled set, both through `Sidekiq::Paginator`. An
`activity` query builds the jobs tab on Settings from them, with the time the last job finished, which it reads
through the `performance` slice. The tab lists retries and scheduled jobs soonest first and dead jobs newest first,
and opens one job from any of the three sets by its jid. A second query builds the tab's cron schedule
from `config/sidekiq.yml.erb`, the scheduler's keys and each entry's newest `performance_jobs` row. Every read
rescues `RedisClient::Error`, so a Redis outage shows as unknown, never as zero.

Two `activity` operations act on a cron entry from the tab, as `act_on_set_job` acts on a job. Run now enqueues
the entry's class with its args, as the scheduler does. Pause and enable write the entry's `enabled` flag through
`sidekiq.schedule_state`, which calls sidekiq-scheduler's own `RedisManager.set_job_state`. The scheduler reads that
flag on every tick and never clears it on boot, so a pause holds across restarts and deploys. With Redis down the tab
offers none of these actions, and a post that finds Redis down changes nothing and says so.

## Alternatives

**Copy each dead job into Postgres from a death handler.** A table the `attention` view joins would keep
[ADR 0095][0095]'s one view and its snoozes. It lost because each job would live twice, and the copy drifts from
Sidekiq whenever a job leaves the set some other way: Sidekiq prunes it, or someone retries it from a console.

## Consequences

The attention list and the jobs tab now read Redis as well as Postgres, through the client the `:sidekiq` provider
configures. The card and `list_attention` need Redis up, and a spec that covers dead jobs has to put them in the dead
set. CI runs no Redis, so specs stub each read with the fakes in `spec/support/sidekiq.rb`, or replace the
scheduler's keys where they read them.

Dead jobs stay out of the `attention` view, so `listed?` never finds them and they cannot be snoozed. Retry and
discard take that place.

Sidekiq prunes the dead set on its own terms, by count and by age, so an old dead job leaves the card without
anyone acting on it.

A job with `retry: false` never reaches the dead set, so the scheduled jobs that [ADR 0012][0012] keeps from
retrying never show as dead jobs, and a failed sync among them shows through its sync state as before.
`Record::Jobs::BackfillRepoCommits` does retry and records a sync state too, so the card has to drop its dead job
when the sync failure already shows.

[0011]: 0011-run-jobs-on-sidekiq-in-one-worker-that-boots-the-app.md
[0012]: 0012-never-retry-a-scheduled-job-and-make-its-next-run-catch-up.md
[0095]: 0095-build-the-stalled-list-in-the-activity-slice-and-keep-snoozes-in-attention-snoozes.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
