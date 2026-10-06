---
id: "0116"
title: Build the tag summary in the tags slice from each kind's tag lookup
status: active
created: 2026-10-06
area: [admin, api, mcp, decisions, posts, projects, record, tags, tasks]
issue: "#626"
tags: [tags, summary, scope, slices, exports, activity, view, admin, mcp]
---

# ADR 0116: Build the tag summary in the tags slice from each kind's tag lookup

![Active][status]

## Context

Spec #625 adds an admin page and a `read_tag` MCP tool that list everything carrying a tag name: posts and projects
(public tags) beside tasks, journal entries and decisions (private tags), grouped by kind. Drafts, archived projects
and done or canceled tasks show with their status marked.

Each of those kinds lives in its own slice, and each slice's relation already finds its records by tag name through
`tagged`. The exported queries built on them read one status alone: `queries.published_page_by_tag` in `posts` and
`queries.public_by_tag` in `projects` serve the public tag page.

[ADR 0074][0074] splits tags into a public and a private scope, and lets an admin screen read `tags` by name across
both. [ADR 0003][0003] lets a slice reach another only through its exports. Today `tags` imports from no slice, and
none of the five imports from `tags`.

## Decision

**One query in the `tags` slice builds the summary.** It finds the tag rows that carry the name in either scope, and
answers nothing when there are none, so the page and the tool can refuse an unknown name. It then asks each kind for
its records and groups them by kind.

**Each kind answers through a query its own slice exports.** `posts`, `projects`, `tasks`, `record` (for journal
entries) and `decisions` each export a query over their relation's `tagged` that keeps every status. `tags` imports
those five. The query holds no SQL over another slice's tables.

**`admin` and `api` import the summary query**, the way they import the review query under [ADR 0100][0100]. The
admin page calls it, and the `read_tag` tool reaches it through an `api` endpoint ([ADR 0088][0088]). `admin`
already imports from `tags`, and `api` gains its first import from it.

A new tagged kind joins the summary by exporting a tagged query from its slice and adding it to the summary.

## Alternatives

**Group rows from the `activities` view ([ADR 0052][0052]).** One relation already spans the kinds. It lost because
its rows are events, not records: a decision shows once per event and a task beside its comments and sessions. It
keeps only published posts, and its tag filter covers neither posts nor projects.

**A new view across the tag join tables**, the shape `search_documents` takes in a `search` slice
([ADR 0096][0096]). One query would read every kind. It lost because it takes a migration and a view whose columns
tie five slices' tables to one definition, for a page that reads one tag at a time and needs no index the join
tables lack.

## Consequences

The summary needs no schema change, and each kind keeps the rule for what counts as tagged in its own slice.

`tags` turns from a leaf into a slice that depends on five others. None of them may import from `tags` now without
closing a cycle, which [ADR 0003][0003] bars.

A summary costs a query per kind, plus the tag lookup, and the grouping runs in Ruby. That stays cheap while one tag
holds few records.

Each tagged slice exports one more query that reads every status, so a caller other than the summary could list
drafts or private records through it. Only `tags` imports them.

[0003]: 0003-reach-another-slice-only-through-its-exports.md
[0052]: 0052-read-activity-through-one-view-across-every-content-kind.md
[0074]: 0074-split-tags-into-a-public-and-a-private-scope.md
[0088]: 0088-hold-the-layer-the-api-and-mcp-share-in-the-api-slice-and-call-it-in-process.md
[0096]: 0096-search-every-kind-through-tsvector-columns-and-one-view-in-a-search-slice.md
[0100]: 0100-build-the-review-in-one-activity-query-that-admin-and-api-share.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
