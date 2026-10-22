---
id: "0012"
title: Never retry a scheduled job, and make its next run catch up
status: active
created: 2026-09-28
area:
  - analytics
  - backups
  - config
  - contact
  - lib
  - mcp
  - media
  - posts
  - projects
  - record
  - security
  - social
  - tasks
issue: AA-657
amended:
  - AA-823
  - "#140"
  - "#252"
  - "#990"
  - "#926"
  - "#957"
  - "#1114"
  - "#1219"
  - "#1375"
  - "#1469"
  - "#1470"
  - "#1565"
  - "#1772"
  - "#1690"
  - "#1518"
  - "#1237"
tags:
  - sidekiq
  - jobs
  - retries
  - schedule
  - sync-states
  - honeybadger
  - failures
  - check-ins
---

# ADR 0012: Never retry a scheduled job, and make its next run catch up

![Active][status]

## Context

Sidekiq retries a job that raises 25 times, and after that moves it to the dead set. The site runs two kinds of
job. Eleven run on the clock from `config/sidekiq.yml.erb`, from every minute (publishing due posts, sending due
social posts) to once a week (the country database). The rest carry one item in their arguments: a chunk of one
repository's commit walk, a social post for one network, a post whose webmentions go out, a
webmention to verify, a post to cross-post, the agents a commit credits.

A scheduled job holds nothing a later run cannot find again. A per-item job does: drop it, and the item goes with
it.

A scheduled job only heals itself when its operation reads what is left from stored state rather than from the
clock. The rollup did not, and a worker down at 01:00 lost the day for good (AA-485). Retrying was never the fix.
AA-550 kept `retry: false` on the rollup because it now catches up.

A job with `retry: false` that raises goes to neither the retry set nor the dead set. Honeybadger hears of it and
the operator sees nothing else. A job that returns a `Failure` leaves no trace at all unless it writes one down.
That is how the GitHub syncs (AA-308), the country refresh (AA-491) and the rollup (AA-550) each failed without
anyone finding out.

## Decision

**A scheduled job never retries.** Since #990 each subclasses `Blog::ScheduledJob` (`lib/blog/scheduled_job.rb`),
which sets `sidekiq_options retry: false` once, and the worker's schedule spec holds every entry to it: the next run
picks up what this one missed. A job that records a failure in `sync_states` and then raises does both through the
`record_and_raise` of `Record::SyncBookkeeping`, and one that records an exception its operation raised wraps the work
in its `record_crash`, which records it as `crashed` (#1219, moved from the base by #1565). Each scheduled operation
finds its work again on every run. `PostRepo#due_scheduled` and `SocialPostRepo#due_scheduled` take every row due by
now, the commit finder starts from the newest stored commit and every failure recorded against a repository, the
rollup walks every day since its newest rollup and the day before yesterday (#1772), the health sync reads again from
two days before its failure began (#1114), and the reapers delete everything past its time.

**A per-item job retries a few times.** `Blog::Job` sets `retry: 3`, so a job that names no count takes 3 (#1690).
`BackfillRepoCommits` takes 3, as `CreditAgents` has since #926, and
`DeliverSocialPost`, `SendWebmentions`, `VerifyWebmention` and `SyndicatePost` take 5, which three of the specs
size for a network "only briefly down". The first three each raise for the one `Failure` a retry can fix and
finish quietly on the rest, and `DeliverSocialPost` marks the delivery failed once its retries run out. The
commit walk raises for nothing it returns. A GitHub rate limit spends no retry: it `perform_at` the reset time
GitHub gave, a minute from now at the soonest. A GitHub failure records itself in `sync_states` and ends the walk,
and the finder's next run starts it again, so a walk never waits on Sidekiq's retries for GitHub. Its retries
cover only an exception, and a walk whose retries run out stalls until the finder starts it again (ADR 0049).
`BackfillHealth`, which walks Google Health's history 90 days at a time, takes 3 retries and raises for every
`Failure` (#1114). `CheckPostLinksAgain`, which checks one post's links on demand, takes 3 and raises for nothing
it returns, since the nightly run checks the same links again (#1469). `CheckShortLinkAgain` does the same for one
short link's destination (#1470).

**A scheduled failure the operator has to act on goes to `sync_states`,** where Today shows it with its reason.

| Scheduled job | On failure |
| --- | --- |
| `BackUpDatabase`, `RefreshCountryDatabase`, `RollUpAnalytics` | Record in `sync_states`, then raise |
| `RefreshProjects`, `SyncCalendar`, `SyncContacts`, `SyncGmail`, `SyncHealth`, `SyncIssues` | Record a `Failure`; record an exception, then raise |
| `RollOverSprint`, `QueueHeldFollowUps`, `QueueHeldWebmentions`, `QueueHeldTitleFetches`, `QueueHeldBackfills`, `CheckPostLinks`, `RollUpTiming`, `RerenderPosts` | Raise |
| `ImportCommits`, `ImportPullRequests` | Record in `sync_states` |
| `ReapSyncStates`, `RefreshSocialEngagement`, `PublishDuePosts`, `SendDueSocialPosts`, `ReapExpiredCredentials`, `ReapWebmentionReceipts`, `SweepPhotos`, `PruneAccessRecords`, `ReapSpamMessages` | Drop it |

The table took in the jobs that came after it in #957. `SyncIssues` runs twice on the schedule, as `sync_issues`
for GitHub and `sync_linear_issues` for Linear, and skips a provider with no client set up.

`BackUpDatabase` logs a warning on `:not_configured` and `RefreshCountryDatabase` stays quiet on it, since the site
may run with no backup store or MaxMind key. `ImportCommits`, `ImportPullRequests` and `SyncIssues` drop
`:lock_busy`, since another run holds the lock. An exception none of them catch still raises from any job and
reaches Honeybadger.

**A Honeybadger check-in shows a run that never happened** (#1375). Neither `sync_states` nor Honeybadger's error
reports hear of a run that never starts: a worker that fails to boot, or a schedule that skips a run, since
sidekiq-scheduler does not replay one. The `Blog::JobCheckIn` Sidekiq middleware sends each job's own check-in
after a run that finishes, and none after one that raises, so Honeybadger alerts when a check-in comes late. It
sits outside `Blog::JobConnection` and `Blog::JobTimer` (#1518), so the call holds no connection and stays out of
the job's timing. It looks the check-in up in `honeybadger.check_ins` under the job's name and its arguments,
such as `publish_due_posts` or `sync_issues_linear`, and each comes from a `HONEYBADGER_CHECK_IN_<NAME>` variable.
A job with none set runs as before. The worker's schedule spec holds every entry to a name in that list. The owner
makes each check-in and its schedule in Honeybadger by hand.

## Alternatives

**An alert inside the app.** It cannot fire while the app or the worker is down, which is when it matters most.

**Sidekiq's default of 25 retries.** For a scheduled job a retry repeats the work the next run does anyway. It
does not rescue an operation that reads its work from the clock. That operation has to catch up instead.

## Consequences

A scheduled job's rule sits in its operation, not in Sidekiq. A new scheduled job has to read what is left from
stored state, or a failed run is lost with no retry to cover it.

The weekly country refresh waits a week after a failure. While `tmp/maxmind` holds no database, as in a fresh
checkout, every visit is stored with no country until a Wednesday run works.

Five retries on Sidekiq's backoff last under ten minutes, so a network down for longer loses the send. A social
post then shows the delivery failed. A webmention send, a verify and a cross-post leave only Honeybadger's
reports.

`RefreshSocialEngagement` leaves no trace anywhere. It drops each network error and rests on the next run trying
again, so an error that repeats every night stays unseen. `ReapSyncStates` records a GitHub refusal or the page
limit under the commits sync (#1237), but leaves a missing token for the commit import to report.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
