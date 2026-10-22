---
id: "0146"
title: Keep health data in a health slice as daily summaries and workouts polled from Google
status: active
created: 2026-10-11
area:
  - config
  - db
  - record
  - services
issue: "#1111"
amended:
  - "#1121"
tags:
  - health
  - google
  - slices
  - sync
  - polling
  - webhooks
  - sleep
  - workouts
  - privacy
  - time-zone
---

# ADR 0146: Keep health data in a health slice as daily summaries and workouts polled from Google

![Active][status]

## Context

Spec #1110 brings my sleep, heart rate and workouts in from Google Health and lays each day beside its work, so
the agents I work with and I can see how one bears on the other. The data is the most private the site holds.
Clients with only the `read` scope must never see it, and none of it may reach the public site.

Google offers two ways to get it: webhooks that push a change as it lands, or reads I make on my own clock. It also
offers two levels of detail: raw samples, such as every heart rate reading and SpO2, or the rollups it keeps per day
and per workout.

A night of sleep crosses midnight, so it needs a day to belong to.

## Decision

A new feature slice, `health`, owns the health tables ([ADR 0001][0001]). Its relations, repos, contracts and
operations live in `slices/health` ([ADR 0126][0126]). Other slices read it through its exported read repos and
operations and never write its tables ([ADR 0123][0123]).

**It keeps two shapes, and no raw samples.**

- **One row per day**: minutes asleep, bed and wake times, resting heart rate, HRV, steps and active zone minutes.
- **One row per workout**: type, start, minutes, distance, average heart rate, zone minutes, kcal and device.

No heart rate samples, SpO2 or GPS routes reach the database.

**A night counts toward the day I wake up,** in the site time zone. Monday night's sleep sits on Tuesday's row.

**We poll.** A scheduled job asks Google every 15 minutes and reads the last 3 days again, so a watch that syncs
late still lands. On the first connect it reads all the history the API gives. The job never retries and catches up
on its next run ([ADR 0012][0012]), and its outcome goes to `sync_states` ([ADR 0047][0047]). Google Health is a
service definition in the `services` slice, and the client looks up its OAuth token there on each call
([ADR 0130][0130]). #1121 moves the client to a `google` slice and the definition to one `google` service
with a connection per account, and health syncs on the main one ([ADR 0149][0149]).

## Alternatives

**Webhooks.** Google pushes a change as it lands. They need a service account, signature checks and a public
endpoint, all for data a poll gets within 15 minutes.

**Raw samples.** They hold more than the summaries and are more sensitive, and no screen needs them.

## Consequences

Health data sits in one place, so the `health` scope and the never-public rule have one slice to guard.

The site polls Google 96 times a day whether or not anything changed, and a workout appears up to 15 minutes
after the watch syncs. A change Google makes to a day more than 3 days back never arrives.

A question that needs a raw sample, such as heart rate through a workout, has no answer without a new record and a
new sync.

The day a night belongs to depends on the site time zone, so changing that setting moves only the nights synced
after the change.

Health data lands in the nightly backups ([ADR 0105][0105]).

[0001]: 0001-split-the-app-into-slices-by-feature.md
[0012]: 0012-never-retry-a-scheduled-job-and-make-its-next-run-catch-up.md
[0047]: 0047-keep-every-syncs-state-in-records-sync-states-table-keyed-by-kind-sync-and-repo.md
[0105]: 0105-dump-the-database-nightly-to-a-private-backups-bucket-and-keep-the-newest-7.md
[0123]: 0123-export-only-read-repos-and-operations-and-keep-write-repos-in-their-slice.md
[0126]: 0126-keep-only-base-classes-and-gem-wrappers-in-lib-and-give-the-rest-a-hanami-shape.md
[0130]: 0130-keep-service-credentials-encrypted-in-a-services-slice-and-define-each-service-in-code.md
[0149]: 0149-keep-google-accounts-in-a-google-slice-with-one-connection-each.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
