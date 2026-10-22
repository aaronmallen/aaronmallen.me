---
id: "0151"
title: Gate mail behind a mail scope that read does not cover
status: active
created: 2026-10-11
area:
  - lib
  - db
  - admin
  - api
  - mcp
  - contact
issue: "#1123"
amended:
  - "#1380"
  - "#1598"
  - "#1823"
tags:
  - mail
  - gmail
  - oauth
  - scopes
  - consent
  - api-tokens
  - mcp
  - privacy
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
- **A client's delete goes to the Trash.** `delete_mail_threads` runs the `trash` act, so a Gmail thread lands in
  Gmail's Trash and every thread lands in the site's trash folder, where the owner can restore it. Only the admin's
  "Delete forever" deletes for good.
- **Tools on `read` that list rows of every kind** leave mail threads out unless the token also holds `mail`:
  `read_activity`, `summarize_activity`, `search`, `list_inbox`, `list_attention`, record links and saved views. The
  rest of each answer reads as it does now, as ADR 0147 does for workouts.
- **`API::Endpoint` holds the filter.** Before any endpoint answers, the base class drops each row whose `kind` is
  `workout` from a token without `health`, and each `message` or `mail_thread` row from a token without `mail`. An
  endpoint that drops them in its query as well keeps its counts and pages right; one that forgets leaks nothing.
- **Google events stay on `read`**, in `list_calendar`.

## Alternatives

**Leave mail on `read`, as contact messages were.** Every connected client would start reading three inboxes the day
the sync shipped, with no consent screen in between. Spec #1119 asked for a scope, as `health` has.

## Consequences

`mail` grants writes as well as reads. A tool names one scope (ADR 0061), so a client that may read mail may also
archive, label and delete it without `write` or `delete`. Since a message from a stranger can ask an agent to delete
mail, and Gmail cannot bring back a thread it deleted, a client's delete stops at the Trash.

A client that reads contact messages under `read` today loses them, and has to connect again asking for `mail`,
since a refresh never widens a grant (ADR 0061).

The `api_tokens_scopes_check` constraint in `config/db/structure.sql` lists every scope, so `mail` needs a migration
to widen it, as `health` did. Since #1823 the column is `oauth_scope[]`, and a new scope is one
`ALTER TYPE ... ADD VALUE`.

More endpoints check a scope by hand. ADR 0147 left one, `read_activity`; mail adds search, the inbox, attention,
links and saved views. A later `read` endpoint that joins every kind gets both kinds dropped by the base class, but
it should still drop them in its query, or a page can come back short. One request spec calls every API operation
with a `read` token over a workout and a mail thread, and fails when either shows.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
