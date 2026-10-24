---
id: "0192"
title: Name another slice's constant only through an import, a contract or a struct
status: active
created: 2026-10-18
area:
  - admin
  - agents
  - analytics
  - api
  - app
  - lib
  - mcp
  - media
  - performance
  - posts
  - public
  - record
  - social
issue: "#1797"
amended:
  - "#1973"
tags:
  - slices
  - exports
  - constants
  - contracts
  - structs
  - field-errors
  - kernel
---

# ADR 0192: Name another slice's constant only through an import, a contract or a struct

![Active][status]

## Context

[ADR 0123][0123] lets a slice reach another through the keys it exports, and keeps ADR 0003's three named ways
across. [ADR 0021][0021] says that rule binds Ruby constants as well as container keys. [ADR 0030][0030] says AA-563
lets a component name a constant another slice owns. The three records disagree, and the code follows none of them.

Admin, api, mcp and public name over a hundred constants from other slices. Most are contracts, which every field error
component names, and structs, which props take as types. The rest are numbers and strings: the raw visit window,
the cap on read seconds, the `ref` parameter, the days raw timing lasts, the name of a record job. Nothing checks a
constant, so a rename breaks when the page or job runs, not at boot.

A field error needs the contract class itself. It quotes the contract's limits in its message, and its `CONTRACTS`
list lets `scripts/lint/field-errors` check that every code the contract raises has wording. An
exported key hands over an instance, not the class, so moving the reads behind one would cost that wording and the
check. [ADR 0016][0016] already moves a value no slice owns into `Blog::Constants`, as #1179 did for the mail,
media and suggestion limits.

## Decision

A slice names a constant another slice owns in five cases, and no others:

- **A constant on a class behind a key it imports.** Api imports `repos.analytics_rollup_queries`, so its activity
  serializer reads `Analytics::Repos::AnalyticsRollupQueries::VIEW_DAYS`. Admin imports
  `repos.sync_state_queries`, so it reads `Record::Repos::SyncStateQueries::BACKFILL_JOB` to drop a dead backfill
  job whose sync failure already shows. The import list names the slice the reader leans on.
- **In `mcp`, a constant `api` may name by the case above.** Mcp imports all of api, and each tool describes the
  endpoint it hands to ([ADR 0088][0088]). `MCP::Tools::ReadAnalytics` quotes
  `Analytics::Repos::AnalyticsPageQueries::FIRST_DAYS`, which `api` imports.
- **A contract**, which a field error or an API endpoint's `COMPLAINTS` table names for its limits and codes, and a
  form or tool description names to quote a limit.
- **A struct named as a type**, in a prop or an `Instance` check.
- **A job constant enqueued from `after_commit`**, the third of ADR 0003's ways across.

Anything else moves. A value goes to `Blog::Constants` when it passes ADR 0016's test, or onto a class the reader
already imports. A shared helper goes to `app/helpers`, as [ADR 0126][0126] says. #1797 moved three values into
`Blog::Constants`: `READ_SECONDS_MAX`, which analytics, public and mcp read, `REF_KEY`, which analytics, admin,
public and mcp read, and `UNMADE_SHORT_CODE`, which social and admin read. It moved the error code for a closed
agent session into `Blog::Contract` as `CLOSED`, beside the other codes more than one slice reads. It moved
`PostSlug` and `MediaPath` from posts and media to `Blog::Helpers`, since admin draws with both. It moved the days
raw timing lasts from `Performance::Operations::PruneTiming` onto `Performance::Repos::TimingReportQueries`, which
api imports, and the backfill job's name onto `Record::Repos::SyncStateQueries`, which admin imports.

## Alternatives

**Hand every value through an exported key.** No constant would cross, and the import list would hold every edge.
A field error would lose its contract's class, and with it the wording and the codes spec. A struct type would turn
back into `Instance(ROM::Struct)`, which checks nothing.

**Move every crossing value into `Blog::Constants`.** One rule, and no slice names another's number. The kernel
would hold values one slice owns and two read, which ADR 0016 refuses, and contracts and structs could not move at
all.

**Leave the reads alone and drop the line in ADR 0021.** No code changes. A one-off number then crosses with no
import to say so, and the next reader still cannot tell which record holds.

## Consequences

The import list names nearly every slice a reader depends on. A contract or a struct can still cross with no import,
and that is the price of keeping field error wording and typed props.

No cop or spec checks a constant. `Hanami/SliceExports` reads export lists, not class bodies, so only review holds
this rule, and a renamed constant still breaks at run time.

Mcp tool descriptions read constants two slices away. A change to what api imports can strand a description that
quotes one.

[0016]: 0016-keep-only-dry-types-in-blog-types-and-only-unowned-values-in-blog-constants.md
[0021]: 0021-let-sql-read-another-slices-tables-never-write-them.md
[0030]: 0030-keep-a-component-in-the-slice-that-draws-it.md
[0088]: 0088-hold-the-layer-the-api-and-mcp-share-in-the-api-slice-and-call-it-in-process.md
[0123]: 0123-export-only-read-repos-and-operations-and-keep-write-repos-in-their-slice.md
[0126]: 0126-keep-only-base-classes-and-gem-wrappers-in-lib-and-give-the-rest-a-hanami-shape.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
