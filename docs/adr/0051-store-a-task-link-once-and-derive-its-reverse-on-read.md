---
id: "0051"
title: Store a task link once and derive its reverse on read
status: active
created: 2026-09-28
area: [db, tasks]
issue: AA-761
amended: ["#631"]
tags: [postgres, schema, tasks, links, constraints]
---

# ADR 0051: Store a task link once and derive its reverse on read

![Active][status]

## Context

AA-760 links tasks to each other. A link has one of three types, and two of them read differently from each side. A
link where #1 **blocks** #2 reads "blocked by #1" on #2, and **duplicates** reads "duplicated by". **relates** reads
"relates to" from both sides. The editor also offers "blocked by", which is a **blocks** link seen from the other task.

The spec sets three rules: one link per pair of tasks in either direction, no task linked to itself, and deleting a
task removes every link to or from it. Each is a rule over stored rows, and ADR 0017 puts those in Postgres.

## Decision

A `task_links` table in the tasks slice holds each link as one row: `from_task_id`, `to_task_id` and `type`. The
type is a `task_link_type` enum of `blocks`, `relates` and `duplicates`, following ADR 0015. The row runs from
the task whose label is the type's own name, so "#1 blocked by #2" saves as `blocks` from #2 to #1. The reverse
label is never stored. The tasks slice works it out from which end of the row a task sits on when it reads the
links.

A fourth type, `parent`, came with #631. It runs from parent to child and reads "parent of" and "child of". A partial
unique index on `to_task_id` for `parent` rows holds a task to one parent, and a `synced` flag marks the links the
issue sync owns, as [ADR 0117][0117] says.

Postgres holds the three rules:

- a unique index on `least(from_task_id, to_task_id)` and `greatest(from_task_id, to_task_id)`, so a pair takes one
  link whatever its type or direction;
- a `CHECK` that `from_task_id` differs from `to_task_id`;
- a foreign key on each id to `tasks` with `ON DELETE CASCADE`.

The operation that adds a link maps the index and the `CHECK` to field errors by name, as ADR 0017 lays out.

## Alternatives

**Two rows per link.** A `blocked_by` and a `duplicated_by` type would let each task read its own rows with no
thought for direction. It lost because every write has to keep the pair in step, and a missed write leaves one side
claiming a link the other denies. The one-per-pair rule could no longer be a plain unique index either, since every
link would already fill the pair twice.

**A `links` jsonb column on `tasks`.** This is what the mock in `tmp/design` does. It lost because Postgres can hold
none of the three rules over it. No foreign key reaches into jsonb, so deleting a task has to walk every other task
and strip its id, the way the mock's `removeTask` does, and no index can see a pair split across two rows. The rules
would fall to Ruby, which ADR 0017 turned down.

## Consequences

Reading a task's links takes two joins, one where the task is `from_task_id` and one where it is `to_task_id`. The
"blocked" pill needs the second: a task is blocked by the `blocks` rows that point at it.

The code that reads a link must know which end it stands on to pick the label. A reader that forgets gets "blocks"
where it means "blocked by", and no constraint catches that.

A **relates** row still has a direction, and it means nothing. Code must not treat `from_task_id` on a `relates`
row as the side that made the link.

[0117]: 0117-sync-task-relations-into-task-links-with-a-parent-type-and-a-synced-flag.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
