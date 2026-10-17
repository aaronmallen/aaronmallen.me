---
id: "0184"
title: Turn maintenance mode off from a signed owner cookie, and keep the admin blocked
status: active
created: 2026-10-17
area: [config, lib, admin]
issue: "#1728"
tags: [maintenance, flag-file, cookies, auth, csrf, app-secret, settings, pi]
---

# ADR 0184: Turn maintenance mode off from a signed owner cookie, and keep the admin blocked

![Active][status]

## Context

[ADR 0181][0181] holds maintenance mode in a flag file on the Pi, and `Blog::Maintenance` answers 503 for every
request while the file exists, ahead of `Hanami.app` and without touching the NAS. Spec #1720 lets me turn the mode
on from the admin and off from the browser, with no SSH.

Turning it on is easy, since the admin still works until the file exists. Turning it off is not. While the mode is
on, the admin sits behind the 503, and its sign-in reads Postgres, which may be down for the update the mode
covers. Whatever proves I am the owner has to work with every NAS store gone, so it cannot rest on the session.

## Decision

**When the admin turns the mode on, it sets a signed owner cookie, and that cookie alone can turn the mode off.**

- The admin action writes the flag file, then sets the cookie: `HttpOnly`, `SameSite=Strict`, for the whole site.
  The web process now writes the flag as well as reading it.
- The cookie holds the time it was issued and an HMAC of that time, keyed by `app_secret` under a purpose string of
  its own, the way `Public::Operations::IssueContactStamp` signs the contact stamp ([ADR 0043][0043]). A different
  purpose keeps one signature from passing for the other.
- `Blog::Maintenance` checks the cookie with nothing but `app_secret` and the file. A cookie with a bad signature,
  or issued before the current flag file was written, counts as missing. A cookie from an earlier window cannot end
  this one, and a window the Pi script opened has no cookie at all.
- With a valid cookie, the maintenance page adds a Deactivate button. The middleware takes its POST itself: it
  removes the flag file, clears the cookie and redirects to Settings. Without a valid cookie the page and the JSON
  503 stay as they are, and the POST changes nothing.
- The cookie opens nothing else. While the mode is on, its holder sees only the maintenance page with the button,
  never the admin.

The app's CSRF check never runs in front of the app, so the signature and `SameSite=Strict` guard the deactivate
request on their own.

The Pi script still creates and removes the file, for a cleared browser or another device.

## Alternatives

**Exempt `/admin` from the middleware.** The admin reads Postgres for sign-in and for every page, so it fails while
the NAS is down, the case the mode exists for.

**Exempt a small toggle route in the app.** It still runs behind Hanami's session and sign-in, which need the stores
the mode covers. Moving the check into the middleware does the same job with less in its path.

**Leave the admin blocked, with SSH the only way off.** It is what we had, and the spec exists to end it.

## Consequences

I can end maintenance from the browser that started it, with Postgres, Redis and RustFS all down.

The web unit on the Pi needs write access to the shared folder that holds the flag, so a bug in the web process can
now take the site down, not only the script.

Anyone holding `app_secret` can forge the cookie. Rotating it voids every cookie it signed, which costs nothing
worse than falling back to the script.

The cookie lives in one browser. Clearing it, or switching device, leaves the script as the only way off.

The public site, which [ADR 0024][0024] keeps free of cookies, now carries one, set only for the owner and only by
the admin.

[0024]: 0024-mount-the-session-cookie-in-admin-and-mcp-alone-and-let-public-read-it-by-hand.md
[0043]: 0043-guard-the-contact-form-with-a-honeypot-and-a-daily-hash-not-a-cookie.md
[0181]: 0181-hold-maintenance-mode-in-a-flag-file-on-the-pi.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
