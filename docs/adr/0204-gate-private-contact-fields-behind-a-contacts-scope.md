---
id: "0204"
title: Gate private contact fields behind a contacts scope
status: active
created: 2026-10-22
area:
  - lib
  - db
  - api
  - mcp
issue: "#1937"
tags:
  - contacts
  - people
  - oauth
  - scopes
  - consent
  - api-tokens
  - mcp
  - privacy
---

# ADR 0204: Gate private contact fields behind a `contacts` scope

![Active][status]

## Context

Spec #1933 grows People into contacts synced with Google (ADR 0201). A person holds a key, a name and a
Mastodon or Bluesky handle today, and agents read them on `read` to write `@key` mentions. A contact adds phones,
emails, addresses, birthdays, notes and the rest of an address book: facts about other people, which none of them
gave the site.

`read` reaches every record ([ADR 0061][0061]), and every client and API token holds it. [ADR 0147][0147],
[ADR 0151][0151] and [ADR 0188][0188] met a like problem with a scope no other scope covers. Those scopes guard
whole tools. Here the same record has to stay half open, or mentions break for every client connected today.

## Decision

`Blog::Types::OAuthScope` gains `contacts`. No other scope covers it, and it covers no other scope. A client asks
for it at consent and the owner ticks it on an API token, and it takes a consent line in
`slices/mcp/config/i18n/en.yml`. The `read` line names contacts' private fields among what it leaves out.

- **The contact tools keep `read` and `write`.** Unlike `health`, `mail` and `agents`, `contacts` widens what those
  tools return and take; it adds no tool of its own.
- **A short list of fields stays open:** the ID, name, key and Mastodon and Bluesky handles. Without `contacts`, a
  person in any API or MCP answer carries those and nothing else. Every other field is private, a field added later
  included, so a new field leaks nothing until someone opens it here.
- **Writes check the body.** A create or edit that sets a private field from a token without `contacts` gets the
  403 `insufficient_scope` naming `contacts`, as a public target refuses a token without `publish`
  ([ADR 0114][0114]). One that sets only open fields goes through on `write`.
- **A contact search matches only the open fields** for a token without `contacts`, so a query cannot test whether
  someone has a given phone or email.
- **Deleting a contact needs `contacts` and `delete`.** A delete reaches Google and takes the private fields with it,
  so a token has to be able to read what it destroys. Running a sync needs `contacts` and `write`, since a sync
  rewrites private fields.
- **The mail threads on a contact stay behind `mail`** ([ADR 0151][0151]).

## Alternatives

**Put every contact field on `read`.** Every client already connected would read the whole address book the day the
sync shipped, with no consent screen in between. Spec #1933 asked for a scope.

**Gate the whole contact behind `contacts`**, as `health` gates health days. A client without it could no longer
look up a key, and every mention an agent writes today would need a new grant. Spec #1933 kept name, key and handles
readable for that reason.

## Consequences

`contacts` does nothing on its own. A token needs `read` to see the private fields and `write` to change them, so the
consent page and the token form show a scope that only widens two others.

The check lives in what a person's answer carries and what a body sets, not in `MCP::Protocol::ScopedServer`, so
withholding a tool does not cover it. Every endpoint that returns a person has to
pass it through the same narrowing, and only request specs catch one that forgets.

A client that deletes people with `delete` alone today loses that until it connects again asking for `contacts`,
since a refresh never widens a grant ([ADR 0061][0061]).

Since #1823 every `scopes` column is `oauth_scope[]`, so `contacts` takes one `ALTER TYPE ... ADD VALUE`
migration.

[0061]: 0061-narrow-a-requested-scope-to-known-names-and-withhold-every-tool-a-token-lacks.md
[0114]: 0114-grant-publishing-and-deleting-as-scopes-of-their-own.md
[0147]: 0147-gate-health-data-behind-a-health-scope-that-read-does-not-cover.md
[0151]: 0151-gate-mail-behind-a-mail-scope-that-read-does-not-cover.md
[0188]: 0188-gate-agent-memory-artifacts-and-sessions-behind-an-agents-scope.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
