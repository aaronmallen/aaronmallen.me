---
id: "0127"
title: Replay each Linear state change at Linear's time, from a cursor on task sources
status: active
created: 2026-10-07
area: [db, lib, record, tasks]
issue: "#737"
tags: [tasks, imports, sync, linear, history, time-tracking, work-sessions, cursors]
---

# ADR 0127: Replay each Linear state change at Linear's time, from a cursor on task sources

![Active][status]

## Context

A Linear issue that goes In Progress starts its task's session. The sync runs every 15 minutes and stamps each
change with the time it ran, so a start or stop lands up to 15 minutes late. A start, stop and start between two
runs leaves one change, since `Tasks::Operations::SyncIssues` sees only the state Linear reports now (ADR 0068).
Logged time and the time report come out wrong.

Linear keeps each issue's history, with the time of every state change. Spec #735 asks the sync to read it, under
Linear's complexity limit, with a quiet run costing what it costs today.

## Decision

The sync replays every Linear state change it has not seen, in order, at the time Linear records for it. Each
`task_sources` row keeps a cursor: the last change the sync replayed for that issue. A run moves the task through
each change past the cursor, then moves the cursor.

The sync reads history only for issues whose `updatedAt` passed their cursor. It first lists the issues as it does
today, then asks for the history of those that changed in one batched query: the same two steps `ReachIssues`
takes. A run where no tracked issue changed sends no history query.

When a replayed change matches one the owner already made by hand, Linear's time wins. The session moves to
Linear's time and no second session opens. A hand change with no match in Linear stays as it is.

Replay starts from the first run after #735 ships. No session logged before it changes.

ADR 0070 still holds. Linear's client maps each change's state type to a `remote_state`, and hands `SyncIssues` the
list of transitions with their times, so the operation reads no Linear field. ADR 0068 still holds too: replay turns
one run's single change in `remote_state` into the list of changes the history holds. ADR 0012 still holds, since a
run catches up from the stored cursor, not from the clock.

## Alternatives

**Read `history` in the shared `FIELDS`.** Every query in `Record::Linear::Issues` would carry each issue's history.
It lost because every run grows heavier under Linear's complexity limit, quiet runs included, and a history past the
connection's cap drops changes.

**Use the latest state with `startedAt` and `completedAt`.** Linear stamps an issue's start and finish, so the sync
could stamp the one change it sees with those times. It lost because a start, stop and start between two runs still
leaves one change, and the first session goes missing.

## Consequences

Sessions match the work in Linear, whatever the run interval. The interval stays at 15 minutes.

A run where an issue changed sends one more query than today. Any edit moves `updatedAt`, so a title or comment edit
pays for a history read that finds no state change.

`task_sources` takes a column for the cursor, which takes a migration of its own.

Linear's time beats the owner's hand on a matching change. A task the owner started at 10:02 under an issue that
went In Progress at 10:00 starts at 10:00, and the owner cannot keep the later time.

GitHub reports no started state, so its sync works as it did. Replay belongs to Linear alone.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
