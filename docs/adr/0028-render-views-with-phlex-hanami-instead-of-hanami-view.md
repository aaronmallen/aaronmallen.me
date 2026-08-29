---
id: "0028"
title: Render views with phlex-hanami instead of hanami-view
status: active
created: 2026-09-28
area: [config, lib, admin, mcp, public]
issue: AA-632
amended: [AA-783, AA-809]
tags: [views, phlex, phlex-hanami, hanami-view, dry-types, props, components, layouts, ui]
---

# ADR 0028: Render views with phlex-hanami instead of hanami-view

![Active][status]

## Context

Hanami documents one way to draw a page: hanami-view. A view class exposes values, a template in a second language
draws them, parts wrap the exposed values, scopes hold helpers for a piece of a template, and a `Views::Context`
takes `Deps` for what every template needs.

Three slices draw pages, admin, public and mcp, and they share one kit of components and one base layout. Each page
builds from many small components, so the shape of a component decides how the rest of the markup reads.

## Decision

Every view, layout and component is a Phlex class, rendered through phlex-hanami. The app does not bundle
hanami-view.

The `Gemfile` pins `phlex-hanami ~> 0.2` from the `gem.coop/@aaron` source, locked at 0.2.2. `Blog::UI::View`,
`Blog::UI::Layouts::Application` and `Blog::UI::Component` in `lib/blog/ui` subclass `Phlex::Hanami::View`,
`Phlex::Hanami::Layout` and `Phlex::Hanami::Component`. Each slice keeps its own under `slices/<slice>/ui`, and each
slice's `UI::View` subclasses `Blog::UI::View`.

Components type their props with dry types through `Phlex::Hanami::Props`, which `Blog::UI::Component` includes
(`lib/blog/ui/component.rb`). Props use strict types, as `Blog::Types` does, and a bad value raises
`Phlex::Hanami::InvalidPropError`. A prop type one slice uses lives in that slice, and only a shared one goes in
`Blog::Types`, under ADR 0016.

We chose Phlex because a component is plain Ruby with typed props. It composes, tests and refactors like any other
class, and there is no template language, no parts and no scopes to learn.

## Alternatives

**hanami-view templates with exposures, parts and a `Views::Context` that takes `Deps`**, the shape Hanami
documents. It brings `form_for`, a context that injects, and view names Hanami infers on its own. It lost because
it splits each page across a class and a template in another language, with parts and scopes as two more things to
learn, and a template does not compose, test or refactor the way a Ruby class does.

**Props typed with `Literal::Properties`**, which this record chose until AA-783, when phlex-hanami had no props of
its own. It lost because it gave the app a second type system: contracts and operations speak dry-types through
`Blog::Types`, while every component spoke Literal's own words (`_Nilable`, `_Union`, `_Interface`,
`Literal::Undefined`). Once phlex-hanami 0.2.2 shipped props built for dry types, Literal cost a gem and a second
set of type words and gave nothing back.

## Consequences

A component is a Ruby class with typed props, so a spec builds it with those props and reads the HTML it returns.

A component and a contract share one set of type words, and a component can take a type from `Blog::Types` as it
is. A prop declared with `prop?` holds `Phlex::Hanami::Props::UNSET` when the caller leaves it out, so a component
that must tell nil from a missing value, as `Blog::UI::Components::Form` does with its token, checks for `UNSET`.

Nothing injects into a layout. phlex-hanami builds one with `layout_class.new`, so `Deps[]` never runs, and both
layouts call `slice[...]` instead (`slices/admin/ui/layouts/application.rb`,
`slices/public/ui/layouts/application.rb`). ADR 0003 says which keys they reach.

There is no `form_for`. `Phlex::Hanami::Helpers` requires hanami-view, so the app cannot include it. The kit's
`Blog::UI::Components::Form` writes the `_csrf_token` field instead (AA-700), and no view or component under
`slices/*/ui` or `lib/blog/ui` writes the field by hand.

Views live under `ui/views`, where Hanami does not look, so `config/app.rb` sets
`config.actions.view_name_inference_base = "ui.views"`. Hanami marks that setting `@api private`
(`hanami-3.0.2/lib/hanami/config/actions.rb`), so an upgrade may change it without notice.

phlex-hanami looks for a layout at `Views::Layout` in the slice. Ours sit at `UI::Layouts::Application`, so each base
view names its layout with `layout Layouts::Application` (`slices/admin/ui/view.rb`, `slices/public/ui/view.rb`,
`slices/mcp/ui/view.rb`).

A relative i18n key resolves against the class's container key with only a leading `views/` taken off. `t(".label")`
in `Admin::UI::Components::CommitsCard` reads `ui.components.commits_card.label`, so each slice's locale file nests
its copy under `ui:` (`slices/admin/config/i18n/en.yml`).

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
