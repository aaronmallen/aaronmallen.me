---
id: "0067"
title: Park an imported task on an external list
status: active
created: 2026-09-28
area: [db, admin, tasks]
issue: "#10"
tags: [tasks, sprints, schema, enums, constraints, imports, github, external, planning]
---

# ADR 0067: Park an imported task on an external list

![Active][status]

## Context

Spec #8 imports every open GitHub issue assigned to the operator as a task, and ADR 0066 keeps each one's origin in
`task_sources`. The spec shows imported tasks only on a new External tab, never on Next or Someday, and lets the
operator pull them into a sprint.

ADR 0050 gives every task one home, a `list` or a `sprint_id`, and the CHECK `tasks_list_or_sprint_check` holds
`num_nonnulls(list, sprint_id) = 1`. `list` takes `next` or `someday`, and a task that leaves a sprint without the
operator naming a list lands on Next. An imported task that took that path would show where the spec says it never
should.

## Decision

`external` joins the `task_list` enum, and an imported task starts there. The site is live, so a new migration adds
the value (ADR 0015).

This amends ADR 0050 in three places, and leaves that record as it shipped:

- **A task goes back to its list.** When ADR 0050 sends a task to Next without the operator naming a list, a task
  with a row in `task_sources` goes to External instead. That covers clearing its date and dropping its sprint.
  A task with no source still goes to Next.
- **`list` takes three values.** Where ADR 0050 reads "`next` or `someday`", read "`next`, `someday` or
  `external`".
- **Planning draws from External.** The operator can pull a task into a sprint from External as well as from Next
  and Someday.

A move to a list the operator names still goes where it is told, so an imported task can leave External by hand.
Rollover, finishing and reopening change no membership, as before.

## Alternatives

**No home at all.** Let an imported task hold neither list nor sprint, and draw the External tab from
`task_sources`. It lost because the CHECK would have to allow a task with no home, which breaks ADR 0050's rule in
Postgres, and nothing in the database could tell an imported task waiting on External from one a bug left homeless.

## Consequences

The one-home rule stays in Postgres, and the External tab is a plain read of `list`, the same as Next and Someday.

Each move that sends a task back without a named list has to ask whether it has a source, which is a read of
`task_sources` the old moves never made. A move that forgets to ask drops an imported task on Next, and nothing
fails when it does.

Postgres does not tie `external` to a source. It will hold a task the operator made on External, or an imported task
on Next, so the tie lives in the code that picks the list.

Adding a value to `task_list` takes its own migration, since Postgres will not use a new enum value inside the
transaction that added it.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
