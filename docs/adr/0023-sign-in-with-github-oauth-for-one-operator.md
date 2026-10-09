---
id: "0023"
title: Sign in with GitHub OAuth for one operator
status: superseded
created: 2026-09-28
area: [admin, lib, db]
superseded-by: "0131"
issue: AA-628
amended: ["#792"]
tags: [auth, oauth, github, sessions, cookies, sign-out]
---

# ADR 0023: Sign in with GitHub OAuth for one operator

![Superseded][status]

## Context

The admin at `/admin` (AA-203) has one user, and nobody else may ever sign in. That one person needs a way to prove
who they are, without accounts for people who will never exist. GitHub is already part of the plan: the commit
import (AA-207) talks to it.

A stateless cookie cannot be taken back. AA-478 saved a session cookie, signed out, sent the saved value again, and
reached the admin for whatever was left of its 30 days. Sign-out is the only lever the operator has once a cookie
gets loose, on a shared laptop, in a backup or through a synced browser profile.

## Decision

We sign in with GitHub OAuth and let in one GitHub account, the one `settings.owner.github_id` names.

- `Admin::Operations::SignIn` checks the numeric GitHub user ID through `Blog::Settings#operator?`, not the login. A
  login can be renamed and someone else can claim the old one. The ID never changes.
- Any other account is turned away before a session exists.
- There is no users table. The sign-in lives in a cookie that `Blog::SessionCookie.store` encrypts, handing
  `app_secret` to rack-session as its `secrets`.
- The cookie is `SameSite=Lax`. GitHub's callback reaches us as a cross-site navigation, and the cookie holding
  `oauth_states` has to come back on it.
- A session lasts 30 days from `signed_in_at` (AA-204). Rack moves the cookie's `expires` forward on each response,
  but `Admin::Auth::Session` counts from sign-in, so the life is fixed.
- After sign-in, the operator lands on the admin URL they first asked for (AA-204).
- Signing out ends every session. `admin` owns one `session_validity` row, `Admin::Operations::EndSessions` moves
  its `valid_after` to now, and `Admin::Auth::Session#signed_in?` refuses a session that began at or before it.
  Only a signed-in operator's sign-out moves the row.

The sign-in lives in `slices/admin`, which ADR 0001 lets own that one table.

## Alternatives

**A bcrypt password hash in settings**, with a session cookie. The simplest to build, but weak without TOTP.

**A passkey (WebAuthn).** The strongest, but it needs a registration flow, a table for credentials and a way back in
when the device is lost.

**A magic link by email.** It can be locked to one address as tightly as GitHub OAuth is locked to one ID. But it
rests on the inbox, needs outgoing mail with a provider and credentials just to sign in, and every sign-in waits on
an email.

**A Redis key for the sign-out instant**, which AA-478 offered since Redis was already set up. Redis here holds only
Sidekiq's queue and schedule, and the row sits in the database every admin request already reads.

**A store with a row per session.** Sign-out could then end one device and leave the rest. AA-478 asked for sign-out
on one device to end every device, which one instant does.

## Consequences

No mail setup, no credentials table and no password to keep. The GitHub setup serves both sign-in and the commit
import.

While GitHub is down, nobody can sign in. The admin is only as safe as the GitHub account and its own guards, such as
2FA.

Widening access means changing the ID check, and there is no table to add a second user to. That is on purpose.

Signing out anywhere signs out everywhere. A sign-in in the same second as the last sign-out counts as the older one
and is refused, since the cookie keeps whole seconds.

A cookie stolen after the last sign-out works for up to 30 days, until the next sign-out ends it.

Every `signed_in?` check reads the row, once per request.

Rotating `app_secret` signs every session out, since no cookie decrypts under the new one.

The MCP server (ADR 0056) builds its consent screen on this sign-in, so it inherits every cost above.

[status]: https://img.shields.io/badge/0131-black?style=for-the-badge&label=Superseded&labelColor=orange
