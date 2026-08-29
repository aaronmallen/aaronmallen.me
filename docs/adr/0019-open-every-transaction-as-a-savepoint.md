---
id: "0019"
title: Open every transaction as a savepoint
status: active
created: 2026-09-28
area: [lib, contact, mcp, analytics, social]
issue: AA-645
amended: [AA-819]
tags: [transactions, savepoint, rom, sequel, dry-operation, after-commit, rollback]
---

# ADR 0019: Open every transaction as a savepoint

![Active][status]

## Context

Operations call operations. `Suggestions::Operations::AcceptSuggestionEdits` opens a transaction and, inside it,
calls posts' `revise_post_body`, which opens its own. Operations also queue jobs from inside a transaction:
`Posts::Operations::PublishPost` and `SavePost` hand social its jobs through `after_commit`.

ROM makes a nested transaction a plain join, and rescues its rollback at the level that raised it. An inner
rollback then unwinds nothing, and the outer transaction commits what the inner one wrote (AA-519). Nothing showed
it, since every caller stepped the inner failure up and the outer transaction rolled back for its own reasons. The
suite hid it as well: `database_cleaner-sequel` opens its transaction with `auto_savepoint: true`, which turns the
next nested transaction into a savepoint, one level down and no further.

## Decision

**Every transaction the app opens through a repo or an operation is a savepoint.** `Blog::DB::Repo#transaction` and
`Blog::Operation` pass `savepoint: true`, so a rollback unwinds its own writes at any depth and the writes around it
stay. No spec drives a transaction two levels deep since the unit specs went (AA-819), so a rollback that stops
landing where it sits would show only as a request or job spec that finds a stray row.

**The operation seam is a prepend.** Hanami's `SliceConfiguredDBOperation` includes dry-operation's ROM extension
into each operation class on its own, with no way to pass options. A `transaction` on `Blog::Operation` would lose to
every subclass's copy, so `Blog::Operation.inherited` prepends the savepoint onto each subclass. No slice includes
the extension by hand (AA-554).

**An `after_commit` hook belongs to its savepoint.** `Blog::DB::Repo#after_commit` passes `savepoint: true` to
Sequel. A hook queued in a savepoint that rolls back never runs. One queued in a savepoint that is released runs once,
after the outer commit. Outside any transaction it runs at once. Request specs that check the job a save queued
pass through the hook, but none pins the three cases apart.

**A throttle's claim opens its own transaction.** `Contact::Relations::Messages#claim`,
`MCP::Relations::OAuthClients#claim`, `Analytics::Relations::AnalyticsEvents#claim` and
`Social::Relations::WebmentionReceipts#claim` open their own transaction, outside both seams, and take no
savepoint. There the transaction is the lifetime of a `pg_advisory_xact_lock`, not a unit of work. Postgres frees a
lock taken outside a transaction at once, and each block commits whether it writes or refuses. Opening it in the repo
would split the lock from the count it guards.

## Alternatives

**ROM's default, where a nested transaction joins the outer one.** No savepoint and no round trip. It is the AA-519
bug: the inner rollback unwinds nothing.

**`auto_savepoint: true` on the outer call.** Sequel then turns the next nested transaction into a savepoint. It
reaches one level, so a third transaction is a plain join again, the gap the suite's cleaner already showed.

**The outer operation owns the transaction.** An inner operation never opens one and assumes it sits inside one. No
savepoints at all, but every operation has to know whether a caller wraps it, including one in another slice that
calls it through an export. AA-519 weighed it as a bigger rule than the fix.

## Consequences

A rollback means the same thing at any depth, and an operation can call another without asking how it handles its
transaction.

Each nested transaction costs a SAVEPOINT and a RELEASE, a round trip each, where a join cost nothing.

The seam rests on a prepend in front of a module Hanami includes. If Hanami changes how it extends an operation,
the savepoint can stop reaching subclasses without a word. The two specs are what notice.

A job queued in a savepoint that rolls back is never queued, which is what a caller wants when the write it
announces is gone.

The four claims sit outside the rule. Called inside an outer transaction, a claim would join it and hold its lock
until the outer commit. None is called that way today. A new throttle that copies one keeps the same exception, and
the comment on `Messages#claim` still calls it the only one.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
