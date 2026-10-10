---
id: "0126"
title: Keep only base classes and gem wrappers in lib, and give the rest a Hanami shape
status: active
created: 2026-10-07
area: [app, config, lib, activity, admin, analytics, api, backups, contact, decisions, links, mcp, media, posts,
  projects, public, record, saved_views, search, security, social, suggestions, tags, tasks]
issue: "#718"
amended: ["#957"]
tags: [layout, hanami, lib, app, rom, plugins, operations, contracts, structs, enums, helpers, markdown]
---

# ADR 0126: Keep only base classes and gem wrappers in `lib`, and give the rest a Hanami shape

![Active][status]

## Context

ADR 0002 sends "anything stateless with no configuration" to plain library code in `lib/<slice>/`, loaded by
`push_dir` and kept out of the container. About 140 files took that door: modules mixed into relations
(`Activity::Crediting`, `Blog::DB::Tags`, `Blog::DB::Taggings`, `Analytics::DailyRollup`), param filters written as
`module_function`, `Data` values, text scanners and bags of constants. None of them has a shape Hanami, ROM or
dry-rb names, so a reader who knows Hanami cannot guess where a thing lives or what it is, and `lib/blog` grows into
a second app root Hanami knows nothing about. Spec #717 asked for one rule.

## Decision

`lib/<slice>/` and `lib/blog` hold two kinds of code: the base classes a slice inherits (`Action`, `Operation`,
`Repo`, `Types` and the like) and code that wraps or extends a gem, such as the Faraday adapter, the Bluesky protocol
builders and the Commonmarker walk. Clients, providers, Rack middleware, errors, the UI kit and `lib/blog/extensions`
stay where they are. Everything else takes the shape its kind has:

| Kind | Becomes | Lives in |
| --- | --- | --- |
| Relation mixin | A ROM relation plugin a relation opts into with `use :<name>`, as commands `use :timestamps` | Registered once at boot |
| Parser or scanner | An operation reached through `Deps` | The owning slice's `operations/` |
| Param filter | A dry-validation contract | The owning slice's `contracts/` |
| Value one slice uses | A `Data` class (ADR 0029) | That slice's `structs/` |
| Bag of constants | An enum | `Blog::Types` if shared, else the slice's `Types` (ADR 0016) |
| Shared value | A `Data` class | `app/structs` |
| Shared presentation helper | A module of functions, reached by constant | `app/helpers` |
| Site-wide fact (`Site`, `Owner`, `Concurrency`) | A setting | `config/settings` |

### The open questions

**Presentation helpers.** `Figures`, `Truncation` and `Whitespace` become modules under `app/helpers`, such as
`Blog::Helpers::Figures`, kept out of the container through `no_auto_register_paths` as the api slice keeps out its
serializers. Callers name them by constant. Views, components, operations, contracts and repos in eight slices call
them, and a Phlex component takes no `Deps`.

**Markdown.** `Posts::Markdown` and `Tasks::Markdown` wrap Commonmarker, so they are library code and stay in
`lib/posts` and `lib/tasks`. Other slices keep naming them by constant, since ADR 0002 lets a caller name a constant
of the slice that owns it, and the admin and public components that render Markdown take no `Deps`.

**`Analytics::Device`.** Nothing crosses. `lib/security` names its own `Security::Device`, which reads the browser
and system, and `Analytics::Device`, which sorts a visit into a device class, is named only from the development
seeds. Each becomes an operation in its own slice, and the seeds resolve the analytics one from its slice. They are now
`Security::Operations::ReadDevice` and `Analytics::Operations::ClassifyDevice`, and #1003 emptied `lib/security`
with nine other `lib/<slice>` folders and dropped their `push_dir` lines, as #957 records.

## Alternatives

**Shared relation base classes, or the methods written on each relation**, in place of plugins. ROM already offers
`use`, so a plugin is the shape a reader who knows ROM expects. Writing the methods out puts six copies of `claim`
back where ADR 0022 had one.

**View parts or components for the presentation helpers.** Phlex views have no parts, and a component cannot serve
the operations, contracts and repos that call `Figures` and `Truncation`.

**An exported Markdown operation, or a move to `lib/blog`.** An operation cannot reach a component, which takes no
`Deps`. A move to `lib/blog` takes a gem wrapper from the slice that owns it and gains nothing.

**Leave the rule as ADR 0002 had it.** Nothing moves, and `lib/blog` keeps growing.

## Consequences

A reader who knows Hanami can tell what a class is from where it sits, and `lib/blog` shrinks to bases, extensions
and gem wrappers.

Each move renames a constant and, for an operation, adds a container key, so every caller changes. Nothing checks a
`Deps[...]` string until the code runs. A parser that answered with plain module functions now needs an instance
from the container, so a class that cannot take `Deps`, such as a Phlex component, can no longer call it.
`Admin::UI::Components::Social::Directory` builds `Social::Mentions` itself today, so its action has to hand it
the result instead.

`app/` stops being assets alone. It holds `structs` and `helpers` too, and the app config grows a
`no_auto_register_paths` line for `helpers`.

The helpers under `app/helpers` stay modules reached by constant, much as the old `lib/blog` helpers were. The rule
gives them a home, not a new shape.

The two Markdown wrappers stay apart and stay named across slices. Merging them is out of scope.

No spec checks the layout, so a new file in `lib/<slice>/` that is neither a base class nor a gem wrapper passes
until someone reads it.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
