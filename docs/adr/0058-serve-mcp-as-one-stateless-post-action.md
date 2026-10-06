---
id: "0058"
title: Serve MCP as one stateless POST action
status: active
created: 2026-09-28
area: [mcp]
issue: AA-679
amended: ["#463", "#573"]
tags: [mcp, transport, json-rpc, sdk, cors, sessions, hanami-actions]
---

# ADR 0058: Serve MCP as one stateless POST action

![Active][status]

## Context

We take the MCP protocol from the official Ruby SDK. The SDK can speak it two ways. `MCP::Server#handle_json`
takes one JSON-RPC body and returns the answer as a string. `MCP::Server::Transports::StreamableHTTPTransport` is a
Rack app that wraps a server and adds sessions, server-sent event streams, a body cap, `Host` and `Origin` checks,
and a stateless mode.

Every call to `/mcp` has to carry a bearer token from our OAuth server, and a missing or bad one gets a 401 with a
`WWW-Authenticate` challenge that names the resource metadata. The tools a caller sees depend on the scopes its
token holds.

## Decision

`/mcp` is one Hanami action, `MCP::Actions::Messages::Create`, on one `POST` route in
`slices/mcp/config/routes.rb`, with an `OPTIONS` preflight beside it. Each request stands alone.

- The action checks the bearer token through `Operations::Authenticate`, reads at most
  `Blog::ParamsGuard::ENCODED_UPLOAD_LIMIT` of the body, and hands the raw string to `MCP::Protocol::Handler#call`.
  Since #573 that is the cap `ParamsGuard` sets on `/mcp`, room for a 25 MB photo in base64, so `upload_photo`
  takes the photos `POST /api/v1/photos` takes. It read 1 MiB before, which cut off any photo over about 750 KB.
- The handler builds a new `ScopedServer` for that token's scopes and calls `handle_json` with no session. A
  notification answers 202 with no body, and anything else answers `application/json`.
- The handler refuses a JSON-RPC batch with `-32600` before the server sees it (AA-698).
- `MCP::Action#render_body` sets `Access-Control-Allow-Origin: *` on every answer, and
  `MCP::Actions::Preflights::Show` answers the preflight for `POST` with `Authorization`, `Content-Type` and
  `MCP-Protocol-Version` (AA-597), so an MCP client running in a browser can call the server. `/mcp` sits outside
  the session middleware, which the routes mount on the OAuth scope alone, so the bearer token is the only
  credential the endpoint reads. Since #463 `POST /oauth/register` sends no `Access-Control-Allow-Origin` and has
  no preflight route, so a web page cannot make its readers' browsers register clients.

The bearer check, the headers and the errors stay in Hanami, beside the rest of the slice's actions.

## Alternatives

**The SDK's Streamable HTTP transport, stateful or stateless.** AA-265 built the endpoint as an action and did not
weigh the transport, and no record or issue since has. What the code shows of it:

- The transport wraps one server built up front, while our tool list changes with each token's scopes.
- Stateful mode keeps its sessions in a Hash inside one process, so a request that lands on another Puma worker
  finds no session. Puma runs in cluster mode when `HANAMI_WEB_CONCURRENCY` is above one, and the SDK notes that
  sending notifications across processes needs an event bus it does not ship.
- Its `Host` check allows only loopback names unless told otherwise, so behind the tunnel it needs the site's
  host passed in or the check turned off.
- Stateless mode would give us its batch refusal and body cap, but none of the push, progress or session
  features the stateful mode exists for.

## Consequences

The endpoint is plain request and response, which the request specs in `spec/slices/mcp/requests/endpoint_spec.rb`
drive with rack-test, `GET /mcp` included, which answers 405.

With no session, `handle_json` drops every progress and log message a tool sends. No tool can report progress, the
server cannot push anything to a client, and it can never tell a client its tool list changed. A client that
gains a scope has to connect again to see the new tools.

Each request builds a server and registers every tool on it. On a site with one caller the cost is small, but it
is paid on every call.

We copy what the transport would have given us. AA-698 added the batch refusal once it found one body could carry
thousands of tool calls, and the body cap and the CORS headers are ours to keep in step with the MCP
spec. The cap comes from `ParamsGuard`, so a change to the upload limit moves both.

`ScopedServer` overrides the SDK's private `call_tool` to refuse a withheld tool with a message that tells the
operator to connect again. A private method can change in any release, so each SDK upgrade has to check that
override.

A feature that needs progress, push, a session or a stream reopens this choice.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
