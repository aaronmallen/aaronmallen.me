---
id: "0068"
title: Follow a change in an issue's state, not the state itself
status: active
created: 2026-09-29
area: [db, tasks]
issue: "#33"
tags: [tasks, imports, github, sync, schema, enums]
---

# ADR 0068: Follow a change in an issue's state, not the state itself

![Active][status]

## Context

Spec #8 lets GitHub decide an imported task: an issue closed as completed makes its task done, one reopened or
assigned back reopens it, and one closed as not planned, taken off the operator, moved or deleted cancels it. The
sync runs every 15 minutes (#13), and the operator can still close or reopen an imported task by hand.

A sync that sets each task to match its issue on every run undoes the operator. Close a task by hand while its
issue stays open, and the next run reopens it, and every run after that.

## Decision

`task_sources` keeps what GitHub last said about each issue in `remote_state`, and the sync moves a task's status
only when that changes. #13 added the column in migration `20260928000043`, typed as the Postgres enum
`task_source_state` (ADR 0015): `open`, `completed`, `not_planned`, `unassigned`, `moved` and `deleted`. A row
starts at `open`.

On each run `Tasks::Operations::SyncIssues` works out the state GitHub reports now. When it differs from
`remote_state`, the sync settles the task to match and stores the new state, both in one transaction. When it
matches, the task keeps whatever status the operator gave it.

A row at `moved` or `deleted` has nothing left on GitHub to follow, so the sync stops reading it.

## Alternatives

**Match the issue on every run.** No stored state: an open issue means an open task. It lost because it reopens a
task the operator closed by hand every 15 minutes while the issue stays open, so no hand close would stick.

## Consequences

The operator can close, reopen or start an imported task, and it holds until GitHub reports something new. The job
spec, under `spec/slices/tasks/jobs`, pins it: a task closed by hand stays closed, and one in progress stays in
progress, while the issue stays open.

A task and its issue can then disagree for as long as GitHub stays quiet. A task the operator reopens under a closed
issue stays open, and nothing marks the gap.

When GitHub does change, it wins. A task the operator canceled goes to done when its issue closes as completed.

The rule covers status alone. The sync copies an issue's title and body whenever they differ from the task's, so an
edit to an imported task's title or note lasts only until the next run.

A new state GitHub can report needs a value in `task_source_state`, which takes a migration of its own.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
