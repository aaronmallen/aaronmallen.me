---
id: "0003"
title: Reach another slice only through its exports
status: active
created: 2026-09-28
area: [db, activity, admin, analytics, contact, mcp, posts, projects, public, record, social, suggestions, tags, tasks]
issue: AA-605
amended: [AA-559, AA-571, AA-803, AA-809, "#236", "#245"]
tags: [slices, exports, rom, associations, sidekiq, cycles, providers]
---

# ADR 0003: Reach another slice only through its exports

![Active][status]

## Context

The app splits into three presentation slices and ten feature slices. Every slice but `public` has its own `db`
provider, and its container holds only the relations under that slice's `relations/` directory.

Tracing the split found three things that would not survive it.

**A ROM association cannot cross a slice.** An association that names another feature's table boots fine, since
nothing checks it, and raises when a `combine` runs.

**Publishing a post was a cycle.** Posts called into social to queue syndication, and social reads posts to compose
the announcement.

**A repo cannot be exported for reads alone.** One repo answers reads and writes: `Posts::Repos::PostRepo` takes
`create` and `update` from ROM's `commands` macro beside its reads. A slice handed the repo for one read holds every
write with it, and there is no way to export half of one.

## Decision

A slice reaches another slice only through what that slice exports. Not its relations, not its container, not its
repos.

**Exports are a slice's API.** Every feature slice lists `export` in `slices/<name>/config/slice.rb`, and anything it
leaves out is private. A dependent writes `import keys: …, from: …` and resolves the key through `Deps[]`.

**A repo never leaves its slice.** A read crosses as a query object, one per read and named for it:
`Posts::Queries::PublishedBySlug` exports as `queries.published_by_slug`. A write crosses as an operation, so the
rules travel with it. A caller holding `post_repo` could write a post and skip every rule in `PostContract`. Inside
its own slice, code still reads its repo.

**No association crosses a slice.** A caller that needs another feature's record loads it by id through that
feature's export, and a `combine` joins children inside one feature. The `tags` table, which five slices declare, is
the one exception, and AA-584 records why.

**Three ways across, each named.** We allow no other cycle.

- **The `admin` and `mcp` cycle.** `admin` imports `queries.connected_clients` and `operations.revoke_client` from
  `mcp`, and `mcp` imports `auth.session_reader` from `admin`. The MCP consent screen signs the operator in through the
  admin's GitHub session, and the admin holds the page that revokes a client. Both are presentation slices, no
  feature's records cross either edge, and neither calls back through the other inside one unit of work.
- **An import of provider keys alone.** `posts` imports `links.tagger` and `networks.all` from `social` so
  `PostContract` can tag the announcement's links the way social sends them and refuse one too long for a network,
  while `social` imports operations and queries from `posts`. A client that a provider registers is not a feature
  dependency: social never calls back into posts through it. An edge whose every key names a provider in the source
  slice does not count toward a cycle, and an edge that carries one operation, query or repo key still does. AA-571
  added this, and #245 added `links.tagger`.
- **A job constant enqueued from `after_commit`.** Publishing announces, and social decides what to do about it.
  `PublishPost` enqueues `Social::Jobs::SyndicatePost` and `Social::Jobs::SendWebmentions` inside
  `post_repo.after_commit`, and `SavePost` enqueues the second, so posts calls no social operation. A job crosses
  this way only where an import would close a cycle. Anywhere else the caller imports an operation that enqueues it,
  the way admin calls `record.operations.queue_commit_import` (AA-716).

**Seeds follow the rule, specs do not.** `config/db/seeds.rb` loads every file under `config/db/seeds/<env>/`, and
only `development/` holds any. A seed reads and writes through a slice's exports wherever one covers the record. Where
none does, it calls the owning slice's own operation, and hands it a stand-in for any remote service: the issue sync,
commit import, client registration, webmention check and social delivery. Where no operation writes the record
either, it uses the owning slice's repo: backdated analytics events, which that slice's own rollup then reads, and the
id of a new MCP client. A seed never reaches one slice's records through another. A spec sets rows up straight out of
the owning slice's container. A test arranges the database rather than serving a request, so the rule it walks past
is one no caller runs.

## Alternatives

**Duplicate the `Posts` relation into each container that needs it.** Cheapest to write, and it keeps the `combine`.
It gives one table several definitions, and the day one gains a type or a scope the others are wrong.

**Keep every relation in one shared ROM container and slice only repos and operations.** The smallest change. A
relation directory would then say nothing about which feature owns a table, and the split would be a directory
shuffle where it counts most.

**Export every repo.** One rule, nothing to remember. It hands every caller a way around the contract that owns the
record.

**Let a read cross as a repo**, which this record first chose. No new class, and every read a repo answers crosses
for free. It hands out the writes with the reads, so the rule then lives in a spec that reads source, and a
hand-written method walks past it.

**Let posts import social and keep syndication inline.** Nothing needs a job, and a failure comes back in the
request. The cycle stands, and two slices that need each other are one slice with a directory between them.

**Name each client edge beside `admin` and `mcp`.** One kind of exception. The list grows with every client that
moves into the slice that owns it, and each line says nothing a provider does not already say.

## Consequences

A reader finds the dependency tree in `slice.rb` rather than by tracing calls.

Privacy stops being a convention. A public page reaches a journal entry only if `public` imports a `record` query,
and it imports none.

No spec checks the repo rule or the cycles. The suite passes when a slice exports or imports a `repos.` key, names
another slice's `Repos::` constant or resolves its `repos.` key, so only review catches them. A repo renamed under a
spec that reaches it breaks when that spec runs rather than at boot.

A container per slice costs the suite. rom-factory follows an association only inside one container, so the linking
step in `spec/support/db/factories.rb` turns a parent record into its id for each factory in `Linking::KEYS`, and
`spec/slices/social/factories/webmention.rb` builds its post through another slice's registry.

Two layouts reach the container, and they have to. phlex-hanami builds a layout with `layout_class.new`, so `Deps[]`
never runs, and the gem hands it `slice` instead. `slices/admin/ui/layouts/application.rb` calls
`slice["operations.build_navigation"]`, its own key. `slices/public/ui/layouts/application.rb` calls
`slice["admin.auth.session_reader"]`, which public imports. Neither names a repo, and the one that crosses a slice
line crosses through an export.

A job constant is still a name from the other side. No guard checks it, so a renamed job breaks when a post saves, not
at boot.

Syndication runs in Sidekiq. A failure that would have come back in the request shows up in a job instead.

Eighty-five query classes stand where a repo method would have done. A cross-slice read is a new file, not a new
method on a repo somebody already imported.

Every dependency costs two lines, an export and an import. Container keys are strings, and nothing checks them until
the code runs.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
