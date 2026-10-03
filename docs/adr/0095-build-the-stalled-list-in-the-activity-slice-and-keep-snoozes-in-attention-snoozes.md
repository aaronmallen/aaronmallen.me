---
id: "0095"
title: Build the stalled list in the activity slice and keep snoozes in attention_snoozes
status: active
created: 2026-10-03
area: [activity, admin, api, db]
issue: "#350"
amended: ["#351"]
tags: [activity, attention, today, snooze, view, postgres, tasks, posts, journal]
---

# ADR 0095: Build the stalled list in the activity slice and keep snoozes in attention_snoozes

![Active][status]

## Context

The spec in #296 adds a Needs attention card to Today. It lists, worst first, tasks carried three or more days,
drafts nobody has touched in thirty days, someday tasks nobody has touched in ninety, and the days since the last
journal entry once that passes two. I can snooze a row for a week. An API endpoint and an MCP tool return the same
rows, and the limits come from settings.

The list reads `tasks`, `posts` and `journal_entries`, which `tasks`, `posts` and `record` own. Both `admin` and
`api` need it, and `mcp` reaches it through `api`, as [ADR 0088][0088] says. [ADR 0003][0003] bars a slice from
another's repos, and [ADR 0021][0021] lets SQL read another slice's tables but never write them.

The `activity` slice already reads across those tables through the `activities` view ([ADR 0052][0052]).

## Decision

The `activity` slice builds the list.

- **A new `attention` view** gives one row per candidate: its kind, its record id and its last touch. A migration
  builds it, and it joins the list in [ADR 0021][0021].
- **A touch per kind.** A draft's last touch is its `updated_at`. A someday task's is its `updated_at` too, not its
  newest row in `task_events` (#260), since `task_events` leaves out edits to the title and note. A carried task
  counts by its `carried_count`, and the journal row by the day of the newest entry.
- **Ruby applies the rules.** An `activity` query reads the limits from settings, drops snoozed rows and sorts the
  rest worst first. `activity` exports it, `admin` imports it for the card, and `api` imports it for the endpoint
  its MCP tool calls, so the card and the tool read one list.
- **Snoozes live in `attention_snoozes`**, which `activity` owns: a kind, a record id and the time the snooze ends.
  The journal row has no record, so its snooze carries no id. An `activity` operation writes a snooze, and
  `activity` exports it to `admin` and `api`.

## Alternatives

**A query per feature slice, joined in `admin` and `api`.** `tasks`, `posts` and `record` would each export their
own stale rows, and each slice would keep its own rule beside its own table, with no view to rebuild. It loses
because the merge, the worst-first order and the snooze filter would then live in both `admin` and `api`, and the
card and the tool could drift apart. Each door would take three imports, and the snoozes would still need a slice
to own them, one that owns none of the three kinds.

## Consequences

The card, the endpoint and the tool read one exported query, and a new kind joins by adding a branch to the view.

The view reads `tasks.title`, `tasks.status`, `tasks.updated_at`, `tasks.list`, `tasks.carried_count`,
`posts.title`, `posts.status`, `posts.updated_at` and `journal_entries.entry_date`. Postgres will not change a
column a view reads, so a migration that touches one has to replace `attention` too.

`updated_at` moves on every write through a repo's update command. Dragging a someday task to a new place in its
list, or a sync of its issue, counts as a touch and puts the task's ninety days back to zero.

A snooze points at records in three tables, so no foreign key holds it. Deleting a task or a draft leaves its snooze
behind until it ends, and nothing reads it after that.

`activity` now writes a table of its own, where before it only read.

[0003]: 0003-reach-another-slice-only-through-its-exports.md
[0021]: 0021-let-sql-read-another-slices-tables-never-write-them.md
[0052]: 0052-read-activity-through-one-view-across-every-content-kind.md
[0088]: 0088-hold-the-layer-the-api-and-mcp-share-in-the-api-slice-and-call-it-in-process.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
