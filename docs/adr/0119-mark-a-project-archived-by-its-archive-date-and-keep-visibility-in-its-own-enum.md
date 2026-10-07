---
id: "0119"
title: Mark a project archived by its archive date, and keep visibility in its own enum
status: active
created: 2026-10-07
area: [db, lib, activity, admin, api, mcp, projects, public, search]
issue: "#646"
tags: [projects, archive, visibility, schema, enums, migrations, views]
---

# ADR 0119: Mark a project archived by its archive date, and keep visibility in its own enum

![Active][status]

## Context

A project's `status` answers two questions at once: do I still maintain it, and may the public see it. Archiving
ActiveInteractor took it off the site, though the owner wants it listed as a past project. Spec #645 splits the two
apart. A project is active or archived, and public or private, and `wip` and `paused` go.

Today `projects.status` is a `project_status` enum of `active`, `wip`, `paused` and `archived`, and `archived_on`
is a date beside it. `projects_archived_on_check` lets `archived_on` hold a date only while `status` is `archived`,
and `ArchiveProject` and `RestoreProject` write both columns each time. The schema says "archived" twice and spends
a check and two operations keeping the copies in step.

The owner keeps the archive date: ActiveInteractor has sat archived for years, and its date should survive.

## Decision

We drop `projects.status` and the `project_status` enum. A project with an `archived_on` date is archived, and one
without is active. `ArchiveProject` sets the date and `RestoreProject` clears it. `projects_archived_on_check` goes
with the column, and `projects_archived_order_check` stays.

Visibility takes a new `project_visibility` enum of `public` and `private`, as [ADR 0015][0015] asks of a closed
set. `projects.visibility` is `NOT NULL` with no default, so every write names one. The migration sets every
existing project to `public` before it adds the constraint. `Blog::Types::ProjectVisibility` is its Ruby twin.

We do not reuse `tag_scope`, though it holds the same two values. `tag_scope` says which side of the `tags` table a
tag lives on, and every tag join pins it through a `CHECK` and the `(tag_id, tag_scope)` foreign key
([ADR 0074][0074]). A value added to it for tags would turn up as a visibility for projects. The schema already keeps
`post_status` and `social_post_status` apart for the same reason, though they share two values.

## Alternatives

**Shrink `project_status` to `active` and `archived`.** It keeps two columns for one fact, and the check would have
to run both ways, so that `archived` without a date fails as well as a date without `archived`. Removing values
from an enum means building the type again, and the views that read it, so it costs no less than dropping it.

**Keep the four values behind a `CHECK` that allows only `active` and `archived`.** No rebuild, but the type keeps
two values no row may hold, `Blog::Types` would have to drop them from its twin, and the two columns still need a
check both ways to stay in step.

**Reuse `tag_scope` for visibility.** One list of `public` and `private` in the schema rather than two. It lost
for the reason in the decision: the two types mean different things and would change together.

## Consequences

The schema holds "archived" once, and no row can be archived without a date or carry a date while active.

The `activities` and `search_documents` views select `projects.status`, so the migration drops and rebuilds both.
Each derives the status from `archived_on` instead, so the activity feed and search still show one.

The API and MCP derive the status too. `list_projects`, `read_project` and the API's project serializer report
whether a project is archived from its date, and nothing in Ruby can set the two apart again. `ProjectStatus` and
`ProjectLiveStatus` leave `Blog::Types`.

Filtering archived projects means `archived_on IS NULL` or `IS NOT NULL`. `projects_archived_on_index` already
covers it.

`project_visibility` and `tag_scope` hold the same two values in two places, and nothing keeps them alike. That is
the point, but a reader who sees both may take one for a copy of the other.

[0015]: 0015-type-a-closed-set-as-a-postgres-enum-and-a-format-as-a-domain.md
[0074]: 0074-split-tags-into-a-public-and-a-private-scope.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
