---
id: "0198"
title: Make a short code from its row id in base 36 and match it whole
status: active
created: 2026-10-20
area:
  - db
  - lib
  - shares
  - social
  - admin
  - api
  - mcp
supersedes:
  - "0194"
issue: "#1887"
tags:
  - shares
  - share-groups
  - short-links
  - short-codes
  - aa-cool
  - base-36
  - exact-match
  - vanity-codes
---

# ADR 0198: Make a short code from its row id in base 36 and match it whole

![Active][status]

## Context

Files, share groups and short links draw their codes from one `short_codes` table ([ADR 0143][0143]).
[ADR 0194][0194] gives each new code 8 random characters, pads a typed code to 8, opens the oldest record under
any prefix of a code and shows each record at its shortest prefix. Making one short code that way takes a retry
loop in 7 operations, a padding helper and the `short_coded` SQL plugin: about 180 lines.

`short_codes` already holds one auto-incremented id that every coded record shares. Spec #1886 makes that id the
code.

## Decision

**Codes.** A new generated code is its `short_codes` row's id in base 36, `id.to_s(36)`: lowercase letters and
digits. Codes start at one or two characters and grow as the table fills, to 3 characters past id 1295.

**Vanity codes.** A code the owner types goes in the same `code` column in place of the generated one, stored as
typed with no padding. A typed code that another record holds is refused. A generated code that clashes with a
vanity code takes the next id, and the clashing id goes unused.

**Paths.** The share host opens a record only when the path matches its whole code. Any other path answers 404.
The admin, the API, MCP and `Social::Operations::ShortenLinks` show the stored code as it is.

**Old codes.** Codes that exist today keep their stored values, the 8 character codes and padded vanity codes
among them, and open by exact match like any other.

A new migration drops the `short_code` domain's 8 character minimum. The `short_coded` plugin, `ALPHABET`,
`LENGTH` and `Code.pad` go.

## Alternatives

**Keep prefix lookup.** Codes made in order are already as short as they can be, so the prefix branch of
`resolved_id` and the shortest prefix display have nothing left to shorten.

**Base 62.** Upper case would make codes shorter, but needs a helper module where Ruby's base 36 takes one call,
and the `short_code` domain's lowercase pattern would have to change.

**Backfill old codes.** Rewriting codes would break every link we already sent. Old codes cost nothing to keep,
since exact match opens them.

## Consequences

A new code needs no draw, no retry on a clash with another random code and no padding.

A shortened prefix URL sent since v26.10.27, in a social post or anywhere else, stops working and answers 404.

Codes come in order, so anyone can walk them and find every share and short link, and a code tells how many came
before it. [ADR 0178][0178] already treats a code as a name, not a secret.

The table holds codes of two shapes, 8 random characters from before this change and short base 36 codes after,
for as long as the old rows last.

[0143]: 0143-send-outside-links-in-social-posts-through-aa-cool-short-links.md
[0178]: 0178-give-each-new-short-code-the-shortest-length-with-a-free-code.md
[0194]: 0194-resolve-a-short-code-by-its-prefix-and-let-the-oldest-code-win.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
