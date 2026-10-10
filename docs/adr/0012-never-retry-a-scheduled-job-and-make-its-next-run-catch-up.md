---
id: "0012"
title: Never retry a scheduled job, and make its next run catch up
status: active
created: 2026-09-28
area: [analytics, config, lib, mcp, media, posts, projects, record, social, tasks]
issue: AA-657
amended: [AA-823, "#140", "#252"]
tags: [sidekiq, jobs, retries, schedule, sync-states, honeybadger, failures]
---

# ADR 0012: Never retry a scheduled job, and make its next run catch up

![Active][status]

## Context

Sidekiq retries a job that raises 25 times, and after that moves it to the dead set. The site runs two kinds of
job. Eleven run on the clock from `config/sidekiq.yml.erb`, from every minute (publishing due posts, sending due
social posts) to once a week (the country database). The rest carry one item in their arguments: a chunk of one
repository's commit walk, a social post for one network, a post whose webmentions go out, a
webmention to verify, a post to cross-post.

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

**A scheduled job never retries.** Each sets `sidekiq_options retry: false`, and each spec gives the reason in its own
words: the next run picks up what this one missed. Each scheduled operation finds its work again on every run.
`PostRepo#due_scheduled` and `SocialPostRepo#due_scheduled` take every row due by now, the commit finder starts from the
newest stored commit and every failure recorded against a repository, the rollup walks every day since its newest
rollup, and the reapers delete everything past its time.

**A per-item job retries a few times.** `BackfillRepoCommits` takes 3, and
`DeliverSocialPost`, `SendWebmentions`, `VerifyWebmention` and `SyndicatePost` take 5, which three of the specs
size for a network "only briefly down". The first three each raise for the one `Failure` a retry can fix and
finish quietly on the rest, and `DeliverSocialPost` marks the delivery failed once its retries run out. The
commit walk raises for nothing it returns. A GitHub rate limit spends no retry: it `perform_at` the reset time
GitHub gave, a minute from now at the soonest. A GitHub failure records itself in `sync_states` and ends the walk,
and the finder's next run starts it again, so a walk never waits on Sidekiq's retries for GitHub. Its retries
cover only an exception, and a walk whose retries run out stalls until the finder starts it again (ADR 0049).

**A scheduled failure the operator has to act on goes to `sync_states`,** where Today shows it with its reason.

| Scheduled job | On failure |
| --- | --- |
| `RefreshCountryDatabase`, `RollUpAnalytics` | Record in `sync_states`, then raise |
| `RollOverSprint`, `QueueHeldFollowUps`, `QueueHeldWebmentions`, `CheckPostLinks` | Raise |
| `ImportCommits`, `RefreshProjects` | Record in `sync_states` |
| `ReapSyncStates`, `RefreshSocialEngagement`, `PublishDuePosts`, `SendDueSocialPosts`, `ReapExpiredCredentials`, `ReapWebmentionReceipts`, `SweepPhotos` | Drop it |

`RefreshCountryDatabase` stays quiet on `:not_configured`, since the site may run with no MaxMind key, and
`ImportCommits` drops `:lock_busy`, since another import holds the lock. An exception none of them catch still
raises from any job and reaches Honeybadger.

## Alternatives

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

Two scheduled failures leave no trace anywhere. `ReapSyncStates` drops a GitHub refusal, and
`RefreshSocialEngagement` drops each network error, and both rest on the next run trying again. A refusal that
repeats every night stays unseen.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
