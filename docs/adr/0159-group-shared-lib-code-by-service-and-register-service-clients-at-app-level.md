---
id: "0159"
title: Group shared lib code by service and register service clients at app level
status: active
created: 2026-10-12
area: [config, lib, admin, analytics, backups, calendar, health, mail, media, performance, posts, projects, record,
  services, shares, social, suggestions, tasks]
supersedes: ["0149"]
issue: "#1171"
amended: ["#1576"]
tags: [layout, lib, providers, clients, services, google, github, linear, mastodon, bluesky, object-store, markdown,
  errors, rubocop]
---

# ADR 0159: Group shared lib code by service and register service clients at app level

![Active][status]

## Context

`lib/` mirrors `slices/` one for one ([ADR 0002][0002]), so code that many slices share sits in the folder of
whichever slice got there first. The `google` slice ([ADR 0149][0149]) holds a config file and a provider and
nothing else. It exists so `lib/google` loads and so `mail`, `calendar`, `health` and `admin` can import
`google.client`, and its errors get rescued in about 20 places across five slices.

The other services split the same way. GitHub's client lives in `lib/record` and its sign-in in `lib/admin`, and
Mastodon is split between `lib/social` and `lib/admin`. Media, shares and backups each carry a near copy of one S3
store. Other slices name `Posts::Markdown`, `Tasks::Markdown`, `Mail::Types`, `Media::Types`, `Suggestions::Types`
and `Record::Remote` out of a slice's lib. A reader has to know which slice claimed a shared thing before they can
find it. Spec #1170 asked for one rule.

## Decision

Shared `lib/` code groups by the service or job it does, not by slice, and the app loads it, not a slice.

- **Each service gets a folder**: `lib/google`, `lib/github`, `lib/linear`, `lib/mastodon` and `lib/bluesky`, each
  holding the service's API client, its sign-in flow, its errors and its provider builder.
- **Jobs that more than one slice does get a folder**: `lib/object_store` holds one store client and one provider
  builder, `lib/markdown` one Markdown wrapper, and `lib/issues` `Issues::Remote` and the GitHub and Linear issue URL
  patterns.
- **Service clients and sign-in providers register in `config/providers`**: `google.client`, `github.client`,
  `linear.client`, the clients behind `networks.all`, `google.auth`, `github.auth` and `mastodon.auth`, plus one
  provider that registers `media_store.client`, `share_store.client` and `backup_store.client`. Slices take them
  through `shared_app_component_keys`.
- **App code looks up a slice's component when it calls it**, because the providers start before the slices boot.
  Each lookup names an exported key:
  - The service clients look up `services.repos.connection_queries` and `services.operations.change_connection`
    through `Hanami.app.slices[:services]`.
  - The Mastodon client looks up `social.operations.scan_links` and `media.operations.process_photo`, and the
    Bluesky client `social.operations.scan_links` and `social.operations.scan_tags`, through `Hanami.app.slices`.
  - The Sidekiq startup hook in `config/sidekiq.rb` calls `analytics.operations.queue_country_database`, and its job
    timer calls `performance.operations.record_timing`.
  - The middleware lambdas in `config/app.rb` call `performance.operations.record_timing` and
    `admin.auth.session_reader`.
- **`Blog::ServiceError` in `lib/blog` is the parent of every service error**, so a caller such as admin's
  `check_service` rescues one class. `lib/blog` holds the base classes slices inherit.
- **The `google` slice goes away.** One `google` service definition with one `service_connections` row per account,
  each with the scopes it granted, carries over from ADR 0149 unchanged.

Code one slice owns stays in `lib/<slice>/` as ADR 0002 says.

## Alternatives

**Group by role**, with `lib/clients` and `lib/auth`. One service's client, sign-in and errors would then sit in
three folders.

**Register the clients in the `services` slice**, which owns the connections they read. Every caller would import
from `services`, a feature slice, for a client that is not about stored credentials.

**Register them in each calling slice.** Five slices would each build `google.client`, with five copies of the
provider.

**Fix only Google.** GitHub, Mastodon, the stores and the Markdown wrappers keep the same split.

## Consequences

A reader finds a service's code under the service's name, and a new slice that calls Google adds one shared key
instead of an import.

The `Hanami/SliceExports` cop cannot see these lookups, so app code's reach into a slice shows as no import edge,
and the cop's allow list drops the client keys. The list above and the slices' exports stand in for the edges.
Passing the scans into the clients would change the `networks.all` interface the length checks call.

A boot-order break, such as a client that resolves `services` before the slice boots, fails only at runtime. Request
specs have to cover every client path.

The app depends on a slice by name, which ADR 0001 kept to imports.

[0002]: 0002-hold-app-and-the-slices-to-hanamis-own-directories.md
[0149]: 0149-keep-google-accounts-in-a-google-slice-with-one-connection-each.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
