---
id: "0133"
title: Count overlapping work sessions once in rollups by merging them in SQL at read time
status: active
created: 2026-10-08
area: [tasks, activity, db]
issue: "#776"
tags: [tasks, activity, review, time, work-sessions, sql, schema]
---

# ADR 0133: Count overlapping work sessions once in rollups by merging them in SQL at read time

![Active][status]

## Context

A task can run while others run, and each keeps its own clock in `work_sessions`. Every rollup adds the clocks:
`Tasks::Repos::TimeReportQueries` sums each task's sessions per day, and the review sums the `work_session_days` view
under [ADR 0100][0100]. Run three tasks for an hour and both credit three hours.

Spec #775 asks for each task to keep all the time it ran, and for rollups to count time spent on more than one task
at once a single time. The rollups are the time report's total, each project and tag group, and the review's daily
and total worked figures. Time set by hand (a total set on a task, the worked figure given on complete, or a shift
to the total) has no start or end, so it cannot overlap anything we can see. Past reports change too.

## Decision

Per-task totals stay full. A task's page, the API and the MCP tools show every second its sessions ran.

Rollups merge overlapping sessions once, in SQL with window functions, when a report loads. An open session runs up
to now. The merged spans are then cut into site days as the report cuts sessions today. A group merges only its own
tasks' sessions, so two overlapping tasks in one project give it one hour, and its rows can add up to more than its
total.

Manual time is the gap between a task's total and its closed sessions. It goes on top of the merged time as it
stands, in place of the scaling the report does now. A task with no sessions still lands on the day it closed.

The time report's merge lives in the `tasks` slice. The review's lives in a new migration that rebuilds
`work_session_days`, so the review stays one activity query, reading `work_sessions` as [ADR 0021][0021] allows.

## Alternatives

**Split each hour between the tasks that shared it.** Totals add up, but a task's page would stop showing the time
it ran, and a task's figure would change when another task starts beside it.

**Merge in Ruby in each slice.** Every report would load every session in its range, and `tasks` and `activity` would
each carry their own copy of the merge. The review would no longer come from one activity query.

**Store merged spans in a table.** Reports would read plain rows, but every start, pause, split and edit of a session
would have to rewrite the spans it touches, and a missed path would leave the figures wrong with nothing to show it.

## Consequences

Each report reads the sessions as they stand, so nothing drifts and editing a session fixes every report at once.
Past weeks and months show new, lower figures where tasks overlapped.

The merge SQL lives twice: in the time report's query and in the `work_session_days` view. A change to how sessions
count has to land in both, and the view's half takes a migration.

Window functions over every session in a range cost more than a plain sum, and the cost grows with the range.

A group's rows can add up to more than its total for a second reason. A task in two projects already did that, and
the hint under the group now covers both.

Manual time never merges. Two tasks given an hour by hand for the same hour still count two.

[0021]: 0021-let-sql-read-another-slices-tables-never-write-them.md
[0100]: 0100-build-the-review-in-one-activity-query-that-admin-and-api-share.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
