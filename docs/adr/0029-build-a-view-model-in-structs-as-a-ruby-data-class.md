---
id: "0029"
title: Build a view model in structs/ as a Ruby Data class
status: active
created: 2026-09-28
area: [lib, activity, admin, analytics, contact, mcp, posts, projects, public, record, social, suggestions, tags, tasks]
issue: AA-661
amended: [AA-783]
tags: [structs, data, view-models, rom]
---

# ADR 0029: Build a view model in `structs/` as a Ruby `Data` class

![Active][status]

## Context

Hanami hands `<Slice>::Structs` to ROM as the repo's struct namespace, and ROM builds a relation's struct there by
class name under `ROM::Struct`. A slice also builds values no relation reads: the admin menu, its sections, the
networks a social post can go to. The former ADR 0002 kept these view models in `slices/admin/structs` and said
nothing of what they are made of.

## Decision

`structs/` holds two kinds of class. The ROM structs a slice's relations build inherit `Blog::DB::Struct`. The view
models a slice builds itself are Ruby `Data` classes: the five in `slices/admin/structs`,
`Analytics::Structs::AnalyticsSummary` and `Tasks::Structs::Link`. A `Data` class is not a record, so it sits beside
the code that builds it, such as `Admin::Operations::ListSections` for `Section`, the analytics event repo for
`AnalyticsSummary` and `Tasks::Structs::Task` for `Link`.

## Consequences

The superclass tells the two kinds apart: `Blog::DB::Struct` for a row, `Data` for a view model.

A `Data` member takes any value. The type check falls to the component that reads it, as
`prop :networks, Types::Array.of(Types::Instance(Structs::Network))` does, so a builder that passes the wrong thing
fails where the page draws, not where the builder made it. A default needs its own `initialize`, the way
`AnalyticsSummary` defaults its lists.

A `Data` class in `structs/` must not share a name with a relation the slice may gain. ROM would find the `Data`
class where it means to build its own, so `Admin::Structs::Network` beside a `networks` relation raises
`Dry::Core::ClassBuilder::ParentClassMismatch` on the first read.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
