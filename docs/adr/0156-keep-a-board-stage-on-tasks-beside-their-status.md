---
id: "0156"
title: Keep a board stage on tasks beside their status
status: active
created: 2026-10-12
area: [db, admin, api, mcp, tasks]
issue: "#1163"
tags: [tasks, projects, kanban, board, stage, status, enum, schema]
---

# ADR 0156: Keep a board stage on tasks beside their status

![Active][status]

## Context

Spec #1162 gives each project a kanban board of the tasks linked to it ([ADR 0093][0093]). The board has five
columns: backlog, ready, in progress, done and canceled. A task's status is a `task_status` enum of `open`,
`in_progress`, `done` and `canceled`, so four statuses have to fill five columns. Backlog and ready both hold open
tasks, and nothing on a task tells them apart.

The status does more than sort. `StartTask` runs the timer and puts the task in today's sprint, `CompleteTask` and
`CancelTask` set `completed_at`, which `tasks_completed_at_check` ties to the closed statuses, and views and reports
across the app read the status.

## Decision

**Tasks carry a stage.** A new `task_stage` enum of `backlog` and `ready` ([ADR 0015][0015]) tells open tasks apart
on a board. New tasks start in backlog. The four statuses stay as they are.

**The five columns are fixed.** Every board shows the same five, and no project can change them.

**A move runs the real task action.** Moving a card into in progress starts the task, into done completes it, and
into canceled cancels it. Moving a card from any of those back to backlog or ready reopens it and sets its stage.
Moving an open card between backlog and ready changes only its stage. The board calls the operations the task list
calls, so a card move does what the same change does anywhere else.

## Alternatives

**A `ready` task status.** Every place that reads the status would have to learn what `ready` means: the timer, the
sprint, the completed check, the views and the API. A fifth status would also turn up on every task, linked to a
project or not.

**Derive the stage from a list or a sprint.** A task's list (`next`, `someday` or `external`) and its sprint already
plan my own work, and a board move would rewrite them. The `external` list parks an imported task
([ADR 0067][0067]) and maps to neither column. Today comes from sprint membership ([ADR 0050][0050]), so moving a
card to ready would put the task in today.

**Per-project columns.** Columns would need their own table and an editor, and each one would need mapping onto a
task action. The owner picked five fixed columns in #1162.

## Consequences

The board needs no table of its own: a task's column comes from its status and stage.

The stage lives on the task, so a task linked to two projects sits in the same column on both boards.

The stage stays on a task once it leaves the open status, and means nothing until the task reopens. Reopening sets
it again.

The API and MCP task tools read and set the stage through the layer they share ([ADR 0088][0088]).

[0015]: 0015-type-a-closed-set-as-a-postgres-enum-and-a-format-as-a-domain.md
[0050]: 0050-derive-today-from-sprint-membership.md
[0067]: 0067-park-an-imported-task-on-an-external-list.md
[0088]: 0088-hold-the-layer-the-api-and-mcp-share-in-the-api-slice-and-call-it-in-process.md
[0093]: 0093-link-any-two-records-through-one-record-links-table-in-a-links-slice.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
