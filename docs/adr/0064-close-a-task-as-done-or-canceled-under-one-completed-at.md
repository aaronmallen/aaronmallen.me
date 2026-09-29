---
id: "0064"
title: Close a task as done or canceled under one completed_at
status: active
created: 2026-09-28
area: [db, tasks]
issue: "#2"
tags: [tasks, schema, enums, constraints, canceled, rollover, sprints, activity]
---

# ADR 0064: Close a task as done or canceled under one completed_at

![Active][status]

## Context

A task ends one way: done. `task_status` holds `open`, `in_progress` and `done`, and `tasks_completed_at_check`
sets `completed_at` exactly when a task is done. A task the operator drops has to be marked done, which inflates the
work finished, or deleted, which loses it. The GitHub Issues sync needs a way out too: when someone takes an issue
off the operator, its task should close without counting as work done. #1 adds a canceled task.

Every read of finished work orders or groups on `completed_at`: `newest_finished` and `newest_first` in
`slices/tasks/relations/tasks.rb`, the finished list's day grouping in `slices/admin/ui/views/tasks/index.rb`,
`tasks_completed_on_index`, and the `activities` view.

## Decision

A task closes as `done` or `canceled`, and `completed_at` holds the close time for both. `done` keeps meaning work
finished. `canceled` means closed without doing it.

`canceled` joins the `task_status` enum, as ADR 0015 types every closed set. The site is live, so a new migration
adds it with `ALTER TYPE ... ADD VALUE` rather than editing the create migration.

`tasks_completed_at_check` widens so `completed_at` is set exactly when a task is `done` or `canceled`. Postgres
holds the rule, as ADR 0017 asks of every rule over stored state, so no caller can cancel a task without a close
time or leave one on an open task.

Canceling follows ADR 0050's rule for finishing. It writes `status` and `completed_at` and changes no membership,
so a canceled task keeps the sprint it closed in. Rollover counts it finished and never carries it forward.
Reopening clears `completed_at` and changes no membership, as it does for a done task.

A read that skips finished tasks, such as `open`, `open_first` and `unfinished_in`, skips canceled ones too. The
finished list reads both closed statuses and marks the canceled ones. A read of work done, such as the
`activities` view, keeps to `done`.

## Alternatives

**A separate `canceled_at` column.** The column's name would say what it holds. It lost because every sort, the
finished list's day grouping and the `activities` view would have to merge two columns into one close time.

**A `resolution` column beside `done`**, as Jira does, with `done` meaning closed and the resolution saying how.
It lost because `done` would stop meaning finished, and every read of work done would have to check a second
column.

## Consequences

`completed_at` names what a done task holds, not what a canceled one does. A reader has to know it means closed.
Renaming it to `closed_at` stays open for later, and would touch the schema, the `activities` view, the tasks
relation and repo, the admin views and the MCP tools.

`completed_at IS NOT NULL` no longer means work done. The `activities` view filters on it today and would list a
canceled task as finished work, so it has to filter on `status = 'done'` instead. Every later read of work done
has to filter on status the same way, and nothing fails when one filters on `completed_at` by mistake.

Postgres refuses a value added by `ALTER TYPE ... ADD VALUE` until the transaction that added it commits, so the
enum and the widened check cannot share one migration's transaction.

The sorts, the finished list's day grouping and both close-time indexes serve canceled tasks with no change.
`TaskRepo#finished` does not: it reads `done`, and has to read both closed statuses.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
