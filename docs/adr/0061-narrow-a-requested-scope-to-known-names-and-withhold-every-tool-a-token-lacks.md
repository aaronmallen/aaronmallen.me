---
id: "0061"
title: Narrow a requested scope to known names and withhold every tool a token lacks
status: active
created: 2026-09-28
area: [mcp, lib]
issue: AA-677
amended: [AA-811]
tags: [mcp, oauth, scopes, tools, consent, sdk]
---

# ADR 0061: Narrow a requested scope to known names and withhold every tool a token lacks

![Active][status]

## Context

Until AA-390 no MCP token carried a scope. The consent page listed what a client could do, and nothing checked
it, so when `write_post_seo` landed every token already issued could write to a live post on its next call. AA-348
settled four scopes, `read`, `suggest`, `write` and `activity`, and asked for a rule short enough to apply to a
tool nobody has written yet. AA-390 built it and put the check where the tool runs. How the SDK learns which tools
a token may call, and what a client hears when it may not, are the two parts of that rule later tools inherit.

## Decision

**A grant keeps only the names the server knows.** `MCP::OAuth::Scope.granted` keeps the names in `Scope::ALL`
that the client asked for and falls back to `Scope::DEFAULT`, `read` alone, when none are left.
`MCP::Operations::Authorize` narrows the request before the consent page, so the page shows what the token will
carry, not what the client asked for. A scope that breaks the OAuth grammar still gets `invalid_scope` from
`MCP::Contracts::AuthorizationRequestContract`; a well formed name the server does not know is dropped. The
authorization code stores the granted set, both tokens copy it, a refresh copies the old set and never widens it
(`MCP::Operations::IssueToken`), and `IssueTokens` returns it in `scope`. Both `scopes` columns in
`config/db/structure.sql` default to `{read}`.

**Each tool names one scope, and `MCP::Protocol::ScopedServer` is the only check.** `MCP::Tools::Base` gives
every tool a `scope` line. `MCP::Protocol::Handler` builds a `ScopedServer` per request from the token's scopes,
and it leaves every tool the token lacks out of `tools/list`. A call to one of them gets an MCP error that names the
tool and the missing permission and says to connect again, where the SDK would say `Tool not found`. To do that,
`ScopedServer` overrides the SDK's private `MCP::Server#call_tool`.

A new scope needs three things: a name in `Scope::ALL`, a consent line under `scopes` in
`slices/mcp/config/i18n/en.yml`, and a tool that names it. `scopes_supported` in the metadata reads `Scope::ALL`
on its own.

## Alternatives

**Answer `invalid_scope` for a name the server does not know.** AA-348 chose to keep the known names instead.
OAuth lets a server grant less than a client asked for as long as the token response says what it granted, and
this one does.

**Separate read and write tokens, and no scopes** (AA-348, AA-390). Nothing stops one client holding both, and
then the split is a naming habit. It also leaves the choice of token to the caller, the side the check defends
against.

**A check inside each tool.** Every new tool would have to remember it, and one that forgot would run for every
token. With the scope on the class and one check that reads it, a tool with no scope matches no token and is
withheld from all of them. `spec/slices/mcp/requests/scopes_spec.rb` fails when a tool names a scope the server
does not know, since a token holding every scope would not see that tool in `tools/list`.

**A check in `MCP::Actions::Messages::Create`.** The action holds the raw request body. It would have to parse the
JSON-RPC ahead of the SDK to find the tool, and it could not take a tool out of `tools/list`.

**Let the SDK say `Tool not found`.** A token that predates a scope, or was granted less than it needs, has no
other way to learn why a tool failed. AA-348 settled that the refusal says to connect again: AA-390 already made it
an MCP error rather than a 500, so the sentence costs nothing.

## Consequences

**A client that misspells a scope connects with less than it meant.** A client asking for `wirte` connects with
`read` and learns at `tools/call`. The consent page and the `scope` in the token response both show the narrower
set, but a client that reads neither finds out late.

**The reconnect message rests on a private SDK method.** If a release renames or reshapes `MCP::Server#call_tool`,
the override stops running. A withheld tool is still missing from the server and still refused, but the client
hears `Tool not found` again. `spec/slices/mcp/requests/endpoint_spec.rb` pins the message, so an SDK bump that
breaks it fails the suite.

**Filtering the list is not the check.** A client that calls a tool it never saw listed gets the same refusal, so
nothing depends on a client hiding a tool it was not shown.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
