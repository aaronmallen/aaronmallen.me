---
id: "0096"
title: Search every kind through tsvector columns and one view in a search slice
status: active
created: 2026-10-03
area: [db, admin, api, mcp, assets, posts, projects, record, social, tasks, contact]
supersedes: ["0091"]
issue: "#299"
amended: ["#773"]
tags: [search, postgres, full-text, tsvector, gin, view, palette, slices]
---

# ADR 0096: Search every kind through tsvector columns and one view in a search slice

![Active][status]

## Context

The spec in #287 has the palette, a search screen, the API and the MCP find a phrase across tasks (open and
closed), posts, social posts, journal entries, commits, projects, work entries, people, messages and webmentions.
The admin is mine alone, so private journal entries, private commits and read messages count. A year of records has
to answer fast enough on the Pi that the palette does not lag as I type.

Those kinds live in eleven tables that `tasks`, `posts`, `social`, `record`, `projects` and `contact` own. The
`activities` view from [ADR 0052][0052] already unions most of them, but its text filter matches columns no index
covers, so it stays fast only while a date range keeps the rows few. A search has no date range.

Today the palette searches nothing but open tasks, fetched once from `GET /admin/tasks/palette` ([ADR 0091][0091]).

## Decision

**An index on each table.** Each searched table gains a stored generated `search_vector` column of type `tsvector`,
built with `to_tsvector('english', ...)` from its own text, with the title weighted `A` and the rest `B`, and a GIN
index on it. A social post's text lives in its parts, so `social_post_parts` carries the column, not
`social_posts`.

**One view.** `search_documents` unions the tables into one shape: kind, source id, title, the text to excerpt,
day, the parts a link needs, and the vector. Each branch selects its table's column as it stands, so Postgres pushes
the match into every branch and each one reads its own GIN index. A social post yields one row per part, and the
query keeps the best part per post. The day follows the `activities` view for each kind it shares; people and work
entries take the site day of `created_at`, and messages of `received_at`.

**One query.** The query parses the phrase with `websearch_to_tsquery('english', ...)`, ranks with `ts_rank`,
newest first on a tie, and narrows by kind and pages by number. It builds the short match with
`ts_headline` over only the rows it returns, since `ts_headline` reads the whole text.

**A `search` slice.** `slices/search` owns the relation, its repo and the query, and exports the query. The view
spans six slices' tables, so no one of them owns it, by the reasoning ADR 0052 gives for `activity`. `admin`
imports the query for the palette and the search screen, and `api` imports it for the endpoint and the MCP tool
([ADR 0088][0088]). The view joins the reads [ADR 0021][0021] lists: it reads the eleven tables and writes none.

**The palette asks search as I type.** A session-only admin route answers the query as JSON: the top 8 hits across
every kind, best first, each with its kind. The palette lists them as one Records group and labels each row with its
kind. It keeps what ADR 0091 settled for its route: no session answers 401, `return_to` stays alone, the answer
is `no-store`, and the row markup stays in Ruby through a `template`. The Tasks group comes from search, closed tasks
among them, so `GET /admin/tasks/palette` and `Admin::Actions::Tasks::Palette` go away in the change that adds the
route.

A new kind joins by giving its table a `search_vector` column and its GIN index, adding a branch to the view in a
new migration, and adding its name to the kinds the query accepts. Decisions (#272) joined this way in #773.

## Alternatives

**Query each table and merge in Ruby.** It needs no view and no slice. Every caller would run a query per kind, and
ranking and paging would run on rows pulled into memory, as ADR 0052 found for activity.

**Add text search to `activities`.** The view already unions most kinds. It has no vector to index and lacks
people, work entries and messages, and its rows carry what a timeline line needs, not what a search hit needs.
Widening it would tie two features to one migration every time either changes.

**Keep the view in an owning slice.** It saves a container and a `db` provider, but puts reads over five other
slices' tables in a slice named for something else, which ADR 0052 turned down for activity.

## Consequences

One query answers every caller, and each branch reads an index, so the cost grows with the matches, not the rows.

Adding a stored column rewrites each table once. A vector that should cover another column takes a new migration
that drops and adds it, and replaces the view with it.

The vectors hold `english` as a literal, since Postgres builds a generated column only from an immutable
expression. Every word stems by English rules, whatever its language.

Every owner's relation infers `search_vector` and never uses it. Postgres refuses to drop or change a column the
vector or the view reads, so a migration that touches one in an owner's table has to rebuild both.

The palette costs a round trip per search rather than one per page, so the route has to stay fast and the script
has to drop a reply that a newer one has overtaken.

[0021]: 0021-let-sql-read-another-slices-tables-never-write-them.md
[0052]: 0052-read-activity-through-one-view-across-every-content-kind.md
[0088]: 0088-hold-the-layer-the-api-and-mcp-share-in-the-api-slice-and-call-it-in-process.md
[0091]: 0091-fetch-the-palettes-open-tasks-from-a-session-only-admin-route-when-it-opens.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
