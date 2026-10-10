---
id: "0022"
title: Declare the tags relation in every slice that tags
status: active
created: 2026-09-28
area: [db, lib, posts, projects, record, tags, tasks]
issue: AA-584
amended: [AA-809, "#76", "#718", "#954", "#992"]
tags: [tags, rom, relations, combine, slices, exports]
---

# ADR 0022: Declare the tags relation in every slice that tags

![Active][status]

## Context

AA-371 made a tag a row. `tags` holds a name and a colour, and each tagged kind has its own join table with real
foreign keys: `post_tags`, `project_tags`, `journal_entry_tags` and `task_tags`. It made tags a feature, so
`slices/tags` owns the table and its admin screen, while each feature owns its join table, since `post_tags` is
posts' business.

Every list of posts, projects, journal entries or tasks loads its tags with a ROM `combine`, as
`Posts::Repos::PostRepo#with_tags` does with `posts.combine(:tags)`. A `combine` runs inside one container and
cannot reach a relation in another slice.

The rule that a slice reaches another only through its exports says the tags slice should own the one relation.
The record on that rule turns down duplicating a relation into each container that needs it, because one table
then has several definitions. AA-561 item 2 found that `tags` has five, and asked for a decision.

## Decision

Each slice that tags declares its own `Relations::Tags` over the `tags` table: `posts`, `projects`, `record` and
`tasks`, beside the one in `tags`. Each is `schema :tags, infer: true` and includes `Blog::DB::Tags`
(`lib/blog/db/tags.rb`), which holds what the relation does: `by_names`, `claim`, `next_color` and the rest. Each
join relation includes `Blog::DB::Taggings` (`lib/blog/db/taggings.rb`) and names its `owner_key`. #718 turns both
mixins into ROM relation plugins that a relation opts into with `use` (ADR 0126).

A tagging repo writes tags itself, as `post_tags.retag(id, names, tags)` in `PostMutations#replace_tags` does, and
the same in every other tagging repo. `claim` inserts each missing name with the least used colour and does nothing
for a name that exists. Since #76 it claims within a scope (ADR 0074): `posts` and `projects` claim public tags,
`record` and `tasks` private ones. Since #992 the join relation's `retag`, `tag` and `untag` claim and write the tags,
and `Blog::DB::Plugins::Taggings::SCOPES` names each join table's scope once, for the owner slice and for the tags
slice's counts.

Several slices write `tags`, an exception to reaching another slice only through its exports. It is not the only
table more than one slice writes: #954 names the tasks write to `record_links` in ADR 0021.

## Alternatives

**The tags slice owns the relation and exports a query and a `claim` operation.** One definition of the table, and
every tag written goes through the slice that owns it. It lost because a `combine` cannot cross a container, so
every tagged list would pay a second query for its tags.

## Consequences

A tagged list loads its tags in the same `combine` that loads the records.

One schema block has five copies, kept in step only by the mixin. A scope added to one relation and not to
`Blog::DB::Tags` leaves the other four behind, which is the cost the record on exports names.

A new tagged kind needs a tags relation and a join relation in its own slice, a `replace_tags` repo method, and a
`JOINS` entry in `Tags::Relations::Tags` so the tags screen counts it. Since #76 it also picks a scope, and its join
table holds a `tag_scope` column pinned to that scope (ADR 0074). Since #992 that scope goes in `Taggings::SCOPES`.

A tag that `claim` writes runs none of `Tags::Contracts::TagContract`. Its name passes only the tagged record's
contract, through `Blog::Types::TagList` and the `tag_slugs` rule, and the `tag_name` domain in Postgres.

Nothing sees a relation declared over another slice's table, so nothing stops the next one being over a table that
is not `tags`.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
