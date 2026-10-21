---
id: "0194"
title: Resolve a short code by its prefix and let the oldest code win
status: superseded
created: 2026-10-19
area: [db, shares, social, admin, api, mcp]
supersedes: ["0178"]
superseded-by: "0198"
issue: "#1856"
amended: ["#1887"]
tags: [shares, share-groups, short-links, short-codes, aa-cool, prefix, code-length, oldest-wins]
---

# ADR 0194: Resolve a short code by its prefix and let the oldest code win

![Superseded][status]

## Context

Files, share groups and short links draw their codes from one `short_codes` table ([ADR 0143][0143]).
[ADR 0178][0178] gives each new code the shortest length with a free code: `ShortCodeQueries#free_code` counts how
full each length is and draws from the shortest one with room. That logic is hard to follow. The share host matches
only a whole code, so a code stays as long as it was the day we made it.

Spec #1855 drops the length count for one fixed length, and lets the host answer any start of a code.

## Decision

**Codes.** Every new code for a file, a group or a short link is 8 random characters from the alphabet in
`Shares::Helpers::Code`. The only check is that no other code holds it. A code the owner types keeps its characters
as its start, and the app adds random ones until it has 8. Codes are 8 characters or more: a code made before this
change keeps its length when it is 8 or longer, and takes random characters on its end until it is 8 when shorter.

**Paths.** The share host answers any start of a code. A path that matches a whole code opens that record. Any other
path opens the oldest record whose code starts with it, oldest meaning the lowest `short_codes.id`, and a path no
code starts with answers 404. Given `abcdefgh`, then `abcefghj`, then `abcfghjk`, `/a`, `/ab` and `/abc` open the
first, `/abce` the second and `/abcf` the third. `/<prefix>.zip` and `/<prefix>/<id>` open the group the prefix
resolves to, and files in a group keep `/<group>/<id>` with no code of their own ([ADR 0163][0163]).

**Deletes.** A delete stays a hard delete. Once a record goes, the next oldest record under each of its prefixes
takes them over, with no state kept about the one that left.

**Shortest URL.** The admin, the API, MCP and `Social::Operations::ShortenLinks` show each record at the shortest
path that opens it, worked out when read. No column stores it.

## Alternatives

**Keep the shortest free length ([ADR 0178][0178]).** It gives short codes, but the length counting is hard to
follow, and a code never gets shorter once more codes exist beside it.

**6 characters.** The brainstorm started there. The owner picked 8 to make a clash between two random codes less
likely.

**Match only a whole code.** The host does that today. A code would open only at the length it was made.

**Answer 404 under a deleted code's prefixes.** It would stop an old short URL opening a new record, but it needs
state kept about records that no longer exist. The owner chose plain oldest wins over the rows that remain.

**Store each record's shortest path.** Every new code and every delete could change the shortest path of older
records, so a stored column would need rewriting on each one.

## Consequences

Picking a code no longer reads the table to count lengths, and random draws at 8 characters rarely clash.

A record's short URL can be shorter than its code. A newer code needs enough characters to pass every older code
that starts the same way.

A short URL is not fixed. One sent before a delete can open a different record after it, and `/talk` can open an
older code that starts with `talk` in place of the code the owner typed. A sent social post can then point readers
somewhere new.

Each lookup and each shortest path scans `short_codes` by prefix. No index serves that. The scan is fine at
today's row count, and a larger table will need one.

Codes from before this change get longer, and a migration has to pad them without any of them losing its own
record.

[0143]: 0143-send-outside-links-in-social-posts-through-aa-cool-short-links.md
[0163]: 0163-serve-a-share-groups-page-files-and-streamed-zip-under-its-code-on-the-share-host.md
[0178]: 0178-give-each-new-short-code-the-shortest-length-with-a-free-code.md
[status]: https://img.shields.io/badge/0198-black?style=for-the-badge&label=Superseded&labelColor=orange
