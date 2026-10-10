---
id: "0018"
title: Run the site on one time zone, written into the schema as a literal
status: active
created: 2026-09-28
area: [activity, admin, config, db, lib, public, record, tasks]
issue: AA-669
amended: [AA-819, "#943"]
tags: [time-zone, postgres, indexes, activity, sidekiq, cron, dates]
---

# ADR 0018: Run the site on one time zone, written into the schema as a literal

![Active][status]

## Context

The site answers questions by the operator's day: what did I do on Tuesday, which sprint is today, what went out
this month. A day means something only in a zone, and the operator lives in America/Chicago.

The activities view unions six kinds of record and filters them by day. Four of those kinds keep a `timestamptz`,
so the view turns each into a day, and each of the four tables carries an index on that day so a date range
narrows every branch. Postgres builds an expression index only from an immutable expression, and `AT TIME ZONE`
is immutable only when the zone is a constant.

AA-333 found the zone written out four times and offered two ways to write it once: take it from a Postgres
setting, or have the view return raw timestamps and convert in Ruby. AA-504 found a cron line with no zone. It ran
on the worker's clock, UTC in a container, and moved an hour against the other jobs at each daylight saving change.

## Decision

One zone runs the site, and `Blog::TimeZone::NAME` in `lib/blog/time_zone.rb` is the only place that names it.

Admin copy may name the city instead, as "Publish time (Chicago)" does. MCP and API text interpolates `NAME`
(#943).

- `config/db/migrate/20260928000035_create_activities_view.rb` writes it as a literal into the four expression
  indexes and into every branch of the view that converts a `timestamptz`.
- `config/sidekiq.yml.erb` requires `lib/blog/time_zone.rb` by path, since Sidekiq reads the file before Hanami
  boots, and ends every cron line with the zone. The nightly jobs run as the Chicago day turns, not the UTC one
  (AA-504).
- Ruby converts through `Blog::TimeZone`, which also reads a form's date and time as Chicago time, whatever zone
  the browser is in.

Nothing checks that the view, every index that names a zone and every cron line carry this one. The spec that did
scanned the schema and went with the unit specs (AA-819).

The schema holds two shapes for when a thing happened. Posts, social posts, webmentions and tasks keep a
`timestamptz` and convert it in SQL. Commits and journal entries store a local `date` and `time`.
`Record::Operations::StoreCommits` converts a commit's time in Ruby before the write. A journal entry takes the day
the operator picks and the clock time of the save (`Record::Operations::SaveJournalEntry`), so it has no single
instant to store. No issue gives a reason for the commit shape.

## Alternatives

**Take the zone from a Postgres setting**, read by the view at query time. It lost to the indexes: an expression
that reads a setting is not immutable, so Postgres will not index it.

**Return raw timestamps from the view and convert in Ruby.** It lost to the indexes too. The view could no longer
filter, count or sort by day in SQL, and the day indexes that narrow each branch would serve nothing.

## Consequences

A fork in another zone edits `NAME` before its first migration, and the view, the indexes, the cron lines and the
Ruby all follow.

Moving the zone after that means rebuilding the database, since the view and the indexes hold the old literal. The
`timestamptz` kinds then follow on their own. Stored commit and journal rows keep the old zone's day and time.

A query built in Ruby that filters one of the four kinds by day has to repeat the index's expression to use the
index, as `Tasks::Relations::Tasks::COMPLETED_ON` does.

Every reader sees the operator's day. A visitor in another zone sees a post dated by the Chicago day it went out.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
