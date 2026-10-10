---
id: "0138"
title: Read dead jobs from the Sidekiq dead set in an activity query
status: active
created: 2026-10-09
area: [activity, admin, api]
issue: "#869"
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
stalled list, so the card and `list_attention` read the same dead jobs.

Sidekiq stays the only record of a dead job. Retry and discard act on the dead set itself, so a job leaves the card
when it leaves the set.

## Alternatives

**Copy each dead job into Postgres from a death handler.** A table the `attention` view joins would keep
[ADR 0095][0095]'s one view and its snoozes. It lost because each job would live twice, and the copy drifts from
Sidekiq whenever a job leaves the set some other way: Sidekiq prunes it, or someone retries it from a console.

## Consequences

The attention list now reads Redis as well as Postgres, through the client the `:sidekiq` provider configures. The
card and `list_attention` need Redis up, and a spec that covers dead jobs has to put them in the dead set.

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
