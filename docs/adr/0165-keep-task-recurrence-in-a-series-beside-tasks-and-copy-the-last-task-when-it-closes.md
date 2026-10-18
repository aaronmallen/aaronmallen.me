---
id: "0165"
title: Keep task recurrence in a series beside tasks, and copy the last task when it closes
status: active
created: 2026-10-14
area: [db, tasks, admin, api, mcp]
issue: "#1275"
amended: ["#1768"]
tags: [tasks, recurrence, series, cadence, schema, sprints, jobs]
---

# ADR 0165: Keep task recurrence in a series beside tasks, and copy the last task when it closes

![Active][status]

## Context

Every task is one-off. Spec #1274 lets the owner set a task to recur on a cadence, such as every Thursday or the
first of each month. When the owner closes a copy, done or canceled, the next copy appears at once, dated for the
next cadence date after today, or after the closed copy's sprint day when it closes before that day, in the sprint
for that date. The owner can pause a series and resume it later.

The next copy takes its title, note, tags and project from the copy just closed, so a rename or a new tag carries
forward. Comments, time, contributors, links and subtasks start fresh. Imported tasks from GitHub or Linear cannot
recur.

A task has one place to be, a list or a sprint ([ADR 0050][0050]), and every task closes through
`Tasks::Operations::CompleteTask` or `CancelTask`, whichever screen, endpoint, board move or MCP tool asks.

## Decision

**A series lives in its own table in `slices/tasks`, beside `tasks`.** It holds the cadence, whether the series is
paused, and which task is its current copy. Each copy is a plain task row in its list or sprint, as ADR 0050
places it. The series holds nothing a copy holds.

**The next copy appears in the transaction that closes the current one.** `CompleteTask` and `CancelTask` make it,
so every path that closes a task makes it too. The copy clones the task that just closed, and the series moves its
current copy to the new one. A paused series makes no copy. Resuming a series whose current copy has closed makes
the next one at once, and so does setting a cadence on a task that has already closed. The task timeline records
each copy as coming from its series.

Since #1768, each copy keeps its series' id in `tasks.series_id`, which clears when the series goes. A copy the
series has moved past refuses a cadence of its own, so it cannot start a second series beside the live one.

No job makes copies, so [ADR 0012][0012]'s catch-up rule never applies to them.

## Alternatives

**A cadence column on `tasks`.** Each copy would carry the cadence, or pass it to the next one, so the rule would
have no one home. The Recurring tab would have to pick one task out of many to stand for a series, and pausing would
mean writing to whichever copy holds the column.

**A stored template the series copies from.** It would split a task's fields across two places, and a rename on the
open copy would not reach the next one. The owner asked for the rename to carry forward.

**A nightly job that makes copies on their dates.** Copies would pile up while one stays open, and the job would
need ADR 0012's catch-up for every night it missed. The owner wanted the next copy the moment the last one closed.

## Consequences

A series moves only when its copy closes, or when it starts on a task already closed. A copy left open stalls the
series, with no backlog of missed dates, and a late close still dates the next copy after today. An early close dates
it after the closed copy's day, so a copy closed ahead of its day never lands a second copy on that day.

`CompleteTask` and `CancelTask` grow a step and a dependency on series reads, and every close now writes in more
than one table. A new way to close a task has to go through them, or a series stops.

A copy dated ahead waits in Upcoming in its sprint and moves to Today on its day, as any scheduled task does.

Each copy is a whole task, so lists, saved views and search need nothing new to find it. The
Recurring tab reads series, not tasks, and shows each one once.

[0012]: 0012-never-retry-a-scheduled-job-and-make-its-next-run-catch-up.md
[0050]: 0050-derive-today-from-sprint-membership.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
