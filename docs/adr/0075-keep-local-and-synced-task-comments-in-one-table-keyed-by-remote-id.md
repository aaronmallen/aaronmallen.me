---
id: "0075"
title: Keep local and synced task comments in one table keyed by remote id
status: active
created: 2026-09-29
area: [db, admin, mcp, activity, tasks]
issue: "#70"
amended: ["#903"]
tags: [tasks, comments, schema, sync, github, linear, providers, constraints, markdown]
---

# ADR 0075: Keep local and synced task comments in one table keyed by remote id

![Active][status]

## Context

Spec #65 adds comments to tasks. The operator writes some in the admin or through MCP. The GitHub and Linear
syncs pull the rest in from each issue, and an edit or deletion on the provider has to reach the copy on the next
sync. The task view, `read_task` and the activity feed (ADR 0052) all list both kinds together, oldest first.

## Decision

Every task comment lives in one `task_comments` table that the tasks slice owns.

A synced row carries its provider and the comment's id on that provider. A unique index on the two means a second
sync updates the row it wrote before, not a new one, the way `task_sources` keys an issue (ADR 0066, ADR 0068). A
local row carries neither. Postgres holds the two to be set together or not at all (ADR 0017).

Comments only flow in. Nothing posts a local comment to GitHub or Linear, and the admin and MCP edit or delete
local rows alone. A synced row changes only when the sync does it.

A comment body renders as Markdown through the sanitize path in ADR 0072, whichever kind it is.

## Alternatives

**Two tables, one for local comments and one for synced ones.** Each would hold only the columns its kind needs,
with no empty provider on a local row. It lost because the task view, `read_task` and the activity view would each
read both tables and merge them by time, and every new reader would have to remember to do the same.

## Consequences

One query lists a task's comments in order, and the activity view joins one table for the new kind.

Provider and remote id sit empty on every local row. Each write path has to tell the two kinds apart by those
columns, and an edit or delete that forgets the check would change a synced comment that the next sync puts back.

A sync reads only the first 100 comments of an issue. Since #903, when an issue has more, the sync adds and
updates the copies it read and removes none, so a copy of a deleted comment stays until the issue is back to 100 or
fewer.

Adding a provider reuses the key as it stands, since the provider already sits in it.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
