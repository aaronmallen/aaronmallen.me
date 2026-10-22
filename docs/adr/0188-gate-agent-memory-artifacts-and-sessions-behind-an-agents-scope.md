---
id: "0188"
title: Gate agent memory, artifacts and sessions behind an agents scope
status: active
created: 2026-10-17
area:
  - lib
  - db
  - api
  - mcp
issue: "#1741"
amended:
  - "#1743"
  - "#1749"
  - "#1823"
  - "#1860"
  - "#1925"
  - "#1937"
tags:
  - agents
  - oauth
  - scopes
  - consent
  - api-tokens
  - mcp
  - untrusted
---

# ADR 0188: Gate agent memory, artifacts and sessions behind an `agents` scope

![Active][status]

## Context

The `agents` slice ([ADR 0186][0186]) holds what agents remember. A fact loads into every later session the moment
it lands, with no review in between. A client that can write memory can steer every agent that loads it.

`read` reaches every record ([ADR 0061][0061]), and every client and API token
holds `read`. [ADR 0147][0147] and [ADR 0151][0151] met a like problem for health data and mail with a scope that no
other scope covers.

## Decision

`Blog::Types::OAuthScope` gains `agents`. No other scope covers it, and it covers no other scope. A client asks for
it at consent and the owner ticks it on an API token, and it takes a consent line in
`slices/mcp/config/i18n/en.yml`.

- **Every memory, artifact and session tool names `agents`**, whether it reads or writes.
  `MCP::Protocol::ScopedServer` withholds them from a token without it.
- **Removal tools also need `delete`**, as every tool that removes a record for good does ([ADR 0114][0114]).
- **Text an agent wrote comes back marked** `{ untrusted: true, text }`, so the agent that loads a fact knows another
  agent wrote it.
- **Record links follow the scope** (#1749). Without `agents`, `link_records`, `unlink_records` and `list_links`
  refuse a memory file or artifact on either side, naming `agents`, and every record's links leave them out, as mail
  threads stay behind `mail` ([ADR 0093][0093]).

## Alternatives

**Put the tools on `read` and `write`.** Every client already connected would read and write agent memory the day
it shipped, with no consent screen in between, and any client with `write` could plant a fact that loads into every
session.

## Consequences

A client holds all of `agents` or none of it. Memory, artifacts and sessions come as one grant, reads and writes
alike.

A client connected before this change sees none of the tools until it connects again asking for `agents`, since a
refresh never widens a grant ([ADR 0061][0061]).

The `api_tokens_scopes_check` constraint in `config/db/structure.sql` lists every scope, so `agents` takes a
migration to widen it, as `health` and `mail` did. Since #1823 the column is `oauth_scope[]`, and a new scope is
one `ALTER TYPE ... ADD VALUE`.

A removal tool names two scopes. Since #1743 `ScopedServer` withholds a tool that lacks any scope it names, and its
refusal names each one missing. The API asks a token for both the same way.

Since #1860 a session starts with an index of memory files, and a fact reaches an agent when it reads the file
with `read_memory_file` or matches a `search_memory` query ([ADR 0195][0195]). A bad fact still reaches every agent
that reads its file, and only the untrusted marker warns of it. I catch a bad fact through its history and revert
it.

Since #1925, [ADR 0203][0203] gates notes behind a `notes` scope the same way.

Since #1937, [ADR 0204][0204] adds `contacts`, another scope no other covers, for a person's private fields.

[0061]: 0061-narrow-a-requested-scope-to-known-names-and-withhold-every-tool-a-token-lacks.md
[0093]: 0093-link-any-two-records-through-one-record-links-table-in-a-links-slice.md
[0114]: 0114-grant-publishing-and-deleting-as-scopes-of-their-own.md
[0147]: 0147-gate-health-data-behind-a-health-scope-that-read-does-not-cover.md
[0151]: 0151-gate-mail-behind-a-mail-scope-that-read-does-not-cover.md
[0186]: 0186-keep-agent-memory-artifacts-and-sessions-in-an-agents-slice.md
[0195]: 0195-load-agent-memory-as-an-index-and-read-it-on-demand.md
[0203]: 0203-gate-notes-behind-a-notes-scope-that-read-does-not-cover.md
[0204]: 0204-gate-private-contact-fields-behind-a-contacts-scope.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
