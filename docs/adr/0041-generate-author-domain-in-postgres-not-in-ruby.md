---
id: "0041"
title: Generate author_domain in Postgres, not in Ruby
status: active
created: 2026-09-28
area: [db, social]
issue: AA-289
amended: [AA-537, AA-682]
tags: [webmentions, types, postgres, hosts]
---

# ADR 0041: Generate `author_domain` in Postgres, not in Ruby

![Active][status]

## Context

`Blog::Types::Normalized::Host` (`lib/blog/types.rb`) is the one host parser in Ruby. AA-286 and AA-289 moved every
call site onto it so that two parts of the app cannot read two different hosts out of one URL.

The `webmentions` table does not use it. `author_domain` is a stored generated column with a regex of its own
(`config/db/migrate/20260928000007_create_webmentions.rb`, `config/db/structure.sql`):

```sql
lower("substring"(author_url, '^[^:]+://(?:[^@/]*@)?([^/:?#]+)'))
```

The column is what a reader sees. `Social::Structs::Webmention#author_label` falls back to it when a mention carries
no author name, and the admin's webmention rows, its pending card and the responses under a public post all draw
that label. The `activities` view coalesces the column the same way.

No Ruby code reads the column to decide anything. `Social::Operations::VerifyWebmention#approved?` compares the
source host with the author host, both read through `Normalized::Host`, then asks
`Social::Repos::WebmentionRepo#known_author?`, which matches the whole normalized `author_url` (AA-463, AA-520).

The two parsers agree on every http and https URL, with or without credentials, with or without a port, whatever
the case. They part on one shape: an IPv6 literal host. Postgres stops the capture at the first colon and stores `[`
for `http://[::1]/`, where Ruby reads `::1`.

Closing the gap means dropping the generated column and writing the domain from Ruby.

## Decision

Postgres keeps generating `author_domain`. Ruby keeps reading hosts only through `Blog::Types::Normalized::Host`. We
accept that the two parsers read an IPv6 literal host differently.

## Alternatives

**Write `author_domain` from Ruby and drop the generated column.** One parser, and the column would hold the host
Ruby reads. It loses on price. Every write that sets `author_url` would have to set the domain too, and could
forget, where a generated column cannot drift from the URL it reads. Once the site deploys it also means a
migration that rebuilds the `activities` view and a backfill of every stored row. What it buys back is a label for
an author URL that names an IPv6 address instead of a host name.

**Teach the column the IPv6 shape.** Still two parsers, and the second one is now harder to read than the first.

## Consequences

The column holds `[` for a mention whose `author_url` names an IPv6 literal host, so a mention with no author name
shows `[` in the admin, under the post and in the activity feed. Nothing else reads wrong, because approval never
reads the column. The table indexes `author_url`, not `author_domain`.

The rule that Ruby reads hosts one way has an exception nobody can see from the Ruby code. A second host parser
sits in SQL, and no spec compares it with `Normalized::Host`, so a later change to either parts the two further and
nothing fails.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
