---
id: "0030"
title: Keep a component in the slice that draws it
status: active
created: 2026-09-28
area: [lib, admin, public, mcp]
issue: AA-672
amended: [AA-783, AA-809, "#17"]
tags: [phlex, components, kit, ui, slices, kernel]
---

# ADR 0030: Keep a component in the slice that draws it

![Active][status]

## Context

Three slices draw pages: admin, public and mcp. Each has its own Phlex kit under `slices/<slice>/ui/components`,
and `lib/blog/ui/components` holds a shared one. The kernel holds what no slice owns, so the question for any
component is which slice owns it.

Phlex reaches a component by a bare method its kit defines, `ProjectCard(...)`, and never through the container.
So a slice can draw a component without ever naming its constant, as public draws `ProjectCard` through its own
`ProjectGrid`. A file can also name a component it never draws: the kernel's `Posts::Tags` reads
`Pill.for_tag_color` for a tag's colour.

## Decision

Drawing a component is owning it. A component one slice draws lives in that slice's `ui/components`. It lives in
`lib/blog/ui/components` only while more than one slice draws it, or while a kernel file names it, as
`Blog::UI::Components::Posts::Tags` names `Pill`. Moving `Pill` would leave the kernel naming a slice constant.

A slice draws a component when it calls the kit method, passes it to `render`, or draws a kernel component that
draws it. Naming a constant alone does not count, since AA-563 lets a component name a constant another slice
owns. No spec checks the rule.

A slice reaches the shared kit through its base classes: `Blog::UI::Component` and `Blog::UI::View` include
`Blog::UI::Components`. A kit does not nest. `Phlex::Kit#const_added` gives a nested module a kit of its own and
includes a component into the module that holds it, so a component in `Components::Tasks::Types` would get the
methods of `Types` and none of `Tasks`. The task types screen kept its rows there until #17 retired task types
(ADR 0065). Two things follow:

- A slice reaches a nested kernel kit by including it in its own module of that name, as
  `slices/admin/ui/components/posts.rb` includes `Blog::UI::Components::Posts`.
- A nested component calls a component a level up through the parent kit, as `Tasks::Types::Row` drew
  `Tasks::TypeTag(type: @type)`.

## Alternatives

**Put a component in the feature slice that owns its record.** An early draft of AA-370 did, since `ProjectCard`
and `Posts::Meta` render on a public page and in an admin preview both. AA-368 found the flaw: Phlex reaches a
component by constant, so admin drawing a component from `slices/projects` is a cross-slice reference no `import`
declares.

**Keep every shared-looking component in the kit.** What AA-421's blanket exemption left: sixteen components one
slice drew sat in `lib/blog/ui`. AA-509 moved them, because the kit then said what arrived first rather than what
is shared.

**Count the slices that name a component.** AA-555 turned this down. By name, `Posts::Meta`, `ProjectCard` and
`Pill` all read as admin's alone, so a guard counting names would move the two components public draws most.

## Consequences

`lib/blog/ui/components` says what is shared, and a spec fails the day it stops.

A second slice drawing a component forces a move to the kernel, and dropping back to one drawer forces a move out.
Each move changes the constant and every qualified call to it.

A kernel component takes no `Deps`, as no Phlex component does, and it can name no slice struct. `Posts::Tags`
types its prop as `Blog::Types::Array.of(Blog::Types::String | Blog::Types::Instance(ROM::Struct))` rather than a
posts struct.

Copy splits across two locale trees. A kernel component's strings live in `config/i18n/shared/en.yml` under
`ui.components`, and a slice component's in that slice's locale file, so a move carries its copy with it.

The MCP consent page, `slices/mcp/ui/views/authorizations/new.rb`, draws the kernel `Form` but not admin's
`PageHead` or `Card`, which only admin draws. It writes their markup by hand.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
