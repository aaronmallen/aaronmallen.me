---
id: "0123"
title: Export only read repos and operations, and keep write repos in their slice
status: active
created: 2026-10-07
area: [activity, admin, analytics, api, backups, contact, decisions, links, mcp, media, posts, projects, public,
  record, saved_views, search, social, suggestions, tags, tasks]
supersedes: ["0003"]
issue: "#665"
amended: ["#917"]
tags: [slices, exports, repos, queries, mutations, rubocop, cycles]
---

# ADR 0123: Export only read repos and operations, and keep write repos in their slice

![Active][status]

## Context

ADR 0003 let a slice reach another slice only through its exports, and kept every repo inside its slice. One repo
answered reads and writes, so a slice handed a repo for one read held every write with it. A read crossed as a query
object instead, one class per read.

That left 186 query classes under `slices/*/queries/`, each a thin wrapper over a repo method with one `call`. Posts
alone exports 25 `queries.*` keys, and every importer lists them by hand. Inside a slice, nothing in the code said
which half of a repo may leave it. No check held the export rule, so only review caught a leak.

The objection to exporting a repo was that it carries its writes. Split the repo in two and the objection goes.

## Decision

Each slice splits its repos into read repos and write repos.

- **A read repo** sits under a `repos.*queries` key, such as `repos.post_queries`, and holds only reads.
- **A write repo** sits under a `repos.*mutations` key, such as `repos.post_mutations`, and holds the writes: the
  stamped commands, the transaction and the `after_commit` hooks ADR 0019 describes.

A slice may keep one read repo and one write repo, or several of each, one per table. We allow both.

**A slice exports only its read repos and its operations.** A read crosses as a read repo, and a caller calls its
method straight. A write crosses as an operation, so the contract's rules travel with it. A write repo never leaves
its slice. The query classes and the `queries/` folders go.

Four other kinds of key may cross, since none of them holds a write repo:

- **`endpoints.*`**, which `api` exports so `mcp` can call its endpoints in process, as ADR 0088 decides.
- **`auth.session_reader`**, which `admin` exports so `public` and `mcp` can read the operator's GitHub session. ADR
  0003 names this edge.
- **`networks.all`**, the provider `social` exports so `posts` and `suggestions` can measure text against each
  network. ADR 0003 names this edge too.
- **A client provider**: `github.client` and `linear.client` from `record`, and `store.client` from `media`. ADR 0001
  makes each client a provider in the slice that owns it, and a slice that calls one imports its key.

**The `Hanami/SliceExports` cop holds the rule.** It comes from `rubocop-hanami`, runs under `mise run lint`, and
fails on any export that is not a read repo key, an `operations.*` key or one of the keys above. A new kind of key
needs a line here and in the cop's allow list.

The rest of ADR 0003 stands, with a read repo key wherever it named a query key: a slice lists its exports in
`slices/<name>/config/slice.rb` and leaves the rest private, no ROM association crosses a slice but the shared
`tags` table, the three named ways across (the `admin` and `mcp` cycle, the `posts` and `social` cycle, and a job
constant enqueued from `after_commit`) are the only cycles, and seeds follow the rule while specs set rows up out of
the owning slice's container.

## Alternatives

**Keep the query classes**, as ADR 0003 chose. A write never crosses, and nothing new to learn. It costs a class and
an export line for every read another slice needs, and it still leaves the rule to review.

**Export whole repos.** No split and no new keys. It hands every caller the writes, and a caller holding a write
repo could skip every rule in the contract that owns the record.

## Consequences

A cross-slice read is a method on a read repo a caller already imports, not a new file and a new export.

The lint catches a write repo or a stray key in an export. It cannot see inside a class, so a write method added to a
read repo crosses with it, and only review holds that line.

The move rewrites every slice and every importer of its keys. It goes one slice at a time, and until the last one
moves the cop's allow list takes both the old `queries.*` keys and the new read repo keys.

A read repo exports every read it holds. A slice that wants one read private keeps it in a repo it does not export.

Container keys are still strings. The cop reads the export list, but nothing checks an import or a `Deps[]` key
until the code runs.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
