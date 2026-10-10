---
id: "0025"
title: Inherit Blog::Operation only in a class that can refuse or steps a Result
status: active
created: 2026-09-28
area: [lib, activity, admin, analytics, contact, mcp, posts, projects, public, record, social, suggestions, tags, tasks]
issue: AA-661
amended: [AA-757, "#718", "#955", "#996"]
tags: [operations, dry-operation, monads, result, callables, transactions]
---

# ADR 0025: Inherit `Blog::Operation` only in a class that can refuse or steps a `Result`

![Active][status]

## Context

Hanami's operations guide defines an operation as a `Dry::Operation` that answers `Success` or `Failure`. The
former ADR 0002 used the directory more widely: anything that takes dependencies and does one job becomes an
operation. So `operations/` came to hold page builders, a hasher and plain lookups beside the writes, and nothing
said which of them answer a `Result`. Today 35 of the 110 classes under `slices/*/operations` do not inherit
`Blog::Operation`.

The gap cost twice. AA-451 found operations that signalled a refusal as `0` or `nil`, which `Dry::Operation`
wrapped in a `Success`, so an unconfigured GitHub token read as a sync that worked. AA-756 found six admin writes
that returned a count, a boolean or a row, each caller rebuilding the outcome by hand, and one truth test that
could never fail, so "Nothing saved" showed only under a stub.

## Decision

A class under `slices/*/operations` inherits `Blog::Operation` only when it can refuse or when it steps another
operation's `Result`. It answers `Success` or a named `Failure`, such as `Failure(:not_found)`, and its caller
matches with `case ... in` and a fallback branch. `Admin::Operations::BuildTasksPage` inherits it because it steps
`Tasks::Operations::CurrentSprint`.

A class that cannot fail stays a plain callable, with `Deps` and a `#call` that returns its value. Wrapping it
would add a `Success` around a value that is always there and, since AA-326 gives every match over a `Result` a
fallback branch, a branch that never runs. The page builders such as `Admin::Operations::BuildPostsPage`, which
return a hash the action splats, stay plain, as do `Analytics::Operations::HashVisitor`, which returns a String,
and the `List*` reads. So do the `Summarize*` reads but two: AA-757 moved `Admin::Operations::SummarizeSprint`
across when it began to step `CurrentSprint`, and `SummarizeToday` with it, since it steps `SummarizeSprint`.

Since #955, a plain callable that needs a transaction opens it through its write repo, the way
`Tasks::Operations::SyncLinks` calls `task_link_mutations.transaction`. ADR 0019 makes that seam a savepoint just as
it does the operation's, so no class inherits `Blog::Operation` only to borrow `transaction`. `SyncLinks` and
`MCP::Operations::IssueTokens` did until #955.

A plain write that another slice's operation steps may return a row or `nil`, and the caller turns `nil` into its
`Failure`, the way `Suggestions::Operations::AcceptSuggestionEdits` does with
`Social::Operations::LockEditableSocialPost`. It did the same with `Posts::Operations::LockPost` until #996 folded
the published check into `Posts::Operations::LockUnpublishedPost`, which answers a `Result`.

Since #718, parsers and scanners from `lib` become operations too (ADR 0126). One that cannot refuse is a plain
callable under this rule.

No name prefix marks the kind. The superclass alone does.

## Alternatives

**Make every class under `operations/` a `Dry::Operation`**, the shape the guide gives. One rule, and every caller
reads a `Result`. It lost because `Dry::Operation` wraps whatever `#call` returns, so every builder that cannot
fail would carry the dead `Success` and fallback branch above. `Admin::Actions::Tasks::Index` shows the shape:
`in Success(screen)`, then `else halt 500`.

## Consequences

A caller that reads a `Result` knows the refusals are named, and one that reads a value knows there are none.

A name tells a reader nothing. `BuildTasksPage` answers a `Result` and `BuildPostsPage` a hash; `ReplacePostEdits`
and `RecordVisit` answer a `Result`, `ReplaceSocialPostParts` and `RecordSyncOutcome` do not. A reader opens the
file and reads the superclass.

A plain class that gains a way to refuse moves across, and every caller changes with it. AA-756 touched six call
sites for six classes. No guard spec checks the rule, so a new refusal can still travel as `nil`.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
