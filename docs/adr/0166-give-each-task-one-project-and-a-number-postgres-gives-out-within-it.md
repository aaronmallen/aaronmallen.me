---
id: "0166"
title: Give each task one project, and a number Postgres gives out within it
status: active
created: 2026-10-14
area: [db, admin, api, mcp, projects, public, tasks]
issue: "#1316"
tags: [tasks, projects, keys, numbers, labels, rules, links, triggers, constraints, backfill, schema]
---

# ADR 0166: Give each task one project, and a number Postgres gives out within it

![Active][status]

## Context

Every task shares one global number, `tasks.id`, and it has passed 2000. The number says nothing about where a task
belongs. Spec #1315 gives each project a key, such as `POD`, and labels a task `<KEY>-<number>`, with numbers that
count from 1 in each project. A task with no project shows its plain number, counted from 1 among tasks with no
project, so `POD-1`, `COM-1` and `1` are three tasks.

A task links to projects through `record_links` today ([ADR 0093][0093]), and it may link to several. Task rules
and a project's repo add those links on import ([ADR 0122][0122]), and a rule may name several projects through
`task_rule_projects`. A number within a project needs one project to count in. The public task page lives at
`/projects/:slug/tasks/:number` ([ADR 0157][0157], [ADR 0160][0160]) and reads the global number.

Comments, links, events, work sessions, record links and tags all point at `tasks.id`.

## Decision

**`tasks.id` stays the internal key.** Nothing that points at a task changes, and admin routes keep it.

**A task belongs to one project at most, through a `tasks.project_id` column**, in place of task to project rows
in `record_links`. Task rules name one project at most. A rule or repo match sets the column where it added a link.

**Projects gain a key.** It is 2 to 6 characters, starts with a letter, and holds only uppercase letters and
digits, unique without regard to case, archived projects included. Postgres holds the format and the uniqueness
([ADR 0017][0017]). A new key defaults to the first 3 letters of the name, uppercased, with a letter or digit added
when that one is taken or too short. The label reads the key at render time, so changing a key relabels every task
in the project and writes no task row.

**A `tasks.number` column holds the number, and a Postgres trigger gives it out** as the next number in the task's
scope: its project, or tasks with no project. A unique index on the scope and the number holds it. A task that
gains, loses or changes its project takes the next number in its new scope, and its old label stops working.

**Lookups take the label.** The public page reads `:number` within the project in its URL. MCP and API tools take
an internal id, a `KEY-n` label, or a plain number for a task with no project.

**A one-time migration backfills every task, closed ones included.** It runs every rule and repo match to fill a
missing project and missing rule tags, never changing a project or tag the owner set. It keeps one project per
task: the one that owns the issue's repo, then the oldest link. It numbers each scope from 1 by `created_at`, ties
to the lower id.

## Alternatives

**Renumber `tasks.id` itself.** Every table that points at a task would have to change in step, and an id would
still be one count across every project.

**Keep project links in `record_links` and give out numbers in app code.** A task with two project links would have
no single scope to count in, and two tasks made at once could take the same number unless every path that makes a
task, captures, imports and repeats, held the same lock.

**Work numbers out at read time**, by counting a task's place in its project. A deleted or moved task would shift
every number after it, so a label would not name the same task from one day to the next.

## Consequences

A label is short and says where a task lives, and Postgres keeps it unique however a task arrives.

A label is not stable. Moving a task, or changing a key, breaks every link and note that named the old label, and
no alias keeps it working. Admin links keep the internal id, so they survive both.

Every reader of a task's project moves from `record_links` to the column. A project still links to every other
kind through `record_links`.

A rule that names two projects today has to give one up, and no task can show in two projects.

The backfill writes every task row, and the admin change notice fires once per row unless the migration turns it
off. #1315 leaves that open.

[0017]: 0017-enforce-rules-over-stored-state-in-postgres-not-in-contracts.md
[0093]: 0093-link-any-two-records-through-one-record-links-table-in-a-links-slice.md
[0122]: 0122-widen-task-tag-rules-into-task-rules-that-assign-projects-and-match-a-projects-repo.md
[0157]: 0157-publish-a-projects-tasks-through-its-board-flag.md
[0160]: 0160-open-a-public-page-for-each-task-on-a-published-board-without-its-tags-or-time.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
