---
id: "0093"
title: Link any two records through one record_links table in a links slice
status: active
created: 2026-10-03
area: [db, admin, api, mcp, posts, projects, record, social, tasks]
issue: "#317"
tags: [postgres, schema, links, slices, exports, triggers, constraints, enums]
---

# ADR 0093: Link any two records through one record_links table in a links slice

![Active][status]

## Context

Spec #286 links any two records of eight kinds: task, post, social post, journal entry, commit, project, work entry
and decision. A link shows on both records and has no type or direction. #278 planned a `task_decisions` join, and
every other pair would have needed one of its own. The brainstorm on #286 chose one shared table instead.

The eight kinds live in six slices: `tasks`, `posts`, `social`, `record`, `projects`, and the `decisions` slice #273
records. Each link page needs the other record's title and admin URL, and the picker searches every kind.

The spec asks Postgres to hold the rules (ADR 0017): one link per pair in either order, no record linked to itself,
ids that point at a real row, and a delete that takes the record's links with it. A foreign key names one table, so
no foreign key can hold a column whose table depends on the row.

## Decision

**A new `links` feature slice owns `record_links`.** The table spans kinds six slices own, so no one of them owns it,
the way `activity` owns its view (ADR 0052). It exports operations to link and unlink two records, a query that lists
a record's links, and a search across kinds. `admin`, `api` and `mcp` import them.

**Each side is a kind and an id.** A `record_kind` enum (ADR 0015) holds the eight kinds, declared in the order above,
since the Linked section groups by kind in that order. A row holds `left_kind`, `left_id`, `right_kind`, `right_id`
and `created_at`. The operation sorts the two sides, kind first and then id, so a pair has one spelling.

**Postgres holds the rules.**

- `record_links_pair_key`, a unique index on the four columns, holds one link per pair. With the sides sorted, the
  pair in either order lands on the same key.
- `record_links_order_check` holds `(left_kind, left_id) < (right_kind, right_id)`. Since the operation sorts, only a
  record linked to itself can break it.
- `record_links_task_pair_check` refuses a task on both sides. Task to task links stay in `task_links`, with their
  types (ADR 0051).
- A trigger before insert finds the row each side names in its kind's table, and locks it `FOR KEY SHARE` as a
  foreign key would. A missing row raises with `ERRCODE = 'foreign_key_violation'` and `CONSTRAINT =
  'record_links_record_missing'`.
- An `AFTER DELETE` trigger on each of the eight tables runs one function, which takes its kind as the trigger's
  argument and deletes every link on either side that names the old row. A cascade from another table fires it too.

`Links::Operations::LinkRecords` maps the four names to field errors as ADR 0017 lays out: `taken`, `self`,
`task_pair` and `missing`.

**Titles and searches cross through exports** (ADR 0003). Each owning slice exports one query per kind, which names
its records by id and finds them by text, and `links` imports all eight. The list query builds each admin URL from
the kind and id through the app's routes helper (ADR 0004), so the pages and the tools share one map from kind to
route.

## Alternatives

**A join per pair**, as #278 planned for tasks and decisions. Each table could hold real foreign keys. It lost in
the #286 brainstorm: eight kinds make 27 pairs beside `task_links`, and every new kind adds a table per kind already
there.

**Clean up in each delete operation**, the way photo claims do (ADR 0082). It needs no trigger on another slice's
table. It lost on two counts. Each of the six slices would import an unlink operation from `links`, while `links`
imports a query from each of them, and ADR 0003 allows no such cycle. It also binds only the deletes that run
through the operation, so a cascade or a new delete path would leave links behind.

**Allow a task to task pair here as well.** One picker could then link any two records with no exception. It lost
because a pair of tasks could then hold two links in two tables, one with a type and one without.

**A view across the eight tables for titles and search**, the way activity reads (ADR 0052, ADR 0021). It would
search every kind in one query. It lost because Postgres will not let a migration change a column a view reads, so
every change to one of eight tables would rebuild the view, and the exports already name each record.

## Consequences

One table, one operation and one query serve every pair, and a new kind joins by adding an enum value, a trigger on
its table, a branch in the insert trigger and an exported query.

`links` writes no other slice's rows, but its migrations attach a trigger to tables other slices own. A migration
that drops and rebuilds one of those tables loses its trigger, and nothing fails until a delete leaves a link
behind. The insert trigger reads those tables too. Both belong in the list in ADR 0021 when #319 builds them.

The operation sorts in Ruby by the enum's order, which Postgres compares on. ADR 0015 lets the Ruby twin of an enum
drift out of order, but here a twin out of order sends some pairs unsorted, and `record_links_order_check` refuses
them as a self link.

A search runs eight queries and merges them in Ruby, so results rank within a kind, not across kinds.

The list query names admin routes from a feature slice. Renaming one breaks the Linked section when it runs, not at
boot.

The `decision` kind needs the `decisions` table first, so #319 waits on it.

ADR 0001 counts the feature slices and ADR 0017 lists the mapped names. #319 updates both when it adds the slice.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
