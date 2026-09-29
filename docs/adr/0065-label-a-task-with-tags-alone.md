---
id: "0065"
title: Label a task with tags alone
status: active
created: 2026-09-28
area: [db, lib, activity, admin, mcp, tasks]
issue: "#17"
tags: [tasks, tags, task-types, schema, migrations, admin, mcp, activity]
---

# ADR 0065: Label a task with tags alone

![Active][status]

## Context

A task carries two sets of labels: one task type and any number of tags. A type is a row in `task_types` with a
name, a colour, an optional icon (ADR 0033) and a place in an order, and `tasks.task_type_id` holds it with
`ON DELETE RESTRICT`. Types have their own admin screen and palette row, a filter and a Types link on the tasks
page, a select in the task editor, `TypeTag`, the colour on the task key, the `type:` search term, the "task typed"
line in the activity feed, and four MCP tools: `list_task_types`, `save_task_type`, `reorder_task_type` and
`remove_task_type`.

After a few days of use, types felt like overhead. They take a screen of their own, allow one per task, and do
nothing tags can't. Spec #16 retires them.

## Decision

A task's tags are its only labels.

Each type becomes a tag. Its name turns into a lowercase slug that fits the `tag_name` domain, so "Bug Fix" becomes
`bug-fix`, and the tag is claimed the way `claim` claims any tag (ADR 0022). Every task that held the type gets
the tag. A type whose slug matches a tag that exists merges into that tag.

The site is live, so new migrations do the work, in the order the schema forces: rebuild the `activities` view
without the type, move the data, drop `tasks.task_type_id`, then drop `task_types`.

Everything built on types goes with them, as the Context lists it. Tags gain no icon and no order, and the task key
shows no colour.

## Alternatives

**Keep types beside tags.** It keeps each task's one-word kind and its colour on the key. It lost because a type
still needs its own screen and still does nothing a tag can't.

**Give tags a "type" flag.** It keeps one table and would let a flagged tag stand in for the type. It lost because
the flag keeps the two sets of labels the spec sets out to end, only now inside one table.

## Consequences

Type icons go, and a tag has none to take their place. `config/solid_icons.txt`, `Blog::Types::TaskTypeIcon` and
`mise run assets:icons` serve only type icons, so nothing reads them once types go.

Type order goes. Tags sort by name wherever they list.

The task key loses its colour. A task can hold many tags, so no one tag's colour can take the type's place. A new
tag also takes the least used colour, as `claim` gives it, not the colour its type had.

Tags share one namespace across posts, projects, the journal and tasks (ADR 0022). The new tags list on the tags
screen beside the others, and a type that merges into a post's tag leaves that tag naming posts and tasks alike.

Finding the tasks of one kind goes through the `tag:` search term, not a filter on the tasks page.

It is hard to undo. Once `task_types` drops, bringing types back means building their rows again and deciding, for
each task, which of its tags was its type.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
