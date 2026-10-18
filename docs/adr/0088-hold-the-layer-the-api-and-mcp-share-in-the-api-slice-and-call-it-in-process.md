---
id: "0088"
title: Hold the layer the API and MCP share in the api slice, and call it in process
status: active
created: 2026-10-01
area: [api, mcp]
issue: "#154"
amended: ["#927", "#1001", "#1188", "#1823"]
tags: [api, mcp, slices, exports, openapi, json-schema, journal, tasks]
---

# ADR 0088: Hold the layer the API and MCP share in the api slice, and call it in process

![Active][status]

## Context

[ADR 0086][0086] puts a JSON API at `/api/v1` beside the MCP server, and asks that an endpoint and its MCP tool take
the same input, run the same checks and return the same JSON. Today each MCP tool holds that work itself: it parses
its input, pages a list, calls a feature slice's operation or query through the keys `MCP::Protocol::Handler` puts
in its server context, and builds its JSON by hand. An endpoint written the same way would be a second copy, and the
two would drift.

The CLI builds its client from `/api/v1/openapi.json`, so that document has to match what the endpoints take.

[ADR 0003][0003] bounds where the work can live: a slice reaches another only through its exports, and a repo never
leaves its slice.

## Decision

The shared layer lives in the `api` slice, under `slices/api/endpoints`, with one class per endpoint. Each class
holds the JSON Schema for its input, does the work a tool does today, calls the feature slice's operation or query
through the `api` slice's own imports, and returns a result whose payload the API's serializers built. A failure
comes back as a result too, such as the errors from an operation's contract.

Both doors call the same class, in process:

- An API action reads the request, calls the endpoint and turns its result into a status: 200 or 201 for a
  success, 404 for a missing record, 422 for a contract's errors. Since #1001 one action, `API::Actions::Forward`,
  serves every endpoint, and the operation table in `BuildDocument` draws the routes as well as the document.
- `api` exports each endpoint. `mcp` imports them in `slices/mcp/config/slice.rb` and puts them in the tool's server
  context. A tool keeps its name and description, takes its input schema from the endpoint, hands the work
  over and wraps the payload as its answer, or the failure as its refusal. #1823 took the scope off the tool and
  onto the operation's row, which the tool and `Forward` both read.

`api` builds `/api/v1/openapi.json` by walking its endpoints: each one's schema gives the request, and its
serializer gives the response. No schema is written twice, so the document, the tools and the endpoints cannot
disagree.

The edge runs one way. `mcp` imports from `api`, and `api` never imports from `mcp`, so it adds no cycle to the three
[ADR 0003][0003] names. Journal entries and tasks joined the layer first.

From #927 on, a resource moved one tool at a time, because moving a tool changes what it returns. Since #1188 every tool
sits on the layer: each hands its work to an endpoint through `endpoint` or `hand_over`, and no tool calls an
operation or a repo itself. `MCP::Protocol::Handler` keeps no table of operations and repos for its tools, only their
endpoints and the repo that marks synced task titles untrusted. `list_clients` reads the MCP clients through
relations the `api` slice keeps on the same tables, since `api` cannot import from `mcp`.

## Alternatives

**MCP calls the API over HTTP with a token.** The API would be the one layer, and MCP one more client of it. It
loses because MCP would need a token of its own, full access and never expiring, held where a leak reaches the whole
admin, for a call that never leaves the process. Each tool call would pay for a round trip and a second token check,
and the tool would turn status codes and JSON errors back into refusals. A fault in the API, or a revoked token,
would break MCP too.

**The layer in each feature slice**, such as `record` and `tasks`, exported to both doors. It keeps `mcp` from
depending on `api`. It loses because the layer's work is the work of a door: it shapes JSON, holds the schemas the
OpenAPI document reads and pages lists for a client. Feature slices would take on the serializers too, and every
resource that moved would spread the API across another slice.

**Each door keeps its own code**, both calling the operations straight. No new layer. It loses because nothing
then holds the input and the JSON the same, and the OpenAPI document would describe code it never read.

## Consequences

A change to an endpoint's input or JSON reaches the API, its tool and the OpenAPI document in one edit, and the
spec that compares a tool's answer with its endpoint's catches the rest.

`mcp` now depends on `api`, a presentation slice on another. A key `api` stops exporting breaks every tool that
reached it, and `api` can never import from `mcp` without closing a cycle.

A tool on the layer no longer shows its work. A reader follows it into `slices/api/endpoints` to see what it calls.

The layer, not the tool, now calls the operation the admin calls, so [ADR 0056][0056]'s rule that MCP refuses what
the admin refuses still holds, one step further down.

[0003]: 0003-reach-another-slice-only-through-its-exports.md
[0056]: 0056-serve-mcp-from-our-own-oauth-2-1-server-and-the-official-ruby-sdk.md
[0086]: 0086-serve-a-json-api-behind-long-lived-tokens-minted-in-the-admin.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
