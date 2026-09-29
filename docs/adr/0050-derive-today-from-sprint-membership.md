---
id: "0050"
title: Derive Today from sprint membership
status: active
created: 2026-09-28
area: [db, admin, tasks]
issue: AA-689
amended: [AA-397, AA-398, "#53", "#81"]
tags: [tasks, sprints, schema, today, upcoming, rollover, dashboard]
---

# ADR 0050: Derive Today from sprint membership

![Active][status]

## Context

AA-341 adds tasks to the admin. A task sits in Next, Someday or Today, and a sprint lasts one day. Today holds the
tasks being worked on and so does the current sprint, so the two name the same set. One has to be the truth and the
other a view of it. AA-341 also asks that starting a task put it in Today, since working on something is the
strongest sign it is today's work, so whatever holds Today has to make that rule cheap.

AA-398 then let the operator plan a sprint for a later day and drop one, so a sprint no longer means today.

A job starts each day at midnight, and a job can miss a night. Two screens show Today: the Tasks screen and the
`/admin` dashboard. A screen that reads today's sprint without claiming it finds no row after a missed night.

## Decision

We store sprint membership and read Today from it. Today is a query, not a column.

A task carries a `list` of `next` or `someday` while it belongs to no sprint, and a `sprint_id` otherwise. The CHECK
`num_nonnulls(list, sprint_id) = 1` in `config/db/migrate/20260928000027_create_tasks.rb` holds the rule, so a task
has exactly one place to be. A sprint may be dated ahead. Today is membership in the sprint dated today, and Upcoming
is membership in a later one (`Tasks::Queries::ListTasks`).

These moves change membership, and nothing else does:

- **Join today.** Move to Today, start, capture into Today, or schedule for today. Each resolves today's sprint
  through `CurrentSprint` and clears the list in one write.
- **Schedule ahead.** `ScheduleTask` claims the sprint for that day and sets the task's `sprint_id` with a null list,
  so it waits out of Next. A task in progress goes back to open while it waits.
- **Clear the date, or move to a list by hand.** The task takes back a list, Next when the date is cleared, and its
  carry count starts again at zero. A task in progress goes back to open (#81).
- **Drop a sprint.** Only one dated ahead. `DropSprint` moves its tasks to Next and deletes it in one transaction,
  since `tasks.sprint_id` is `ON DELETE RESTRICT`. A task in progress goes back to open here too (#81).
- **Roll over.** `CurrentSprint` claims today's sprint and carries every unfinished task from any earlier sprint into
  it. Each carried task's `carried_count` rises by one and the sprint's `carried_in` by the number that arrived
  (AA-397). After days away there is one sprint for today holding the work across the gap, not one per missed day.

A task in progress belongs to Today, so every move that takes a task out of Today and into a list or a later sprint
sends it back to open, while a move into Today leaves its status alone. `TaskRepo#move_to_list` and
`TaskRepo#release_sprint` write the rule, so `MoveTask`, `ScheduleTask`, `DropSprint` and the MCP tools that call them
all follow it. A finished task stays finished. An issue sync still acts only when the provider reports a new state
(ADR 0068), so a started issue whose task was moved to a list leaves the task open (#81).

Finishing a task writes `status` and `completed_at` and changes no membership, so a finished task keeps the sprint
it was finished in. Reopening one changes none either, and the next rollover carries a task reopened in an earlier
sprint.

Every screen that shows Today claims today's sprint as it loads, as AA-358 asked, so a missed midnight job never
leaves Today stale. The Tasks screen does it in `Admin::Operations::BuildTasksPage` and the `/admin` dashboard in
`Admin::Operations::SummarizeSprint`, both through `CurrentSprint`. A task's read and edit pages do it too, in
`Admin::Operations::BuildTaskPage` and `Admin::Actions::Tasks::Edit`, so a task opened from a link on a new day shows
today's sprint and saves unchanged (#53). Rollover also runs from `Tasks::Jobs::RollOverSprint` at midnight in the
site's time zone and from every write that puts a task in Today.

The relations, repos and operations belong to `slices/tasks`, and `slices/admin` holds the screens and reaches them
through exports.

## Alternatives

**A third `list` value of `today`, with sprints recorded beside it.** One column answers Today, and the screen draws
whether or not a sprint exists. It writes one fact in two places. Rollover then has to move membership and rewrite
lists together, and the first rollover that half finishes leaves the column and the sprint claiming different work
with nothing to say which is right. Starting a task costs two writes instead of one, for the same reason.

**A dashboard that only reads**, through `todays_sprint`, leaving the start of a day to the job and to whatever the
operator posts next. The dashboard would stay a summary that never writes. It lost because after a night the worker
missed, `/admin` would show no sprint and none of yesterday's open tasks until the Tasks screen loaded or a write
put a task in Today.

## Consequences

Every read of Today is a join: resolve the sprint, then its tasks. It is bounded by one operator and a day's work,
and it buys a set that cannot disagree with itself.

A task cannot be in Today and in a list at once, because there is nowhere to record it twice. The schema holds that,
not the code.

Both screens always have a sprint to draw, since loading either claims one, so their empty case is an empty sprint.
Whether the job ran matters to neither.

A GET to `/admin` writes. A glance at the dashboard starts the day: it can insert the sprint and carry tasks
forward, and it has a failed claim to handle that a plain read did not. The claim upserts on `sprint_date`, so two
loads at once still make one sprint.

The carry count resets when the operator moves a task to a list or clears its date. It survives a schedule ahead,
and a dropped sprint sends its tasks to Next with their counts. The count on the sprint survives a task later
moving or finishing, which a count derived from rows would not.

Carrying unfinished work forward is the only honest end for a sprint. Dropping it back to Next would lose that it was
started, and archiving it would hide it.

The activity feed is untouched. It reads tasks on `completed_at`, which has nothing to do with sprints.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
