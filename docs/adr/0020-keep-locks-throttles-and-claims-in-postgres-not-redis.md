---
id: "0020"
title: Keep locks, throttles and claims in Postgres, not Redis
status: active
created: 2026-09-28
area: [lib, record, contact, mcp, analytics, social, tasks]
issue: AA-644
amended: [AA-823, "#200"]
tags: [postgres, redis, advisory-lock, throttle, upsert, concurrency, sidekiq]
---

# ADR 0020: Keep locks, throttles and claims in Postgres, not Redis

![Active][status]

## Context

Several writers race. Two commit imports can start at once, one from the schedule and one from **Import now**
(AA-303). A burst of contact messages, beacon views, webmentions or
client sign-ups can all read a count before any of them writes (AA-490, AA-717). The midnight job and a read of Today
can both start the same sprint (AA-358). Two runs of the social send can both pick up one network (AA-621).

Redis is there, on the NAS, for Sidekiq. It holds the queue and the schedule and nothing else. Only the Sidekiq
provider, `config/providers/sidekiq.rb`, connects to it.

## Decision

Every guard against a race or a flood lives in Postgres, beside the rows it guards, in one of three shapes.

**A session advisory lock, for a run that must not overlap itself and can skip a turn.**
`Record::Relations::SyncStates#with_advisory_lock` holds the gateway's connection and takes `pg_try_advisory_lock`.
When another run holds it, `Record::Repos::CommitRepo#with_import_lock` hands back `Failure(:lock_busy)`,
`Record::Jobs::ImportCommits` drops the tick, and the next one catches up.

**A transaction advisory lock around a count and a write, for a step that must not run twice at once.** The throttle
claims on `Contact::Relations::Messages`, `MCP::Relations::OAuthClients`, `Analytics::Relations::AnalyticsEvents` and
`Social::Relations::WebmentionReceipts` open a transaction, take `pg_advisory_xact_lock`, count and insert. The lock
ends with the commit, and a row lock would hold nothing before a sender's first row.

**A unique index with `ON CONFLICT`, for a claim whose row is the state.** `Tasks::Relations::Sprints#insert_missing`
inserts on `sprint_date` and the loser does nothing. `Social::Relations::SocialPostDeliveries#claim` inserts on
`(social_post_id, network)` and takes a row again only when no job has touched it since `stale_before`.

A new lock key follows the ones beside it. A lock on a sender takes two keys, `hashtext` of the table and `hashtext`
of the sender. A lock on a whole table takes the table key alone. A lock on a job takes a bare integer, and
`CommitRepo` holds the one in use, `IMPORT_LOCK`.

## Alternatives

**Redis keys and counters.** Sidekiq already talks to Redis, and `INCR` with an expiry is the usual throttle. A count
in Redis and a row in Postgres cannot commit together, and rows that are the count have to be counted and written in
one step, or a burst gets through. The rows are also the record of who sent what, so the count needs no second copy
to prune. AA-621 shows what two stores cost: a claim in Postgres and a job in Redis, with nothing between them when
Redis drops.

**A Sidekiq unique-job gem.** It refuses a second copy of a job with the same arguments. Most of these races are not two
copies of one job: a request against a request, or a read of Today against the midnight job. The one race it fits, the
commit import, already had a lock in Postgres (AA-303).

## Consequences

A crash leaves no lock behind. Postgres frees a session lock when its connection closes and a transaction lock
when the transaction ends.

A session lock holds its connection for the whole run. AA-309 sized the pool with `SPARE_CONNECTIONS` for it, in
`Blog::Providers::DBProvider`.

A claim can still strand. `Social::Jobs::SendDueSocialPosts` claims a delivery and then calls `perform_async`. If Redis
fails between the two, the delivery waits `STALLED_AFTER`, fifteen minutes, before a later run claims it again. A
delivery that holds an error or has failed is not claimed again.

Each site picks its key by hand, and nothing checks that two sites picked the same one. Postgres keeps the one-key
and two-key forms apart, so a job lock cannot meet a lock on a sender. The table-wide webmention and contact locks share
the one-key space with `IMPORT_LOCK`, and two tables whose names hash alike would share a lock.

A throttle lock on a sender makes a flood wait on itself while every other sender goes straight through. The
webmention and contact caps across all senders lock the whole table, so a flood there makes every sender wait.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
