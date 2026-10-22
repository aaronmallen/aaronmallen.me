---
id: "0185"
title: Keep a failed job's error on its performance_jobs row
status: active
created: 2026-10-17
area:
  - lib
  - db
  - performance
  - admin
issue: "#1735"
tags:
  - performance
  - jobs
  - sidekiq
  - cron
  - errors
  - failures
  - retention
---

# ADR 0185: Keep a failed job's error on its performance_jobs row

![Active][status]

## Context

Spec #1722 shows each cron entry's last run, and an entry whose last run failed shows the error's class and
message. Scheduled jobs never retry ([ADR 0012][0012]), so a run that raises reaches neither the retry set nor the
dead set. Only Honeybadger hears of it, and `performance_jobs` ([ADR 0162][0162]) gets a row with outcome `failed`
and no error text.

`Blog::JobTimer` already writes that row for every job run, after the job finishes or raises.

## Decision

**A failed run keeps its error's class and message on its `performance_jobs` row.** The table gains two nullable
columns for them. `Blog::JobTimer` fills both when the job raises and leaves both empty when it succeeds. The
`performance` slice records and reads them with the rest of the row, and the admin reads a cron entry's last error
from its latest row.

**A scheduled job's row also keeps its schedule key**, in a nullable `schedule_key` column. Two cron entries can
share a class and differ only by args, as `sync_issues` and `sync_linear_issues` share `Tasks::Jobs::SyncIssues`.
`Blog::JobTimer` fills the column from `Blog::ScheduledJob.check_in_name` and the payload's args, the same name
`Blog::JobCheckIn` sends Honeybadger, so it is unique per entry. Other jobs leave it empty. An index on
`(schedule_key, occurred_at)` finds each entry's latest row.

## Alternatives

**A table of its own for job failures.** It would hold a second row for a run `performance_jobs` already holds, and
the two would need keeping in step.

## Consequences

The cron panel reads a run's error from the same row as its outcome and duration, and each entry reads its own
row even when another entry runs the same class. The migration that adds the column fills it on older rows of
every class that only one entry runs, from a class to key list written into it, which a spec checks against the
schedule. The two `Tasks::Jobs::SyncIssues` entries cannot be told apart on older rows, so they show no last run
until they run again.

Errors share the 30 day retention of raw timing rows, and the daily rollups do not keep them. A cron entry whose
last failure is more than 30 days old shows no error.

Only a raise counts. A job that returns a `Failure` without raising writes outcome `succeeded` and no error, so it
still looks like a success.

`Blog::JobTimer` times every job, not only scheduled ones, so every failed job keeps its error, whether or not
anything shows it.

[0012]: 0012-never-retry-a-scheduled-job-and-make-its-next-run-catch-up.md
[0162]: 0162-keep-request-job-and-page-load-timing-in-a-performance-slice.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
