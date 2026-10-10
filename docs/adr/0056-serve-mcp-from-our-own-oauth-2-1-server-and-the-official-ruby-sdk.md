---
id: "0056"
title: Serve MCP from our own OAuth 2.1 server and the official Ruby SDK
status: active
created: 2026-09-28
area: [config, mcp, admin]
issue: AA-262
amended: [AA-348, AA-390, AA-408, AA-480, AA-525, AA-537, AA-663, AA-809, AA-824, "#153", "#551", "#932", "#941"]
tags: [mcp, auth, oauth, github, tokens, claude, scopes]
---

# ADR 0056: Serve MCP from our own OAuth 2.1 server and the official Ruby SDK

![Active][status]

## Context

The operator wanted Claude to catch grammar and spelling mistakes in drafts before they go live (AA-212). Pasting a
draft into a chat and fixing each mistake by hand is dull enough that the operator skips it.

The app then grew around the server. Before AA-824 an agent could read commits, journal entries and finished tasks
through the feed and write through three narrow tools, and nothing else. It could not hand back a full account of a
date range, and it could not act on "write a journal entry about abc". Each feature that shipped widened the gap.

Claude has to reach the site from claude.ai, the desktop app and Claude Code. That needs a public server on the
live site, since a local one only sees the local database. The claude.ai and desktop connectors expect MCP's OAuth
flow with dynamic client registration. GitHub's OAuth has no client registration, so Claude cannot go straight to
GitHub.

This server is the one public door into everything the admin holds, so the grant is the whole control.

## Decision

We run an MCP server in `slices/mcp` and take the protocol from the official Ruby SDK, which
`slices/mcp/config/slice.rb` loads, rather than writing it ourselves.

The slice holds its own OAuth 2.1 server: discovery, dynamic client registration, authorize and token
(`slices/mcp/config/routes.rb`). `Blog::Types::CodeChallengeMethod` allows only PKCE `S256`, and
`Blog::Types::OAuthTokenAuthMethod` only public clients. Authorize signs the operator in through the admin's GitHub
sign-in, which takes only a GitHub account listed in the admin's `owner_identities` table, and asks the operator to
approve the client before it issues a code. Any other account gets no code and no token. The types were
`MCP::OAuth::Metadata`, and the sign-in check named one GitHub ID, until #941 corrected them here.

- An access token lasts one hour and a refresh token 30 days (`MCP::Operations::IssueTokens`).
- We store a SHA-256 digest of each token and code, never the value (`Blog::Types::SecretDigest`, which #941
  corrected from `Blog::SecretToken`).
- A token is bound to this server. `MCP::Operations::Authorize` fills in the resource from the protected resource
  metadata when a client sends none, since RFC 8707 leaves it optional there, and `MCP::Operations::Authenticate`
  refuses a token that names no resource or another one (AA-408).
- The connected clients page in the admin lists each client and revokes it, through the query and the operation
  `mcp` exports.

`config/routes.rb` mounts the slice at `/`, not `/mcp`, because discovery has to sit at the root of the issuer, and
the issuer is the configured site URL (AA-480). So `/.well-known`, `/oauth` and `/mcp` belong to `mcp`, and the
resource itself answers at `/mcp`. `public` may not route under any of the three.

The slice owns the three tables that server needs: `oauth_clients`, `oauth_codes` and `oauth_tokens`. They are not
a feature's records. They are the door's own rows (AA-525).

A token carries scopes, and each tool names the one it needs (AA-348, AA-390). The record filed under AA-677 says
how we grant and check a scope. An agent holding the right scopes reads and writes everything the operator can in
the admin (AA-824):

- `read`: every record the backend keeps, analytics, contact messages, site settings and sync state included, and
  the whole activity feed. A commit goes out with its full message, never cut. The record on the activity feed says
  why the feed needs no scope of its own.
- `suggest`: a set of edits for one post or social post, each holding the exact original text, its replacement and
  a short reason. It changes no content. Each edit waits for the operator to accept or reject it in the admin. A new
  set drops every open edit on that post, pending and stale alike, and any older suggestion left with no edits
  (`slices/suggestions/repos/suggestion_repo.rb`).
- `write`: every other write the admin makes. Since #551, publishing a post and sending a social post need
  `publish`, and deleting a record needs `delete`, as [ADR 0114][0114] records (#932).

A write tool calls the operation the admin calls for the same change, through the slice's exports, so the MCP
refuses whatever the admin refuses and never saves a record the admin could not. Background jobs and sync
internals, such as imports, reaps, rollups, delivery, sign in and OAuth, have no tool.

## Alternatives

**A hosted identity provider** with client registration, such as WorkOS or Auth0, in the same slice. Less auth code,
but it adds a vendor account, and the admin's safety would then rest on that vendor.

**A separate MCP service** talking to the site over a new internal API. Kept apart from the app, but it means two
things to deploy and an extra API, which is too much for one user. #153 added an API for a CLI, in the same app
beside this slice, as [ADR 0086][0086] records.

**A secret token from settings**, for Claude Code only. Much simpler auth, but claude.ai and desktop connectors
expect OAuth. #153 gave the API long-lived tokens minted in the admin, and they do not open MCP
([ADR 0086][0086]).

**A local stdio server.** No public endpoint, but it only sees the local database, not the drafts on the live site.

**Proofreading through direct edits**, with version history, or read only with fixes given in chat. Direct edits
put each fix in Claude's hands before the operator sees it, and fixes in chat bring back the copying by hand.
`write` now edits a post outright, but a proofreading pass still goes through `suggest`.

**A feature slice for the OAuth tables**, leaving `mcp` the protocol and the tools. It would end the import cycle
admin and mcp share, since the connected clients page would move with the tables. It loses because the two halves
are one door. The tokens table holds scopes and the tool classes say what a scope means, so adding a tool would
change two slices for one thing.

**A proofreading door.** The first version of this record kept the server small: `read` reached posts and unsent
social posts, `write` a post's `og_title` and `og_image_url` alone, `activity` commits, journal entries and finished
tasks, and no tool published, sent or deleted anything. Webmentions, analytics and settings stayed out of reach. It
kept a leaked token from doing much, and it kept the everyday proofreading connector, holding `read suggest`, off
published posts. It lost because the operator wants to hand an agent a date range and get back everything, and to
ask it for any change the admin makes. Every feature that shipped left the agent further behind.

**A scope of its own for publishing, sending and deleting.** It would keep those steps out of a connector granted
only edits. AA-824 ruled it out and put every write under `write`. #551 took it up, as [ADR 0114][0114] records.

**Write tools that reach the repos.** Fewer layers, but a tool could then save a record the admin would refuse, and
no slice lets another reach its repos.

**Mounting the slice at `/mcp`**, as the first version of this record said. It keeps every MCP route under one
prefix, but discovery would no longer sit at the issuer root, where it has to be.

## Consequences

No third party stands between the operator and the admin, and the slice sits beside the admin in the same app.

We own the most auth code of any option, and OAuth is easy to get subtly wrong. Discovery, registration, authorize
and token each need request specs, failure cases included.

The server takes on the costs of the GitHub sign-in: while GitHub is down, no new client can connect, and a new
connection is only as safe as the GitHub account.

A leaked access token works for up to an hour. A leaked refresh token works until it expires or the operator
revokes the client.

A public route under `/.well-known`, `/oauth` or `/mcp` loses to `mcp`'s with no error. `mcp` mounts after
`public`, and hanami-router keeps the last fixed route it sees for a path.

We follow the SDK's releases, and the MCP spec as the SDK tracks it.

A leaked token holding `publish` can publish and send, and since #551 `write` alone cannot. A published post or a
sent social post cannot be called back, so the hour an access token lasts is long enough to do lasting harm. A
client that names no scope gets `read` alone, and that alone reads the journal, private commits and contact messages.

Every admin operation needs a tool, and the tool list grows with the admin. A spec fails when an operation or an
activity kind lands with no tool, and a job or internal left without one goes on its exempt list with a reason.

Since #153 the rule asks for a tool and an endpoint, for each resource once it moves to the API
([ADR 0086][0086]).

Three tables sit in a presentation slice, so a reader after every table in the site has to open `slices/mcp` as
well as the feature slices. Beyond those three, the presentation slices hold only `admin`'s `session_validity` and
`owner_identities` and `api`'s `api_tokens` (#941).

[0086]: 0086-serve-a-json-api-behind-long-lived-tokens-minted-in-the-admin.md
[0114]: 0114-grant-publishing-and-deleting-as-scopes-of-their-own.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
