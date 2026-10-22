---
id: "0202"
title: Tell admin browsers apart with a device cookie, and sign each one out on its own
status: active
created: 2026-10-22
area:
  - admin
  - db
  - lib
  - security
issue: "#1905"
tags:
  - auth
  - sessions
  - cookies
  - sign-out
  - devices
  - security
  - sign-in
---

# ADR 0202: Tell admin browsers apart with a device cookie, and sign each one out on its own

![Active][status]

## Context

The security tab lists `sign_ins` a row per event, so one browser that signs in three times shows three times.
Nothing ties a sign-in to the browser that made it. The new-device alert comes from a new `known_devices` row, keyed
on browser, OS, city and country, so my own laptop alerts whenever it signs in from a new city.

[ADR 0023][0023] turned down "a store with a row per session" so that one sign-out ends every session, and [ADR
0131][0131] kept that. `session_validity.valid_after` is that one instant. Spec #1904 wants each browser to show
once, to sign out one browser without the rest, and to stay quiet when a browser it knows signs in from somewhere
new. The Sign out button still ends every device.

[ADR 0024][0024] mounts the session cookie in `admin` and `mcp` alone and keeps public pages free of cookies, as
[ADR 0043][0043] and [ADR 0045][0045] do. [ADR 0184][0184] already gives the owner a second cookie. [ADR
0124][0124] puts access records in the `security` slice.

## Decision

**Each admin browser carries a device cookie holding a random ID, and a `devices` row the `security` slice owns
stands for it.**

- The cookie is `admin.device`: `HttpOnly`, `SameSite=Lax`, `Secure` in production, and scoped to the `/admin`
  path, so no public page receives it. Its settings live beside `Blog::SessionCookie`. `Lax` lets it come back on
  the OAuth callback, which always sits under `/admin`.
- The cookie lives 400 days, the most a browser keeps one, and each sign-in sets it again. A browser that signs in
  once a year stays the same device.
- At sign-in the admin reads the cookie. An ID with a matching row keeps that row. A missing or unknown ID gets a
  fresh random one and a new row, so a browser can never choose its own ID.
- A `devices` row holds the ID, the browser and OS from its last sign-in, its last sign-in time and the time it was
  signed out, if it was. It holds no address and no raw user agent, so it can outlive the 90 day prune ADR 0124
  sets. Each `sign_ins` row names its device when the browser sent one.
- The session cookie holds the device ID beside `signed_in_at`. `Admin::Auth::Session#signed_in?` reads the device
  row on every request and refuses a session that began at or before that device was signed out, or whose device
  is gone. The admin reads the row through a read repo `security` exports, and signs a device out through an
  operation it exports, as [ADR 0123][0123] allows.
- The Sign out button moves `valid_after` as before and leaves the device rows and the cookie alone, so the same
  browser counts as the same device next time.
- A sign-in that carries a known device cookie writes no `known_devices` row, so it raises no new-device alert from
  any city. API tokens and MCP clients carry no cookie and alert as they do now.
- The prune job deletes a device row once its last sign-in is older than 400 days, since no browser can still send
  its cookie.

## Alternatives

**Keep the device ID in the session cookie.** One cookie fewer, but sign-out drops the session, so every browser
would turn new after each sign-out and after 30 days.

**Add a column to `known_devices`.** It is keyed on credential and place, `api` and `mcp` write to it, and it keeps
a row per city. A browser needs one row however far it travels, and a sign-out time no token has.

**A row per session**, the store ADR 0023 turned down. A device row already ends one browser, and `valid_after`
still ends them all in one write.

**Sign the cookie with `app_secret`**, as ADR 0184 signs its own. The ID is random and only counts when a row
matches it, so a signature would guard nothing a guess could reach.

**A 30 day cookie, the length of a session.** A browser that signs in less than once a month would show as new each
time and alert.

## Consequences

Each browser shows once on the tab, and I can end one lost browser and keep the rest.

Every `signed_in?` check reads one more row, beside `session_validity` and `owner_identities`. Public pages call it
too, so the owner's public page views pay for it.

Sessions from before the change hold no device ID, so the deploy signs every browser out once.

Anyone who copies the device cookie and also gets into my GitHub or Google account signs in with no alert. The
alert stops guarding a browser once it has signed in once.

Clearing cookies, a private window or a new browser profile makes a new device and a new alert, and the old row
sits on the tab until it is signed out or pruned.

Device rows outlive the sign-ins they group, and say which browsers I used for up to 400 days after the last one.

[0023]: 0023-sign-in-with-github-oauth-for-one-operator.md
[0024]: 0024-mount-the-session-cookie-in-admin-and-mcp-alone-and-let-public-read-it-by-hand.md
[0043]: 0043-guard-the-contact-form-with-a-honeypot-and-a-daily-hash-not-a-cookie.md
[0045]: 0045-count-visitors-with-a-daily-hash-and-no-cookies.md
[0123]: 0123-export-only-read-repos-and-operations-and-keep-write-repos-in-their-slice.md
[0124]: 0124-keep-the-operators-raw-ip-and-user-agent-for-90-days-in-a-security-slice.md
[0131]: 0131-keep-owner-identities-in-the-database-and-add-the-first-by-hand.md
[0184]: 0184-turn-maintenance-mode-off-from-a-signed-owner-cookie-and-keep-the-admin-blocked.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
