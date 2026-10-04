---
id: "0105"
title: Dump the database nightly to a private backups bucket and keep the newest 7
status: active
created: 2026-10-03
area: [config, lib, record]
issue: "#396"
tags: [backups, postgres, pg-dump, s3, rustfs, nas, sidekiq, schedule, providers, sync-states, honeybadger]
---

# ADR 0105: Dump the database nightly to a private backups bucket and keep the newest 7

![Active][status]

## Context

Nothing backs up the database. The only fallback is the TrueNAS snapshots of the NAS, which nobody has restored
from, and which hold the disk rather than a clean copy of Postgres. Posts, journal entries, tasks, decisions and
OAuth records exist nowhere else. [ADR 0080][0080] said a lost database comes back from GitHub and the social
networks, but that holds only for what the site syncs in.

Spec #395 settles that a Sidekiq job dumps the database into a private `backups` bucket in RustFS on the NAS and
keeps the newest 7. The owner wants a failure to reach Today and Honeybadger, and wants the dumps on the NAS, where
the rest of the storage lives. The bucket exists. A dump holds OAuth tokens, API tokens and contact messages.

## Decision

**A new `backups` slice owns the work,** with its code under `lib/backups/`. No slice covers operations work today,
and the job answers no route.

**A client and provider reach the bucket,** in the pattern of [ADR 0009][0009]. It reads its own endpoint, bucket
and key from settings, apart from the photo store's. With no settings the site boots, and the client answers
`configured?` false. The key reaches the `backups` bucket and nothing else, and no route on the site reads from it.

**One scheduled job runs at 00:30 each night,** the first free slot: nightly jobs hold 00:00 and the slots from
01:00 to 05:45. It runs `pg_dump` in the custom format, which compresses by default and restores through
`pg_restore`, uploads the dump, then deletes every dump past the newest 7. A run that fails before its upload lands
deletes nothing.

**A failure follows [ADR 0012][0012].** The job never retries, since the next night's run tries again. It records a
failed dump or upload in `sync_states` through the `record` slice, where Today shows it, then raises so Honeybadger
gets it. Without settings it does nothing and reports that it is not configured.

**The dump goes up as it is.** We do not encrypt it, since the bucket stays private on the NAS behind a key that
reaches only that bucket.

**A missed run does not alert.** No Honeybadger check-in watches for the job, for now.

## Alternatives

**A cron job on the NAS.** It needs nothing from the site, but its failures would reach neither Today nor
Honeybadger, which the owner asked for.

**The TrueNAS snapshots alone.** They cost nothing more, but they hold the disk Postgres writes to rather than a
dump, and nobody has restored from one.

**Plain SQL dumps.** They read as text, but take more room unless compressed by hand, and `pg_restore` cannot pick
single tables out of one.

## Consequences

Losing the database now costs at most a day of writes, as long as the NAS survives. The dumps sit on the same NAS
as the database, so a lost NAS takes both, and copies off it stay out of scope.

Anyone with the bucket key, or root on RustFS, can read every token and message the site holds, in the clear.

A worker that is down at 00:30 skips that night's dump and says nothing. Today shows no failure, since no run
failed.

The Pi runs `pg_dump`, which mise does not manage, so the Pi needs one of version 17 or newer to match Postgres on
the NAS. An older one refuses to dump. Each dump also crosses the LAN twice, from the NAS to the Pi and back.

The key has to list the bucket to find the dumps past 7, which the photo key does not need.

Nothing restores a dump yet, and nothing checks that one restores.

[0009]: 0009-register-every-service-client-with-or-without-its-credentials.md
[0012]: 0012-never-retry-a-scheduled-job-and-make-its-next-run-catch-up.md
[0080]: 0080-store-photos-in-an-s3-store-and-serve-them-through-the-site.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
