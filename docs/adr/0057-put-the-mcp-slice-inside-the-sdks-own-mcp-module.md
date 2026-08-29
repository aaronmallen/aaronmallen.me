---
id: "0057"
title: Put the mcp slice inside the SDK's own MCP module
status: active
created: 2026-09-28
area: [config, lib, mcp]
issue: AA-675
amended: [AA-809]
tags: [mcp, sdk, zeitwerk, inflection, namespace, autoload]
---

# ADR 0057: Put the `mcp` slice inside the SDK's own `MCP` module

![Active][status]

## Context

Hanami names a slice's module from its directory through the app's inflections. `config/app.rb` lists `MCP` as an
acronym, so `slices/mcp` becomes `MCP`, the module the official Ruby MCP SDK defines. The slice's tools, prompt and
server subclass the SDK's classes, and the SDK autoloads `Client`, `Content`, `Prompt`, `Resource`, `Server`,
`Tool` and more straight under `MCP` (`mcp-1.5.1/lib/mcp.rb`).

## Decision

The slice shares the SDK's `MCP` module. `slices/mcp/config/slice.rb` requires the gem before it opens
`module MCP`, and pushes `lib/mcp` into the same module. Slice code names the SDK's classes bare:
`MCP::Tools::Base < Tool`, `MCP::Protocol::ScopedServer < Server` and `MCP::Prompts::Proofread < Prompt`. That
is the gain: the classes the slice builds on read as if they were its own.

The rule that comes with it: no file or directory directly under `slices/mcp` or `lib/mcp` takes a name the SDK
defines under `MCP`. Before adding one, check the constants in the SDK's `lib/mcp.rb` and its `lib/mcp/`
directory.

## Alternatives

Nobody weighed either of these in writing. They are the two ways out of the shared module.

**Drop `MCP` from the acronyms**, so the slice becomes `Mcp` and its code writes `::MCP::Tool`, `::MCP::Server`
and `::MCP::Prompt`. The slice keeps its own module, and every name the SDK owns needs the full path.

**Name the slice something else.** The slice gets a module of its own the same way, under a name other than the
protocol's, and still names the SDK's classes in full.

## Consequences

**A clash fails in silence.** Zeitwerk raises nothing for a `slices/mcp/client.rb`
(`zeitwerk-2.8.3/lib/zeitwerk/loader.rb`). If the SDK's `MCP::Client` has loaded, Zeitwerk skips our file and only
logs it, so the SDK's class answers in its place. If it has not, Zeitwerk sets its own autoload over the gem's, so
our file loads instead and SDK code that names `MCP::Client` gets our class. For a directory, Zeitwerk loads the
gem's module and puts the slice's classes inside it, so an SDK release that adds `MCP::Tools` or `MCP::Protocol`
mixes our classes into its module with no error.

**No spec guards the rule.** An SDK bump is the moment to check the new constants against the slice's names.

**Hanami and the SDK own one module.** Hanami puts `MCP::Slice`, `MCP::Deps` and the slice's components there, so
a future SDK constant with one of those names would clash too.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
