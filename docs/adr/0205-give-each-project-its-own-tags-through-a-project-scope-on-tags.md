---
id: "0205"
title: Give each project its own tags through a project scope on tags
status: active
created: 2026-10-23
area:
  - db
  - lib
  - admin
  - api
  - mcp
  - public
  - agents
  - decisions
  - links
  - mail
  - notes
  - posts
  - projects
  - record
  - tags
  - tasks
issue: "#1948"
tags:
  - tags
  - scope
  - projects
  - schema
  - constraints
  - foreign-keys
  - record-links
  - labels
  - sync
  - board
  - public
  - privacy
---

# ADR 0205: Give each project its own tags through a project scope on tags

![Active][status]

## Context

[ADR 0074][0074] splits tags into a public scope for posts and projects and a private scope for everything else.
Every private tag shares one list, so tags made for one project crowd the list, the picker and `list_tags` for every
other kind and project. Spec #1947 gives each project its own tags, and a project board a filter over them.

Each tag join holds a `tag_scope` column pinned by a `CHECK`, and its foreign key `(tag_id, tag_scope)` points at
`tags (id, scope)`, so Postgres keeps every join on its side ([ADR 0017][0017]). Tasks, sessions and project memory
files point at one project through a `project_id` column ([ADR 0166][0166], [ADR 0199][0199]). Decisions, notes,
journal entries, mail threads, posts and artifacts have no such column, and reach a project only through
`record_links` ([ADR 0093][0093]).

## Decision

**`tag_scope` gains `project`, and `tags` gains a `project_id`.** A `CHECK` sets `project_id` on a project tag and on
no other. A project tag's name is unique within its project, so two projects each hold their own `bug`, with its own
tone and description. Names in the public and private scopes stay unique within the scope. The private scope is the
global tag list.

**The joins admit the project scope.** Each join pinned to the private scope also admits `project`, and so does
`post_tags`. `project_tags` stays pinned to the public scope: it holds the public tags on a project, not the
project's own tags. Agent sessions, memory files and artifacts gain joins to `tags`, and an artifact's `text[]` tags
move into its join. Every join still points at `tags` by id, so `page_by_tag`, the tag summary
([ADR 0116][0116]) and the MCP tag tools keep working by tag id.

**A record relates to a project through its own project, or else through its record links.** A task, a session and
a project memory file relate to their `project_id`. Every other kind relates to each project it links to, so it can
relate to several. A record related to a project carries only that project's tags, never private ones: any tag added
to it in the admin, the API or the MCP becomes a project tag, made in the project when missing. A record linked to
several projects takes the name from each that holds it, and a name none of them holds is made in each. The picker
offers the tags of every project the record relates to. Posts keep their public tags beside any project tags, in a
field of their own, and no public page shows the project ones.

**Tags follow the record when its project changes.** A task that moves to another project takes its tags there by
name, and a name the new project lacks is made there with the old tag's tone and description. A task that leaves
every project keeps its tags by name as private tags. Removing a record's last link to a project drops that
project's tags from the record, through a trigger on `record_links`. A task rule that files into a project holds that
project's tags, and a rule with no project keeps private tags.

**Labels on a synced issue become project tags.** When a synced task sits in a project, each label on its issue
makes or uses a tag of that name in the project, at import and on every later sync. A label removed upstream leaves
the tag. A synced task with no project takes private tags from its labels at import alone, as
[ADR 0077][0077] says.

**Project tags stay out of the global tag screens.** The tag list, its picker, `/tags/:name` and `list_tags` without
a project leave them out. Each project tag has its own page at `/projects/:key/tags/:name`, which lists every record
holding it, grouped by kind as `/tags/:name` is.

**A published board makes its project's tags public, and nothing else does.** Its cards show them and its filter
reads them ([ADR 0157][0157]). No other public page shows a project tag, so an unpublished board's tags never reach
the public site.

A one-time migration moves every private tag on a record related to a project into that project's tags, a copy in
each project when it relates to several, and deletes each private tag left on nothing.

## Alternatives

**A separate project tag table, with a join to it for each kind.** It needs about ten new join tables, and a second
copy of every tag query, relation and screen to read them.

**One polymorphic join holding a kind and a record id.** It cannot hold a foreign key to the record, which
[ADR 0017][0017] turns down.

## Consequences

The tag code stays one model: one table, one set of joins, one summary and one set of MCP tools. `claim` and the tag
writes take a project beside the scope, and a join row for a project tag sets `tag_scope` rather than relying on the
default.

Postgres holds the scope of each join, but not which project a tag belongs to. For kinds related through
`record_links` the tie lives in another table, so the tagging code keeps it, and a write that skips that code can tag
a record with another project's tags.

The name `project_tags` reads as the project's own tags, but the table holds the public tags on a project.

A tag the owner removes from a synced project task comes back on the next sync while the issue keeps the label,
since no sync stores the labels it saw. That is the cost ADR 0077 turned down, now taken for project tasks.

Publishing a board publishes every tag of its project, made by hand, by a rule or from a label, so a tag name has to
be fit to read.

A record that drops its last link to a project loses that project's tags, and getting them back takes the link and
each tag again. A task that moves keeps them.

A new tagged kind now also decides how it relates to a project, and its join admits the project scope.

[0017]: 0017-enforce-rules-over-stored-state-in-postgres-not-in-contracts.md
[0074]: 0074-split-tags-into-a-public-and-a-private-scope.md
[0077]: 0077-tag-an-imported-task-from-its-labels-only-on-import.md
[0093]: 0093-link-any-two-records-through-one-record-links-table-in-a-links-slice.md
[0116]: 0116-build-the-tag-summary-in-the-tags-slice-from-each-kinds-tag-lookup.md
[0157]: 0157-publish-a-projects-tasks-through-its-board-flag.md
[0166]: 0166-give-each-task-one-project-and-a-number-postgres-gives-out-within-it.md
[0199]: 0199-attach-agent-memory-and-sessions-to-projects-and-treat-a-repo-as-a-lookup.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
