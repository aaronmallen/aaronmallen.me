---
id: "0183"
title: Find tasks by label through a lookup ahead of full-text search
status: active
created: 2026-10-16
area: [admin, api, mcp, search, tasks]
issue: "#1486"
tags: [search, tasks, labels, keys, numbers, full-text, tsvector, palette, record-picker]
---

# ADR 0183: Find tasks by label through a lookup ahead of full-text search

![Active][status]

## Context

Spec #1482 makes every task search find a task by its label, `POD-23` or a bare `23`. Search runs on stored
tsvector columns and the `search_documents` view ([ADR 0096][0096]), and a task's vector holds its title and note.
The label is not stored: [ADR 0166][0166] works it out at read time from the project key and `tasks.number`, so a
task that moves or a project whose key changes takes its new label at once. The Postgres tokenizer also splits
`POD-23`, so a label in the text would not match as one term.

## Decision

**A label lookup runs ahead of each task search, and its tasks rank first.** The tasks slice owns one parser that
reads `23`, `#23`, `POD-23`, `pod-23` and `#POD-23`. A bare number matches every task with that number, in every
project and with none. A label with a key matches that one task, in any case. The lookup reads `tasks.number` and
the project key as they stand, then the usual title and note matches follow.

Every surface that searches tasks calls it: the admin link finder, the record picker, the task list and board
filter in the admin, the API and MCP `list_tasks`, and global search, the palette and MCP `search`. No surface
matches the internal `tasks.id`.

## Alternatives

**Put the label in the task's search vector.** A stored label goes stale when a task moves or a key changes, unless
a trigger rewrites every task in the project, and the tokenizer splits it anyway.

**Add a label column to the `search_documents` view.** The view would join projects for every search, every
migration that rebuilds the view would carry it, and only global search reads the view, so the other surfaces would
still need their own match.

## Consequences

A label finds its task the moment it changes, with no migration and nothing to keep in step.

Each search runs one more query, and the code that merges label hits with full-text hits has to drop the
duplicates and keep counts and paging right.

Each new surface that searches tasks has to call the parser, or it misses labels.

Only exact labels match. `POD-2` never finds `POD-23`, and a label from before a task moved finds nothing.

Public search ([ADR 0180][0180]) does not look up labels. Spec #1482 leaves that open.

[0096]: 0096-search-every-kind-through-tsvector-columns-and-one-view-in-a-search-slice.md
[0166]: 0166-give-each-task-one-project-and-a-number-postgres-gives-out-within-it.md
[0180]: 0180-search-the-public-site-through-a-view-that-holds-only-public-rows-and-public-text.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
