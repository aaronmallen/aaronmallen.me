---
id: "0059"
title: Gate an MCP client on the operator's consent, not on registration
status: active
created: 2026-09-28
area: [db, mcp, admin]
issue: AA-670
amended: ["#176", "#463", "#465"]
tags: [mcp, oauth, consent, registration, clients, revoke]
---

# ADR 0059: Gate an MCP client on the operator's consent, not on registration

![Active][status]

## Context

Claude's connectors find the server and register with it on their own, so that connecting needs nothing but the URL
(AA-263). `POST /oauth/register` takes no token and hands out no secret, so a registered client proves nothing:
anyone can register one, call it `Claude`, and point it at a redirect URI they hold.

AA-276 found what that meant for authorize. `GET /oauth/authorize` issued a code as soon as it saw a signed-in admin
session, and the session cookie is SameSite=Lax. A crafted link opened while signed in minted a code for a client
someone else registered, and they held the PKCE verifier. Nothing else stood between that link and a working token.

## Decision

Anyone may register a client, and the operator approves every connection. The rule lands in `slices/mcp`, and the
admin's clients page follows it.

- `MCP::Operations::RegisterClient` registers a public client with no secret. It sets `grant_types`,
  `response_types` and `token_endpoint_auth_method` itself from `MCP::OAuth::Metadata`, and
  `MCP::Contracts::ClientRegistrationContract` takes only redirect URIs, a name and two URIs from the client.
- `MCP::Operations::Authorize` renders the consent page unless the request carries approve or cancel. The page
  names the client, what each scope grants and where the answer goes. Approve is a guarded POST, cancel sends
  `access_denied`, and a plain GET never mints a code.
- Nothing remembers a grant. A client that reconnects meets the page again.
- `MCP::Operations::RevokeClient` deletes the client's codes and tokens and keeps its row, so it can sign in again
  (AA-269). Nothing marks a client revoked, and `oauth_clients` has no `revoked_at`.
- `queries.connected_clients` lists only clients holding an unexpired, unrevoked token (AA-693), so a revoked client
  leaves the admin page and a registration that never connected never shows.

## Alternatives

**A code with no page**, as authorize worked before AA-276. It saves a click, and it lets a link the operator did not
start mint a code for a client someone else holds.

**A remembered grant per client**, so a client approved once connects again with no page. It breaks AA-276's rule
that a plain GET never mints a code, and a client ID is public and carries no secret.

**A registration token**, so only a client holding one may register. A connector would need the token before it
could register, and AA-263 asked that connecting need nothing but the URL.

**A revoked client marked by `revoked_at`**, so revoke shuts it out for good. AA-269 asked that revoke cut a client
off until it signs in again, not ban it. A mark would stop little anyway: registration is open, so the same app can
register a new client.

## Consequences

The operator clicks Approve on every connect and every reconnect, after a revoke and after a refresh token lapses.

The consent page is the only gate, so the operator has to read it. A client names itself, so the name proves
nothing. The redirect URI the page shows is where the code goes, and the clients page puts its host beside the
name so the operator can tell two clients called `Claude` apart (AA-693). Since #465 the consent page leads with
that host, and shows the name only as the name the client gave itself. A client that has never used a token and
holds no token row gets a notice that it is new, with when it registered, and the `write` grant warns that a post it
publishes or a social post it sends cannot be taken back.

Anyone can grow `oauth_clients`. `POST /oauth/register` answers 429 past `client_registration.throttle_limit`
registrations from one visitor hash in the window, 10 an hour by default (AA-693). Since #463 the hash covers an
IPv6 sender's whole /64, and past `client_registration.total_throttle_limit` registrations from everyone together,
30 an hour by default, it answers 429 whatever the address. The cap is site wide, so a flood locks out the operator's
own connector for up to a window. Registration sends no wildcard CORS origin and answers no preflight, so a web page
cannot make its readers' browsers register clients.

Since #176 `MCP::Operations::ReapExpiredCredentials` deletes a client that holds no live code or token and has not
connected, or registered, in 90 days. Since #463 it deletes a client a day after it registers when it holds no code
or token row and has never connected. A code lasts a minute and the job deletes it once it lapses, so a client that
took a code and never traded it for a token counts as one that took nothing. The job locks each client row before it
deletes, as issuing a token does, so a token issued while the job runs keeps its client.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
