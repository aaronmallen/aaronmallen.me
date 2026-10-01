---
id: "0084"
title: Keep edit notes in a post_edits table and require one under the post's lock
status: active
created: 2026-09-30
area: [db, posts]
issue: "#142"
tags: [posts, edit-notes, post-edits, operations, contracts, locks, markdown]
---

# ADR 0084: Keep edit notes in a post_edits table and require one under the post's lock

![Active][status]

## Context

Spec #141 makes the writer say what changed and why whenever the body of a published post changes. The note shows
on the post and closes its Atom entry. It is Markdown, 500 characters at most, and renders through
`Posts::Markdown` the way a post body does. The writer can fix its wording later but cannot delete it; it goes only
when the post goes.

The rule reads stored state: whether the post is published, and whether the body differs from the stored one.
[ADR 0017][0017] puts such rules in Postgres because a check in Ruby that runs before the transaction can read a
row that changes before the write. The scheduled posts job can publish a post while its editor is open, so a check
made then would see a scheduled post and let a body change through with no note.

## Decision

**A `post_edits` table holds the notes, one row per note.** Each row holds its post, the note's Markdown and the
time it was written. The foreign key to `posts` cascades, so deleting a post deletes its notes. Nothing deletes a
note on its own. Editing a note changes its wording and keeps its time, since the time dates the edit to the post.

**`Posts::Operations::SavePost` enforces the rule.** It already locks the post's row inside its transaction before
it saves. After the lock, and before it writes, it compares the stored status and body with what arrived. When the
post is published and the body differs, a blank note fails as a field error and a note writes its `post_edits` row
in the same transaction as the post. Every other save, including one that changes only tags or SEO fields, takes no
note.

`PostContract` keeps the rules over what arrived: a note is Markdown with no stray control characters, 500
characters at most. It does not know whether the note is required.

## Alternatives

**A revisions table that also keeps the old body.** It would let a later page show what changed, not just why. It
lost because the spec asks only for the note, and storing every earlier body is more than that. A revisions table
can sit on top of this one later.

**A JSONB list of notes on `posts`.** It saves a table and a join. It lost because Postgres cannot hold each item
in the list to a non-blank note or a length, against [ADR 0017][0017], and editing one note means rewriting the
list.

**The rule in `PostContract`, with the stored post as context.** `context[:intent]` already reaches the contract
this way. It lost the race ADR 0017 names: `SavePost` validates before it opens its transaction, so the contract
would read the post before the lock and could see it scheduled when it is published.

## Consequences

The note and the body land together or not at all. A failed save leaves no orphan note, and a body change on a
published post through `SavePost` never lands without one.

This is a rule over stored state that lives in Ruby, against [ADR 0017][0017]. It binds only callers that go
through `SavePost`. `Posts::Operations::RevisePostBody`, which accepting a suggestion calls, writes the body with no
note, as the spec leaves it. A new writer of the body has to go through `SavePost` or carry the rule itself.

The required-note error comes from the operation, not the contract, so it arrives after every contract error. A
form with a bad slug and no note shows the slug error first and the note error only on the next save.

Notes exist only from the day this ships. A post edited before then shows no note, and nothing marks that it
changed.

[0017]: 0017-enforce-rules-over-stored-state-in-postgres-not-in-contracts.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
