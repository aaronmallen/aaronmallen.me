---
id: "0063"
title: Apply a suggested edit only where its text appears once, under its owner's lock
status: active
created: 2026-09-28
area: [suggestions, posts, social, mcp]
issue: AA-671
amended: [AA-818]
tags: [suggestions, edits, mcp, locks, transactions, gateways]
---

# ADR 0063: Apply a suggested edit only where its text appears once, under its owner's lock

![Active][status]

## Context

Claude proofreads a post or an unsent social post through the MCP server and sends each fix as an edit: the text
to replace, its replacement and a short reason. Nothing changes until the operator accepts the edit in the admin
(AA-266). The operator may keep writing in between, so the body an edit meets at accept time can differ from the
one Claude read.

An accept writes a body it worked out from what it read. AA-446 showed that losing writes both ways. Once AA-429
had moved the post lock into `posts.operations.revise_post_body`, after the accept had read and sifted, a change
committed in that gap was thrown away while the edit still read `accepted`. On the social path nothing locked, so
the delivery job could mark a post sent while the accept rewrote its parts. The admin and the MCP server reach the
same operation, and the delivery job runs beside them.

## Decision

**An edit names its text, not a place.** `Suggestions::Structs::SuggestionEdit#applies_to?` takes an edit only
when its original appears exactly once in the body, and `apply_to` replaces that one match.
`Suggestions::Operations::AcceptSuggestionEdits` marks any other edit `stale`. The `suggest_edits` tool schema in
`slices/mcp/tools/suggest_edits.rb` holds no offset, only the social post part an edit falls in, and the
`proofread` prompt tells Claude to take in enough words that the original appears once.

**Suggestions applies the edit, under the lock of the slice that owns the text.** `AcceptSuggestionEdits` opens one
transaction. It locks the post through `posts.operations.lock_post`, or the unsent social post through
`social.operations.lock_editable_social_post`, before it reads the text. It then locks the pending edits, applies
them, and writes through `posts.operations.revise_post_body` or `social.operations.replace_social_post_parts`. The
row stays held from the read until the write commits (AA-446).

The lock crosses slices only because every slice's `db` provider opens the same gateway.
`config/providers/db.rb` configures the app's through `Blog::Providers::DBProvider`, each slice takes that config
from the app, and Hanami reuses a gateway for slices whose config matches (`prepare_gateways` in Hanami's
`providers/db.rb`).
`spec/slices/suggestions/requests/accepting_edits_spec.rb` accepts edits through the admin and checks that the
post stays held from the read to the save, and that an edit whose text appears twice turns stale.

## Alternatives

**The lock inside the owner's write**, where AA-429 left it in `revise_post_body`. Posts kept its own lock, but
the lock came after the read, so it guarded the write and not the text the write was built from. AA-446 moved it
ahead of the read.

**An apply operation in posts and in social** that locks, applies and writes in its own transaction. Each owner
would keep its write whole and need no shared gateway. AA-266 put applying an edit in suggestions, beside the
edits, and no issue records this shape being weighed.

**A position, a diff or a fuzzy match** in place of the text. AA-266 chose the exact text from the start, and no
issue records these being weighed.

## Consequences

An edit on a phrase the body holds twice never applies, however right it is. The operator fixes it by hand or asks
Claude again.

Any change to the body can strand an open edit. Once its text is gone or appears a second time, the edit turns
stale and stays stale.

An accept that meets a held row waits for it. A social post sent before the lock is refused as `:already_posted`,
not rewritten.

`revise_post_body` is a bare `post_repo.update` and `replace_social_post_parts` a bare `replace_parts`, so an
accepted edit runs none of `save_post`'s contract. Beyond the exact-once rule, an accept checks only that a social
part still fits each network's limit.

The lock holds only while every slice's `db` provider config stays the same. A slice given settings of its own
would open a second connection, and the lock would no longer cover the accept. The spec above fails first.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
