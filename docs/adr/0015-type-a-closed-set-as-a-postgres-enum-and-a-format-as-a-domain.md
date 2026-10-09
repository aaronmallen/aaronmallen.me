---
id: "0015"
title: Type a closed set as a Postgres enum and a format as a domain
status: active
created: 2026-09-28
area: [db, lib]
issue: AA-609
amended: [AA-758, AA-801, AA-819, "#17", "#791"]
tags: [postgres, schema, enums, domains, constraints, types]
---

# ADR 0015: Type a closed set as a Postgres enum and a format as a domain

![Active][status]

## Context

The schema pushes its rules into Postgres. Before AA-317 it did that with 54 `CHECK` constraints, no `CREATE TYPE`
and no `CREATE DOMAIN`, so each rule was written again at every column that needed it. `'mastodon','bluesky'`
appeared three times. `~ '\S'`, "not blank", appeared at least nine times. `posts` allowed `draft, scheduled,
published` and `social_posts` allowed `draft, scheduled, posted`, two lists a letter apart, each typed by hand.
Any copy could drift from the others.

## Decision

A column that takes one of a fixed list of values takes a Postgres enum. A text column that must match a format
takes a domain over `text`. A rule that relates two columns, such as `visitors <= views`, stays a `CHECK`, since
no type can say it. `config/db/structure.sql` holds 16 enums and 9 domains, and each list or pattern is written
once.

An array of a closed set is an array of its enum, so `posts.syndication_targets` and `social_posts.targets` are
`network[]` and need no `<@ ARRAY[...]` check.

An enum sorts in the order it was declared, so we declare it in the order it must sort. `network` is alphabetical
because `social_post_deliveries` orders by it (`in_network_order`), and a comment in
`config/db/migrate/20260928000005_create_posts.rb` says so. AA-758 added `sync_name`, which is
alphabetical because Today lists sync failures in that order, and a comment in
`config/db/migrate/20260928000018_create_sync_states.rb` says so.

One fact the UI draws belongs to the schema. `tag_color` holds the six `mk-*` theme tokens. AA-371 stored the
token rather than a hex value, because the theme resolves each token through `light-dark()`, so a stored token
reads in both themes. AA-801 took the task type icon out of the schema, and #17 retired task types with their
icons (ADR 0065).

One set grows by design and stays text. #791 checks `service_connections.provider` against the service definitions
in code, so a new service takes no migration ([ADR 0130][0130]).

`Blog::Types` keeps a Ruby enum for 11 of the 16 sets, and relations and operations take their values from it
(`slices/posts/relations/posts.rb`).

## Alternatives

**A `CHECK` constraint per column.** What the schema had. It lost because the same list or pattern sat at every
column that used it and could drift at any one of them.

**A text domain for a closed set too.** AA-317 weighed it: a domain over `text` is easier to change later. AA-317
asked that each set be weighed on its own rather than by reflex, and for each the domain lost because the values
look stable.

## Consequences

Adding a value is `ALTER TYPE ... ADD VALUE`. Removing or reordering one means building the type again, then every
column that uses it, and for `network` the `activities` view as well. Until the site deploys we edit the create
migration instead.

A new theme colour is a schema change, not only a stylesheet or a component change.

The sort rule lives in one comment. Nothing fails if someone declares a new enum out of order.

`Blog::Types` is a second copy, kept in step by hand, and no spec compares the two. A value missing from the Ruby
twin refuses input the database would take. A value missing from the enum passes the Ruby check and fails the
write, which a request spec that sends it would catch as a 500. The order drifts freely: `NetworkName` lists
`mastodon` first, where the enum sorts `bluesky` first. `code_challenge_method`, `oauth_token_type` and
`suggestion_edit_status` have no twin. Their values sit as plain strings in `lib/mcp/oauth/pkce.rb`,
`slices/mcp/repos/oauth_token_repo.rb` and `slices/suggestions/repos/suggestion_repo.rb`. No spec compares a
domain's pattern with its Ruby type either.

[0130]: 0130-keep-service-credentials-encrypted-in-a-services-slice-and-define-each-service-in-code.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
