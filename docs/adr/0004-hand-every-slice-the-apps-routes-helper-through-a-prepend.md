---
id: "0004"
title: Hand every slice the app's routes helper through a prepend
status: active
created: 2026-09-28
area: [config, lib, admin, mcp, public]
issue: AA-586
amended: [AA-809]
tags: [routes, hanami, slices, patch, upstream]
---

# ADR 0004: Hand every slice the app's routes helper through a prepend

![Active][status]

## Context

Each presentation slice keeps its own routes in `slices/<name>/config/routes.rb`, beside its actions, and
`config/routes.rb` holds three `slice` lines and nothing else.

Hanami's default does not fit it. For any slice with a `config/routes.rb`,
`Hanami::Slice#prepare_container_providers` registers `Hanami::Providers::Routes`, which puts a helper over the
slice's own router under `"routes"`. That helper overwrites the one the slice imports from the app. It knows no
mount prefix and none of the `admin_` or `mcp_` names, so `routes.path(:admin_root)` raises
`Hanami::Router::MissingRouteError` in an admin view, and `path(:root)` gives `/` for a page under `/admin`. Actions
do not hit this, because Hanami resolves `slice.app["routes"]` for them. Views, components and `Deps["routes"]` do
not.

## Decision

`lib/blog/extensions/hanami/providers/routes/extension.rb` prepends onto `Hanami::Providers::Routes#start`. In any
slice but the app, it registers `slice.app["routes"]` under `"routes"` in place of the slice's own helper.
`config/app.rb` requires it. Every view, component and action in `admin`, `mcp` and `public` links through the
app's helper and the app's route names: `admin_*`, `mcp_*`, and the public names bare.

The patch and its `require` go once a Hanami release ships hanami/hanami#1630, which the extension cites as the
fix upstream.

## Alternatives

**Inline slice routes in `config/routes.rb`**, as Hanami's
[slice routing guide](https://hanakai.org/learn/hanami/v3.0/app/slices#slice-routing) shows:
`slice :admin, at: "/admin" do ... end`. A slice with no routes file of its own keeps the app's helper, so it needs
no patch. It lost because it moves every slice's routes into the app file, and the admin's route constants and
session middleware with them, which undoes the layout above.

## Consequences

Every route name is global. No slice has names of its own, so an admin view writes `path(:admin_posts)`, not
`path(:posts)`, and an `as:` name in a slice's routes file resolves only under the name its mount gives it.

The patch depends on `Hanami::Providers::Routes`, a class Hanami marks `@api private`. An upgrade can rename it or
its `start` with no warning, and the extension spec is what finds out.

Taking it out is three deletions: the extension, its spec and the `require` in `config/app.rb`.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
