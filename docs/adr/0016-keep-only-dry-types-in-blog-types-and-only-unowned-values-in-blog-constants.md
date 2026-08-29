---
id: "0016"
title: Keep only dry types in Blog::Types, and only unowned values in Blog::Constants
status: active
created: 2026-09-28
area: [lib, admin, posts, projects, public]
issue: AA-665
amended: [AA-561, AA-562, AA-809]
tags: [types, constants, enums, dry-types, kernel]
---

# ADR 0016: Keep only dry types in `Blog::Types`, and only unowned values in `Blog::Constants`

![Active][status]

## Context

`Blog::Types` once held forty-nine constants above thirty-seven types, and the constants were not types. They were
format regexes, status literals, arrays and normalizing lambdas.

Most had one reader. `COUNTRY_CODE_FORMAT` stood between a regex and the `constrained(format:)` three lines below
that read it. The rest wrote down again what an enum already held: `MASTODON` and `BLUESKY` copied the list
`NetworkName` holds and publishes through `.values`. A caller reaching for `Blog::Types::SOCIAL_POSTED` got a string
with no check that it belonged to the enum it came from. The file showed accretion rather than a rule:
`ProjectLiveStatus = Types::String.enum(PROJECT_ACTIVE, "wip", "paused")` took a constant and literals on one line.

The values that were no type went to `Blog::Constants`, and nothing said what may go there. It holds six names today
in `lib/blog/constants.rb`. Three have one reader: `ACTIVITY_RANGES` and `GITHUB_COMMIT_URL` only in `slices/admin`,
`GITHUB_REPO_URL` only in `slices/projects`. AA-562 settled that `lib/blog` keeps only what no slice owns, and that
code a slice owns lives in `lib/<slice>`.

## Decision

`Blog::Types` publishes dry types and nothing else. `Blog::Constants` holds a value that is no type and that no
single slice owns.

**A name with one reader does not exist.** A format regex goes into the `constrained(format:)` that reads it, and a
normalizer with one reader becomes a `constructor` block. A normalizer with two readers becomes an unconstrained type in
the private `Normalizers` module, and each type built on it applies its own constraint last. The types that share a
normalizer do not share a constraint: `Normalized::TaskType` folds a name the way `Normalized::Tag` does and takes none
of the tag's slug format.

**An enum's values are written once.** The enum holds them as literals, and everything else reads them back.
`TagColor.values` stands where `TAG_COLORS` stood, each enum's `*Param` fallback takes the first value of its own
enum, and a caller that needs a value asks for it: `PostStatus["draft"]` rather than `POST_DRAFT`.

**A value that is no type goes to `Blog::Constants` only when no slice owns it.** Each name there passes the test
ADR 0002 sets for a kernel file: a kernel file reads it, or it reaches too many slices for one to own it. `CHECKED`,
`GAP` and `SLUG_RESERVED` pass, since `Blog::Types` reads all three. A name one slice reads lives in that slice's lib:
`ACTIVITY_RANGES` and `GITHUB_COMMIT_URL` in `lib/admin`, `GITHUB_REPO_URL` in `lib/projects`.

Anything inside `Blog::Types` that is not a type is `private_constant`: `Normalizers`, and the `REDIRECT_HOSTS`,
`SLUG_FORMAT` and `URL_FORMAT` regexes and table that more than one type reads or that would not fit inside the
block that reads them.

## Alternatives

**Move every value to `Blog::Constants` and have the types read from it.** One rule and no judgement about how many
readers a name has. It moves the indirection rather than removing it: a name standing between a regex and its only
reader still stands there, one file further away.

**Publish the shared normalizing steps, so a caller can normalize without the constraint.** `Admin::SearchQuery`
wants exactly that, since a query like `tag:c++` has to fold case without being refused. Publishing the step hands
every caller a way around the constraint the type exists for. The caller asks the type and hands it a fallback
instead: `normalize.call(match[:value]) { it }`.

**Weigh `Blog::Constants` as a whole**, as AA-562 left it. The module reaches three slices or more, so the kernel
rule keeps it, and one rule covers every kernel file. A value only one slice reads then lands in the kernel with
nothing to question it, and the module grows into a grab bag.

## Consequences

A wrong value fails at the enum rather than at Ruby's constant lookup, which catches more. A misspelt
`Blog::Types::POST_PUBLISHEDD` raised `NameError`, but `Blog::Types::POST_PUBLISHED` where a social post status
belonged raised nothing. `SocialPostStatus["published"]` raises.

Call sites are longer. `Blog::Types::ProjectFilter["archived"]` runs to 38 characters where
`Blog::Types::PROJECT_ARCHIVED` ran to 29.

Reading a status through the enum runs it. In a frozen constant at class body level that is once at boot, and in an
operation it is once per call. Both are a hash lookup.

A reader who opens `lib/blog/types.rb` still finds constants at the top. They are private, and the rule covers what
the module publishes, not every name in it.

Nothing checks either rule. No spec fails when a regex with two readers lands as a public constant in
`Blog::Types`, or when a name in `Blog::Constants` drops to one slice reading it.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
