---
id: "0078"
title: Ignore a webmention through a new status that is neutral for trust
status: active
created: 2026-09-30
area: [admin, db, lib, mcp, social]
issue: "#115"
tags: [webmentions, moderation, trust, spam, enums, schema]
---

# ADR 0078: Ignore a webmention through a new status that is neutral for trust

![Active][status]

## Context

A webmention ends as approved or spam. To keep a real mention off a post, the operator has to call it spam, and a
spam mark ends the author's trust ([ADR 0042][0042]), so their next mention waits in the queue. #114 asks for a way
to hide a mention without judging the person who sent it.

`webmention_status` is a Postgres enum, as [ADR 0015][0015] has for every closed set. Every public read and the
activity view ([ADR 0052][0052]) pick mentions by that one column.

## Decision

We add `ignored` to `webmention_status`, before `spam`, so spam, the one verdict against an author, sorts last. An
ignored mention stays off the public site and does nothing else.

Ignored is neutral for trust. `Social::Repos::WebmentionRepo#known_author?` reads approved and spam mentions only,
through `Social::Relations::Webmentions::APPROVED_NOT_SPAM`, so an ignored mention neither earns an author trust
nor costs it.

An ignored mention stays ignored on resend, as spam does. `Social::Relations::Webmentions#store` sends only a
changed approved mention back to pending and leaves every other status alone.

The operator can move a mention to approved, spam or ignored from any status. Nothing moves back to pending.

## Alternatives

**A hidden flag beside the status.** A boolean on `webmentions` that hides a mention. It lost because every
public query and the activity view would have to read two columns where they read one, and a mention could hold a
mix nobody meant, such as spam and hidden. Taking the status over the flag rules out hiding a mention that stays
approved, since a mention holds one status.

**Delete the mention.** It lost because the sender can resend, and a resend of a deleted mention arrives as new and
waits as pending, so the operator would have to drop it again. Taking the status over deletion rules out dropping a
mention for good: an ignored mention keeps its row, and counts as received in the post list, the post editor and
analytics.

## Consequences

Every query that picks approved mentions already leaves ignored ones out, so the public site and the activity feed
need no change. Counts that take every status count ignored as received, the way they count spam.

An author whose only mention the operator ignores stays unknown, and their next mention waits. An author with one
approved mention and one ignored stays trusted.

A resend never brings an ignored mention back, even with new text. Only the operator can.

Postgres cannot drop a value from an enum. Taking `ignored` back out means a new type, a cast of every row and a
swap of the column.

[0015]: 0015-type-a-closed-set-as-a-postgres-enum-and-a-format-as-a-domain.md
[0042]: 0042-trust-a-webmention-author-by-exact-url-on-their-own-host.md
[0052]: 0052-read-activity-through-one-view-across-every-content-kind.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
