---
id: "0113"
title: Share a repeated view fragment as a kit component with slots
status: active
created: 2026-10-06
area: [lib, admin, mcp, public]
issue: "#552"
tags: [phlex, components, kit, ui, slots, partials]
---

# ADR 0113: Share a repeated view fragment as a kit component with slots

![Active][status]

## Context

Phlex has no partials. ADR 0028 chose phlex-hanami over hanami-view, so there are no templates, parts or scopes, and
a fragment two views share is a kit component reached by a bare method. ADR 0030 says which kit a component lives
in, and ADR 0031 says "a shape that repeats in markup becomes a component". Neither says when a private method
stops being private, how a caller fills a region of a component, or what a component may be named.

The tree shows the gap:

- `Tasks::Timeline` and `Decisions::Timeline` carry the same eleven private methods, from `acts` to `stamp`.
- `Journal::Day`, `Tasks::CompletedDay` and `Activity::Day` each carry the same `ago`.
- `ListItem` takes its sub line as a String in `sub:` and a built component in `beside:`, so a row that needs markup
  under its title writes `.li` by hand instead.
- `People::Form` and `WorkEntries::Form` take the name of the kernel `Form`. Inside their kits a bare `Form(...)`
  reaches the local one, so their neighbours write `render Blog::UI::Components::Form.new(...)`.
- `People::Dialog` draws `task-dialog` classes, named for the feature that drew the dialog first.

`Admin::UI::Components::Card#side` already shows another way. It keeps the caller's block, and `view_template` runs
the outer block through `vanish` first, so the caller fills the head's side with markup of its own.

## Decision

A private method that a second component copies becomes a kit component, in the narrowest kit both can reach under
ADR 0030. Two task components share one in `Components::Tasks`, a task and a decision component share one in
admin's top kit, and two slices share one in `lib/blog/ui/components`.

A region the caller fills with markup is a slot: a public method on the component that keeps the block, as
`Card#side` does, and that `view_template` draws after `vanish` has run the caller's block. A prop holds data, never
markup. A component does not take markup as a String prop or a built component as a prop, as `ListItem`'s `sub:`
and `beside:` do.

A component never takes the name of a component in a kit it can reach: the kernel's `Form` and `Pill`, or admin's
`Card`. A bare call then reaches the component its name promises, from every kit.

A shared component's classes name the thing it draws, not the feature that drew it first. A dialog shell that
tasks and people share draws no `task-dialog` class. ADR 0031 still gives each element one class, defined once.

## Alternatives

**Copy the private method into each component that needs it.** What the timelines and the day lists do. It costs
nothing on the day, and the copies drift the first time one changes and the other does not.

**Take markup as a String prop.** `ListItem`'s `sub:` does this. A String cannot hold an element, so the first row
that needs a link or an icon in that line falls back to writing the markup by hand.

**Take a built component as a prop.** `ListItem`'s `beside:` takes `ProfileLinks.new(person:)`. It holds markup, but
the caller builds the component outside the kit, by constant and `.new`, and the region takes one component rather
than whatever the caller draws.

**Parts and partials from hanami-view.** ADR 0028 turned hanami-view down, and these come only with it.

## Consequences

A fragment has one home, so a change to it is one edit, and the next component that needs it calls the kit method.

Moving a method out turns a private name into a public one. The new component takes props for what the method read
from instance variables, and every caller passes them.

A slot reads in the caller as a block on the component, so its markup sits in the caller's file. A reader looking
for what a region draws reads both files.

Components that break the rule today stay until the issues that follow this record move them: the timelines, the day
lists, `ListItem`, `People::Form`, `WorkEntries::Form` and the people dialog.

Nothing checks the rule. A copied method and a shadowed kit name pass every spec.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
