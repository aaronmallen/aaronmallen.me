---
id: "0097"
title: Keep saved views in their own slice with a screen enum and jsonb filters
status: active
created: 2026-10-03
area: [db, lib, admin, api, mcp]
issue: "#315"
tags: [saved-views, slices, schema, enums, jsonb, filters, admin, api, mcp]
---

# ADR 0097: Keep saved views in their own slice with a screen enum and jsonb filters

![Active][status]

## Context

The spec in #291 keeps the filters on the tasks, posts, journal and activity screens in the database, so I can open
them again under a name. The admin saves and opens a view, the palette lists them (#320), and the API and MCP
list, create, change, delete and read them (#322, #324).

Each screen reads its filters from params, and each param falls back to its default when the value is one the
screen does not take (`Blog::Types::TaskTabParam`, `PostFilterParam`). Activity reads `from`, `to`, `q`, `day` and
`types`, and `types` comes as a hash, `types[post]=1`. Posts read `status`. Tasks read `filter`, `pool` and `q`.
The journal reads `q`, `to` and `write`.

Three things are hard to change once rows exist: which slice owns the table, how the screen is typed, and how the
filters are kept. The schema has no `jsonb` column yet.

## Decision

**A new feature slice, `saved_views`, owns the `saved_views` table.** It holds the relation, repo, contract and the
operations to create, rename, change and delete a view, and exports those operations and a query that lists views.
`admin` and `api` import them, and `mcp` reaches them through the `api` endpoints ([ADR 0088][0088]). The slice
imports nothing.

**The screen is a Postgres enum, `saved_view_screen`**, with the values `activity`, `journal`, `posts` and `tasks`,
declared in that order so views list by screen alphabetically ([ADR 0015][0015]). `Blog::Types::SavedViewScreen`
is its Ruby twin.

**The filters are one `jsonb` column**, an object of the params as the screen reads them: strings, and for
activity's `types` an object of strings. A `CHECK` holds it to an object. The slice keeps the names each screen
knows, and saving keeps only those, so `page` and stray params never land in a row.

**A screen ignores a filter it no longer knows.** Reading a view drops every key its screen does not list and hands
the rest to the screen as if they came from the URL. A value the screen no longer takes falls back to its default
through the same type a URL param goes through. The row stays as it was until I change the view, which replaces
its filters with the screen's current ones.

## Alternatives

**Let `admin` own the table.** The screens and the Save view button live there. It lost because a presentation slice
owns only the rows its own door needs ([ADR 0001][0001]), and because `api` would have to import from `admin`, which
already imports token operations from `api`. That is a cycle [ADR 0003][0003] refuses.

**Put the table in an existing feature slice**, such as `tasks`. It saves a slice. It lost because a view belongs to
four screens across `tasks`, `posts`, `record` and `activity`, and no one of them owns the others' filters.

**Keep the filters as a query string in `text`.** It loads by appending to the screen's path. It lost because
dropping an unknown key means parsing the string, Postgres cannot check its shape, and the API would hand agents a
string to parse.

**One typed column per filter.** Postgres would type each one. It lost because the four screens share almost no
filters, so each row would leave most columns empty, every new filter would take a migration, and a filter a screen
dropped would leave a column behind.

**Fail a view that holds an unknown filter.** It tells me the view went stale. It lost because #291 asks that the
screen fall back to its default, and a filter dropped from a screen should not cost me the rest of the view.

## Consequences

The admin, the palette and the API share one way to keep a view, and the slice graph gains no cycle.

Adding a screen is `ALTER TYPE ... ADD VALUE`. Removing one means building the type again.

Saved views bring the first `jsonb` column to the schema, so the relation is the first to read and write one
through ROM.

The names each screen knows live twice: in the `saved_views` slice and in the admin action that reads the params.
Nothing compares the two. A filter added to a screen but not to the slice never saves, and one renamed on the screen
alone stops loading without an error.

Postgres checks only that the filters form an object, not the keys or values inside it. The contract and the
screens' fallbacks carry the rest.

A row can keep a filter no screen reads for as long as I leave the view alone.

[0001]: 0001-split-the-app-into-slices-by-feature.md
[0003]: 0003-reach-another-slice-only-through-its-exports.md
[0015]: 0015-type-a-closed-set-as-a-postgres-enum-and-a-format-as-a-domain.md
[0088]: 0088-hold-the-layer-the-api-and-mcp-share-in-the-api-slice-and-call-it-in-process.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
