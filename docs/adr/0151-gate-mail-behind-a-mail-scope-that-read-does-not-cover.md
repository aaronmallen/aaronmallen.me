---
id: "0151"
title: Gate mail behind a mail scope that read does not cover
status: active
created: 2026-10-11
area: [lib, db, admin, api, mcp, contact]
issue: "#1123"
tags: [mail, gmail, oauth, scopes, consent, api-tokens, mcp, privacy]
---

# ADR 0151: Gate mail behind a mail scope that `read` does not cover

![Active][status]

## Context

Spec #1119 mirrors three Gmail accounts into the site and moves contact form messages into the same mail tables.
Agents should sort that mail, but most of it is mail strangers and colleagues sent to me, from a work account among
them, and none of it was written for the site.

Contact messages sit under `read` and `write` today, through the message tools, since AA-824 widened `read` to
every record (ADR 0062). Every client and API token holds `read`, so mail on `read` would reach every client
already connected. ADR 0147 met the same problem for health data with a scope `read` does not cover.

## Decision

`Blog::Types::OAuthScope` gains `mail`. No other scope covers it, and it covers no other scope. A client asks for it
at consent and the owner ticks it on an API token, as with `health`, and it takes a consent line (ADR 0061). The
`read` line stops naming messages.

- **The mail tools** replace the message tools, and each names `mail`, whether it reads, marks, labels, archives,
  snoozes or deletes. `MCP::Protocol::ScopedServer` withholds them from a token without it. Mail bodies come back
  marked untrusted.
- **Tools on `read` that list rows of every kind** leave mail threads out unless the token also holds `mail`:
  `read_activity`, `summarize_activity`, `search`, `list_inbox`, `list_attention`, record links and saved views. The
  rest of each answer reads as it does now, as ADR 0147 does for workouts.
- **Google events stay on `read`**, in `list_calendar`.

## Alternatives

**Leave mail on `read`, as contact messages were.** Every connected client would start reading three inboxes the day
the sync shipped, with no consent screen in between. Spec #1119 asked for a scope, as `health` has.

## Consequences

`mail` grants writes as well as reads. A tool names one scope (ADR 0061), so a client that may read mail may also
archive, label and delete it without `write` or `delete`.

A client that reads contact messages under `read` today loses them, and has to connect again asking for `mail`,
since a refresh never widens a grant (ADR 0061).

The `api_tokens_scopes_check` constraint in `config/db/structure.sql` lists every scope, so `mail` needs a migration
to widen it, as `health` did.

More endpoints check a scope by hand. ADR 0147 left one, `read_activity`; mail adds search, the inbox, attention,
links and saved views. A later `read` endpoint that joins every kind has to drop both workouts and mail threads, and
nothing but its specs will catch one that forgets.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
