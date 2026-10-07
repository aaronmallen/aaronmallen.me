---
id: "0121"
title: Keep inbox snoozes in a snoozed_until column on each record's table
status: active
created: 2026-10-07
area: [db, api, contact, social, tasks]
issue: "#655"
tags: [inbox, snooze, schema, slices, tasks, messages, webmentions]
---

# ADR 0121: Keep inbox snoozes in a snoozed_until column on each record's table

![Active][status]

## Context

Spec #649 lets the owner snooze any inbox row, an issue, a message or a webmention, until a set time. A snoozed row
leaves the inbox and its nav count, keeps its seen, read or pending state, and comes back at the top when the snooze
ends, as if it just arrived. A Snoozed section lists the snoozed rows with a Wake now button.

The rows live in three slices. [ADR 0094][0094] has `tasks`, `contact` and `social` each export a query for their own
waiting rows, and `api` merges them newest first. It keeps an issue's seen mark in `task_sources.seen_at`, and #651
adds a seen mark to `webmentions` the same way. [ADR 0095][0095] keeps the Needs attention snoozes in one
`attention_snoozes` table that `activity` owns, with a trigger per table to delete a record's snoozes when the record
goes.

## Decision

**Each record's table carries its own snooze.** A new migration adds a nullable `snoozed_until` to `task_sources`,
`messages` and `webmentions`, beside the seen marks. A row waits while `snoozed_until` is empty or past.

**Each slice filters its own rows.** `tasks`, `contact` and `social` each leave a snoozed row out of the waiting query
and the count they export, and each owns the operations that snooze and wake its rows. The Snoozed section reads one
more export per slice, and `api` merges them as it merges the inbox.

**A woken row sorts by the later of its arrival and its snooze end.** The merge in `api` takes that time as the row's
`at`, so a woken row lands at the top.

## Alternatives

**One `inbox_snoozes` table, as `attention_snoozes` does.** A kind, a record id and an end time, in one place. It loses
because a single table needs one slice to own it, and the waiting queries in three other slices would have to read it.
It points at three tables with no foreign key, so it needs a drop trigger on each, and every inbox read takes a join
it does not need today.

## Consequences

A deleted record takes its snooze with it, with no trigger to keep.

Each slice keeps the filter in two places, its waiting query and its count. One that forgets the count shows a nav
number the inbox does not match, and nothing fails when it does.

A fourth inbox kind needs a `snoozed_until` of its own, a filter, and a snooze and wake operation in its slice.

A snooze that has ended stays in its column. A row the owner reads or moderates while snoozed keeps its
`snoozed_until`, so each Snoozed query has to list only rows that would wait once they wake.

The inbox snoozes and the Needs attention snoozes now live in two shapes, and a reader has to know which list a
snooze belongs to before looking for it.

[0094]: 0094-keep-a-seen-at-on-task-sources-and-merge-the-inbox-in-the-api-slice.md
[0095]: 0095-build-the-stalled-list-in-the-activity-slice-and-keep-snoozes-in-attention-snoozes.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
