---
id: "0066"
title: Keep an imported task's origin in a task_sources table
status: active
created: 2026-09-28
area: [db, tasks]
issue: "#9"
tags: [tasks, schema, imports, github, providers, enums, constraints]
---

# ADR 0066: Keep an imported task's origin in a task_sources table

![Active][status]

## Context

Spec #8 imports every open GitHub issue assigned to the operator as a task. Each sync has to find the task an issue
already became, so an issue never imports twice and GitHub's changes reach the right task. Each imported task links
back to its issue. Linear or Jira may follow, and each would bring ids and fields of its own.

`tasks` holds nothing that says where a task came from, and a task the operator makes has no origin at all.

## Decision

An imported task's origin lives in `task_sources`, one row per imported task. The tasks slice owns the table, and a
sync in another slice reaches the rows only through what tasks exports (ADR 0003).

A row holds the task, the provider, the issue's id on that provider and the issue's URL. `provider` takes a new
Postgres enum, since the providers form a closed set (ADR 0015). It holds `github` alone, and a new provider adds a
value. A unique index on provider and id means Postgres, not the sync, refuses a second import of one issue. A row
goes when its task does.

## Alternatives

**Source columns on `tasks`.** Provider, id and URL on the task itself, so no read needs a join. It lost because
the three columns would sit empty on nearly every row, and each provider that needs a field of its own would reshape
`tasks`.

**A new `task_list` value alone.** It would mark a task as imported. It lost because it cannot say which issue a task
came from, so a sync could neither match an issue to its task nor link back to it.

## Consequences

Every read that shows the link or asks whether a task is imported joins `task_sources`: the task struct and the
moves that send a task back to a list. The join stays inside the tasks slice, so a `combine` serves it. A read that
forgets the join treats an imported task as one the operator made, and nothing fails when it does.

`tasks` keeps its shape. A provider that needs a field the others lack adds a column to `task_sources`, where it sits
empty for the rest.

Adding a provider is a schema change: `ALTER TYPE ... ADD VALUE` in its own migration (ADR 0015).

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
