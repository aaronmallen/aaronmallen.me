---
id: "0074"
title: Split tags into a public and a private scope
status: active
created: 2026-09-29
area: [db, lib, admin, mcp, posts, projects, record, tags, tasks]
issue: "#76"
amended: ["#284", "#911"]
tags: [tags, scope, schema, migrations, constraints, foreign-keys, mcp, admin]
---

# ADR 0074: Split tags into a public and a private scope

![Active][status]

## Context

Tags share one namespace across posts, projects, the journal and tasks (ADR 0065). Every tagging slice claims from one
`tags` table through `Blog::DB::Plugins::Tags` (ADR 0022), and `tags_name_key` keeps each name unique. `#hanakai` on a
post and `#hanakai` on a task are one row with one color, so recoloring a task tag changes what readers see. Spec #67
splits them.

## Decision

A tag is **public** or **private**. Posts and projects take public tags. Tasks and journal entries take private
tags.

`tags` gains a `scope` column of a new `tag_scope` enum, and `tags_scope_name_key UNIQUE (scope, name)` replaces
`tags_name_key`. A name can exist once in each scope, and each row keeps its own color.

Postgres holds each join table to its scope, as ADR 0017 asks of a rule over stored state. `tags` adds
`UNIQUE (id, scope)`. `post_tags`, `project_tags`, `journal_entry_tags` and `task_tags` each gain a `tag_scope`
column with a default and a `CHECK` that pin it to the join's side, and the foreign key on `tag_id` becomes
`(tag_id, tag_scope) REFERENCES tags (id, scope)`. A post can then never hold a private tag, whichever code writes
the row. The key first said `ON DELETE RESTRICT`. #284 made it `ON DELETE CASCADE`, so deleting a tag takes it off
every record that carries it, and `decision_tags` and `task_rule_tags` follow the same rule.

`Blog::DB::Plugins::Tags#claim` and `#next_color` take a scope, so a new tag takes the least used color within its
scope. Each slice's repo passes its own: `posts` and `projects` claim public tags, `record` and `tasks` claim private
ones. As #911 records, `decisions` and `contact` claim private tags too.

New migrations split the data. A tag joined from both sides becomes a public row and a private row with the same
color, and its joins move to match. A tag joined from one side takes that side's scope.

The MCP tools `list_tags`, `save_tag` and `remove_tag` require `scope` and refuse a call without one.

## Alternatives

**Two tables, `public_tags` and `private_tags`.** It keeps each scope apart with no guard on the joins. It lost
because every tagging slice, `Blog::DB::Plugins::Tags` and the tags screen would need two of everything, and ADR 0022
already pays for five copies of one relation.

**One scope per kind.** Posts apart from projects, tasks apart from the journal. It lost because a post and a
project on the same subject should share a tag page, and nothing asks for task tags apart from journal tags.

**Guard the joins in the repos.** Each repo already passes its scope to `claim`, so the join would only ever
point at the right side. It lost because it binds only the code that runs it, which ADR 0017 turns down.

## Consequences

Each join row repeats a scope that its table already fixes. That buys the guard with a plain foreign key and no
trigger, and `Blog::DB::Plugins::Taggings#replace` writes no new column, since the default fills it.

A tag cannot move from one scope to the other. Its joins pin it, and the spec leaves moving out.

A tag used on both sides today becomes two rows that drift apart from the first rename or recolor.

The MCP tag tools break old calls. That ships in 1.2.0, a minor bump under BreakVer.

A new tagged kind now also picks a scope and needs a join table held to it the same way.

Lookups through a join table, such as `/writing/tags/:tag`, the task `tag:` search and the activity tag filter,
read the right scope once the data splits. A lookup that reads `tags` by name alone sees both rows.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
