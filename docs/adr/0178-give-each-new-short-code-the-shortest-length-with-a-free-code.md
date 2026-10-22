---
id: "0178"
title: Give each new short code the shortest length with a free code
status: superseded
created: 2026-10-15
area:
  - lib
  - shares
superseded-by: "0194"
issue: "#1448"
amended:
  - "#1856"
tags:
  - shares
  - share-groups
  - short-links
  - short-codes
  - aa-cool
  - code-length
  - guessing
---

# ADR 0178: Give each new short code the shortest length with a free code

![Superseded][status]

## Context

Shares, share groups and short links all draw their codes from the `short_codes` table ([ADR 0143][0143]). Short
links take a random 5 character code. #1339 gave shares and groups a random 16 character code so nobody could guess
one. No record holds that choice, and the owner never agreed to it. The links are too long to read out or type.

Spec #1446 asks for short codes again. Every share is public: anyone with the link can fetch the file, and the owner
uses shares to hand files out, not to hide them.

## Decision

Each new code for a share, a group or a short link takes the shortest length that still has a free code. Codes start
at 3 characters, from the alphabet in `Shares::Code`. Once no 3 character code is free, new codes take 4, then 5,
and so on. A code the owner types keeps the length the owner typed.

Codes made before this change keep their length and keep working. A code freed when its share joins a group goes
back to the pool and can come out again at its length.

We do not treat a code as a secret. A share stays public, and its code only names it.

## Alternatives

**Keep the 16 character secret.** It makes a share hard to find without the link, but shares are public and the
owner does not want them hidden. It lost because the links are too long to read out or type.

**A fixed 5 character random code for everything.** Short links use it today. It lost because 3 characters fit
tens of thousands of codes and are shorter, and the owner wants the shortest link that is free.

## Consequences

Links get short: the 29,791 codes of 3 characters last a long time on one owner's site.

Anyone can walk every 3 character code and find every share and short link. We accept that, since none of them is
private. A file that must stay private does not belong in a share.

A freed code can name a new share or short link, so an old link can lead to something else. The owner has to know
that before moving a share into a group.

Picking a code has to find a free one at the shortest length, not draw at random and retry, since a full or nearly
full length makes random draws collide.

[0143]: 0143-send-outside-links-in-social-posts-through-aa-cool-short-links.md
[status]: https://img.shields.io/badge/0194-black?style=for-the-badge&label=Superseded&labelColor=orange
