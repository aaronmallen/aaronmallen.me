---
id: "0086"
title: Serve a JSON API behind long-lived tokens minted in the admin
status: active
created: 2026-10-01
area: [config, db, admin, mcp]
issue: "#153"
tags: [api, auth, tokens, cli, mcp, oauth, journal, tasks]
---

# ADR 0086: Serve a JSON API behind long-lived tokens minted in the admin

![Active][status]

## Context

I want to keep my journal and manage tasks from a terminal, through a Rust CLI. The site has no API. The MCP server
is the only way in for a program, and its OAuth flow suits claude.ai connectors, not a CLI. It asks for consent at
every sign-in, and again each time a refresh token lapses after 30 days ([ADR 0056][0056], [ADR 0059][0059]).

[ADR 0056][0056] turned down "an extra API, which is too much for one user", and a secret token from settings. Both
were weighed for Claude, where a connector needs OAuth. A CLI needs neither OAuth nor a second service: it needs a
token it can keep.

## Decision

The site serves a JSON API at `/api/v1` from a new `api` slice, which `config/routes.rb` mounts. Resources take
plain URLs, such as `/api/v1/journal_entries` and `/api/v1/tasks/:id/complete`.

A client sends an API token as a bearer token. I mint tokens in the admin, see each one once, and revoke any of
them there. A new table holds each token's name, a digest of it, when a client last used it and when I revoked
it, never the token itself. A token:

- never expires;
- can do anything the admin can, with no scopes;
- opens the API alone. MCP's OAuth tokens open MCP alone, and each door refuses the other's tokens with a 401.

MCP keeps its OAuth flow, consent and scopes as [ADR 0056][0056], [ADR 0059][0059] and [ADR 0061][0061] lay them
out. claude.ai and desktop connectors still need them.

[ADR 0056][0056] says every admin operation needs a tool. We widen that to a tool and an endpoint. An endpoint and
its tool share one layer, so they take the same input, run the same checks and return the same JSON. The rule
binds one resource at a time, as each moves to the API: journal entries and tasks first (#152), the rest in later
specs. Until a resource moves, its operations need a tool alone.

## Alternatives

**MCP's OAuth for the CLI.** One way in for every client, and no second kind of token. It loses because the CLI
would stop me for consent at each sign-in and again every 30 days, and would carry a browser flow a terminal tool
has no use for.

**Scoped tokens.** A leaked token would reach less. It loses because I mint every token myself, for a tool I run,
so a scope would only guard me from my own tools. MCP keeps its scopes, since there I hand a token to a client I
did not write.

**Expiring tokens.** A leaked token would stop working by itself. It loses for the same reason the OAuth flow
does: the CLI would need a fresh token on a schedule. Revoking in the admin, with the last use shown beside each
token, ends a token I no longer trust.

## Consequences

The CLI signs in once, with a token pasted into its config, and works until I revoke it.

A leaked API token can do anything the admin can, for as long as nobody notices. Nothing expires it. The last use
the admin shows is the only sign that a token I forgot about still works.

The site keeps only a digest, so a token I lose cannot be shown again. I mint a new one and revoke the old.

Two kinds of token now guard the site, each with its own table, checks and specs. A change to how one door signs
in does not carry to the other.

Every operation that moves to the API needs an endpoint beside its tool, and the shared layer has to keep the two
in step. Until every resource has moved, the rule holds for some resources and not others, and a reader has to
check which.

[0056]: 0056-serve-mcp-from-our-own-oauth-2-1-server-and-the-official-ruby-sdk.md
[0059]: 0059-gate-an-mcp-client-on-the-operators-consent-not-on-registration.md
[0061]: 0061-narrow-a-requested-scope-to-known-names-and-withhold-every-tool-a-token-lacks.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
