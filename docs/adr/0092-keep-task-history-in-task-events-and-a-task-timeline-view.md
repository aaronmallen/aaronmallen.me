---
id: "0092"
title: Keep task history in task_events and a task_timeline view
status: active
created: 2026-10-03
area: [db, tasks, admin, api, mcp]
issue: "#258"
tags: [tasks, history, timeline, work-sessions, view, postgres, enums, constraints]
---

# ADR 0092: Keep task history in task_events and a task_timeline view

![Active][status]

## Context

A task keeps its current state and nothing else. `tasks.status`, `tasks.list` and `tasks.sprint_id` each hold one
value, so a move, a sprint change or a status change writes over the last one. Tags sit in `task_tags` with no trace
of when they came or went. Comments, local and synced, live in `task_comments` ([ADR 0075][0075]).

Spec #257 asks for the story of a ticket: work sessions with a total time, and one timeline, oldest first, that holds
comments, sessions, tag changes, moves and status changes. The task page, the flyout, the API and the MCP all read
that timeline, so it needs one shape that later work on tasks, the feed and the API can build on.

[ADR 0015][0015] types a closed set as an enum, and [ADR 0017][0017] puts every rule over stored state in Postgres.

## Decision

We keep task history in three places and read it through one view.

- **`task_events`** holds every move, tag change and status change. A `kind` enum names the change, and typed
  columns hold what changed: the from and to list, the sprint, the tag, the status. A `CHECK` per kind holds the
  columns that kind needs and leaves the rest null, so Postgres refuses an event missing what its kind needs.
- **`work_sessions`** holds each span of work on a task, with its start and its end. A partial unique index allows
  one open session per task, and a `CHECK` refuses a session that ends before it starts.
- **`task_comments`** stays as it is.

The total time is a column on `tasks`, stored, not summed from sessions. Each session write shifts it in the same
transaction: a closed session adds its length, a deleted one takes its length away, and an edit adds the
difference. A total set by hand replaces the stored number, and sessions keep shifting it after that.

A `task_timeline` view unions events, sessions and comments into one shape, keyed by task and stamped with the time each
happened, as the `activities` view does for the feed ([ADR 0052][0052]). The `tasks` slice owns the tables and the view.
The admin, the API and the MCP read the timeline through it.

History starts when these tables land. Nothing fills it in for older tasks.

## Alternatives

**A table per event kind**, such as `task_moves`, `task_tag_changes` and `task_status_changes`. Each table would
need no per-kind `CHECK`. It lost because the view would union one more branch for each kind, and a new kind would
mean a new table and a new view, the cost ADR 0052 names for the feed.

**One events table with a JSON payload**, holding comments and sessions too. It needs no new table for a new kind.
It lost because Postgres cannot type or check what sits in a JSON column, against ADR 0015 and ADR 0017. Comments
would leave `task_comments` and the sync that keys them by remote id, and sessions would lose the index that allows
one open session per task.

## Consequences

The timeline for a task is one query against one relation.

A new kind of event is `ALTER TYPE ... ADD VALUE`, a new `CHECK` branch, and the columns it needs. The view reads
the columns of three tables, so changing one of them means replacing the view too.

The stored total can drift from the sum of sessions, and that is the point: an hour I forgot to track stays in the
total. It also means no query can rebuild the total, and a session write that skips the shift leaves the total
wrong with nothing to catch it.

Every write that moves, tags or changes the status of a task has to write its event in the same transaction. A path
that forgets leaves a gap in the timeline, and nothing in Postgres notices.

A ticket made before then shows its comments and no history.

[0015]: 0015-type-a-closed-set-as-a-postgres-enum-and-a-format-as-a-domain.md
[0017]: 0017-enforce-rules-over-stored-state-in-postgres-not-in-contracts.md
[0052]: 0052-read-activity-through-one-view-across-every-content-kind.md
[0075]: 0075-keep-local-and-synced-task-comments-in-one-table-keyed-by-remote-id.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
