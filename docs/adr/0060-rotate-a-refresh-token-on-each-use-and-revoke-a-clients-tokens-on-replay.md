---
id: "0060"
title: Rotate a refresh token on each use and revoke a client's tokens on replay
status: active
created: 2026-09-28
area: [mcp]
issue: AA-673
tags: [mcp, oauth, tokens, refresh, replay, rotation, postgres]
---

# ADR 0060: Rotate a refresh token on each use and revoke a client's tokens on replay

![Active][status]

## Context

The MCP token endpoint takes two grants: an authorization code and a refresh token. Every MCP client is public:
`lib/mcp/oauth/metadata.rb` offers `none` as the only way to authenticate at the token endpoint. So whoever holds
a refresh token can spend it, a code needs only its PKCE verifier beside it, and a stolen one looks the same as
the real one.

RFC 6749 section 4.1.2 says a server should revoke what a reused code bought, and the OAuth 2.1 draft rotates
refresh tokens for public clients. The former ADR 0056 said a leaked refresh token works until it expires or the
operator revokes the client.

Two races showed that checking a row and then writing it is not enough. AA-473 found that two requests carrying one
code could both read it as unused and both get a token pair, so the replay check never ran. AA-521 then found the
losing request could sweep the client's tokens before the winner's pair was committed, so that pair stayed live.

## Decision

`MCP::Operations::IssueToken` holds two rules.

- **A refresh token works once.** Spending it revokes it and issues a new pair, and `MCP::Operations::IssueTokens`
  gives the new refresh token a fresh 30 days.
- **A spent code or refresh token that comes back revokes the client.** `replay` calls
  `token_repo.revoke_for_client`, which revokes every live token the client holds, then refuses with
  `invalid_grant`.

One statement spends the row and says who spent it. `burn` in `slices/mcp/relations/oauth_codes.rb` and
`slices/mcp/relations/oauth_tokens.rb` updates only an unspent row and returns it through `RETURNING`, so the
request that gets a row back won and a request that gets nothing back is a replay (AA-473). `settle` grants inside
the transaction that burned the row, so a racing request waits on that row until the winner's pair is committed,
and its sweep then revokes that pair too (AA-521).

## Alternatives

**Refuse a replay and revoke nothing.** A client that posts twice by mistake would keep its tokens. It lost
because a reused code means someone else may hold what it bought, and AA-521 asked that a stolen code leave no
usable token behind.

**One refresh token that never rotates**, good for its 30 days. The client keeps one secret. A leaked one then
works beside the real client for up to 30 days, and nothing on the server can tell them apart. With rotation the
thief and the client hold one token between them, so whichever refreshes second makes a replay, which cuts off
both.

## Consequences

A client that posts the same code or refresh token twice, say by retrying after a timeout, loses every token. The
operator then has to approve it again through authorize.

A client that keeps refreshing never runs out, since each rotation starts a new 30 days. The 30 days bound only how
long a client may go quiet.

A leaked refresh token works only until the real client next refreshes. Once both have spent it, every token the
client holds is revoked.

A replay is caught only while the spent row exists. `MCP::Operations::ReapExpiredCredentials` deletes codes and
tokens once they expire, and a spent row that has gone reads as unknown, which refuses without revoking.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
