---
id: "0203"
title: Gate notes behind a notes scope that read does not cover
status: active
created: 2026-10-22
area:
  - lib
  - db
  - api
  - mcp
issue: "#1925"
tags:
  - notes
  - oauth
  - scopes
  - consent
  - api-tokens
  - mcp
  - privacy
---

# ADR 0203: Gate notes behind a `notes` scope that `read` does not cover

![Active][status]

## Context

Spec #1923 adds private notes in folders, kept in the notes slice ADR 0200 records. Agents should do with notes
everything I do in the admin, but notes hold reference material, drafts and working thoughts written for nobody
else.

`read` reaches every record ([ADR 0061][0061]), and every client and API token holds it. [ADR 0147][0147],
[ADR 0151][0151] and [ADR 0188][0188] met the same problem for health data, mail and agent memory with a scope no
other scope covers. The spec asks for the same here.

## Decision

`Blog::Types::OAuthScope` gains `notes`. No other scope covers it, and it covers no other scope. A client asks for
it at consent and the owner ticks it on an API token, and it takes a consent line in
`slices/mcp/config/i18n/en.yml`. The `read` line names notes among what it leaves out.

- **Every notes and folders tool names `notes`**, whether it reads or writes. `write` does not reach them.
  `MCP::Protocol::ScopedServer` withholds them from a token without it.
- **Deleting a note or removing a folder also needs `delete`**, as every tool that removes a record for good does
  ([ADR 0114][0114]). Removing a folder moves its notes up a level, but the folder itself is gone.
- **Rows of every kind leave notes out.** `API::Endpoint::GUARDED` maps `notes` to the note and folder kinds, so
  search, record links and every other `read` answer that lists kinds drop them for a token without `notes`. A
  link, unlink or list that names a note or folder on either side gets a 403 naming `notes`, as mail threads do
  ([ADR 0093][0093]).
- **Nothing public** reads notes, whatever scope a request carries.

## Alternatives

**Put the tools on `read` and `write`.** Every client already connected would read my private notes the day they
shipped, with no consent screen in between, and any client with `write` could edit or rename them. Spec #1923 chose
a scope, as health, mail and agent memory have.

## Consequences

A client holds all of `notes` or none of it. A client fit to read notes may also create, edit, rename, move and tag
them without `write`. A rename rewrites `[[old title]]` links in every other note, so one call from such a client
can touch many notes at once.

A client connected before this change sees no notes until it connects again asking for `notes`, since a refresh
never widens a grant ([ADR 0061][0061]).

`notes` takes a migration: one `ALTER TYPE ... ADD VALUE` on `oauth_scope`.

A delete or folder removal names two scopes. `ScopedServer` withholds a tool that lacks any scope it names, and
its refusal names each one missing.

A later `read` endpoint that joins every kind gets notes dropped by the base class, but it should still drop them
in its query, or a page can come back short.

[0061]: 0061-narrow-a-requested-scope-to-known-names-and-withhold-every-tool-a-token-lacks.md
[0093]: 0093-link-any-two-records-through-one-record-links-table-in-a-links-slice.md
[0114]: 0114-grant-publishing-and-deleting-as-scopes-of-their-own.md
[0147]: 0147-gate-health-data-behind-a-health-scope-that-read-does-not-cover.md
[0151]: 0151-gate-mail-behind-a-mail-scope-that-read-does-not-cover.md
[0188]: 0188-gate-agent-memory-artifacts-and-sessions-behind-an-agents-scope.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
