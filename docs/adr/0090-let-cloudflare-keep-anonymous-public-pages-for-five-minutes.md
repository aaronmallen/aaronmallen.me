---
id: "0090"
title: Let Cloudflare keep anonymous public pages for five minutes
status: active
created: 2026-10-01
area: [config, public]
issue: "#235"
amended: ["#376", "#468"]
tags: [cache, cloudflare, cache-control, cookies, sessions, theme, deploy, public]
---

# ADR 0090: Let Cloudflare keep anonymous public pages for five minutes

![Active][status]

## Context

The Pi renders every public page itself. The Hanami post drew about 6,400 views over two days, and all of its
15,000 or so requests reached Puma, since public pages sent no `Cache-Control` and Cloudflare answered
`cf-cache-status: DYNAMIC`. The Pi coped, but a bigger wave lands on five Puma threads.

A public page is not the same for every reader. The signed-in owner sees the admin items and gets
`private, no-store`, as [ADR 0024][0024] says, and a visitor who picked a theme gets it written into the page, as
[ADR 0032][0032] says. Public pages send `Vary: Cookie` for both, but Cloudflare does not key HTML on `Vary`, so a
page it keeps goes to every reader whatever cookie they send. Analytics count a view when the page posts to
`/pulse`, not when the server renders it.

## Decision

The server marks a page shared, and a Cloudflare cache rule keeps only what the server marks.

`Public::Action.share_with_caches` adds an after callback that sends `public, max-age=0, s-maxage=300`. It sends it
only on a 200, only when nothing set `Cache-Control` first, and only when the request carries neither the
`admin.session` nor the `site_theme` cookie. A shared page is then always the page a reader with no cookie gets.
The home page, about, projects, the post index, a post and a tag page call it. A halt, such as a 404, skips after
callbacks, and so does an error, so neither is ever marked shared. A redirect is not a 200. The contact page sends
`private, no-store` itself. The feeds keep their own `ETag` and `Last-Modified` and do not call it. #376 has them send
`private, no-cache`, so Cloudflare never keeps a feed and every fetch reaches the server to be counted, as
[ADR 0106][0106] says.

`s-maxage=300` lets Cloudflare keep a page for five minutes. `max-age=0` makes a browser ask again each time, so a
reader who signs in or picks a theme never sees a stale copy from their own browser cache.

### The Cloudflare rules

The rules live in the dashboard, under Caching, then Cache Rules, on the site's zone. Set them up in this order,
since a later rule wins.

- **Cache public pages**, first. Match the site's host and the methods `GET` and `HEAD`:
  `(http.host eq "<site host>" and http.request.method in {"GET" "HEAD"})`. Set the cache to eligible. Set the
  edge TTL to "Use cache-control header if present, bypass cache if not". Set the browser TTL to "Respect
  origin". Leave the cache key as it is.
- **Skip the cache for a personal page**, second. Match a request that carries either cookie:
  `(http.cookie contains "admin.session" or http.cookie contains "site_theme")`. Set the cache to bypass.

The first rule needs no list of paths. A page that sends no `Cache-Control`, or sends `private, no-store`, is never
stored, so the admin, the API, MCP and the contact page stay out. The second rule keeps a stored page from a reader
whose copy would differ, and makes Cloudflare answer `BYPASS` for them.

To check it, request a post twice with no cookie. The second answer carries `cf-cache-status: HIT`. The same
request with `Cookie: admin.session=x` answers `BYPASS`.

## Alternatives

**Purge the page from Cloudflare when a post changes.** A long lifetime with a purge on publish and edit would
spare the Pi more requests. It needs a Cloudflare API token, a client and a job, and a purge that fails leaves a
stale page up with no end. Five minutes of a stale page costs less.

**Key the cache on the theme cookie.** Cloudflare can add a cookie to the cache key only on the Enterprise plan.
Readers who picked a theme are few, so they skip the cache.

**Mark every public page shared in `set_cache_policy`.** One before callback would cover every page, but it would
also mark a 404 and the contact page, and every new page would be shared until someone thought to stop it. Each
page opts in instead.

## Consequences

An edit to a published post, a new post or a moderated webmention takes up to five minutes to reach a reader who
has no cookie. Edge locations each keep their own copy, so two readers can see different versions inside that
window.

The rules live outside the repo. Rebuilding the zone means setting them up by hand from this record, and the code
cannot tell when they are missing: pages then answer `DYNAMIC` again and the Pi renders them all.

A reader with a forged or stale session cookie, or any `site_theme` cookie, always reaches the Pi.

Anything new that changes a public page per reader must either set `Cache-Control` before the after callback runs
or add its cookie to `Public::Action::PERSONAL_COOKIES` and to the second rule. Missing either one serves one
reader's page to everyone.

The first rule also makes photos eligible, so Cloudflare keeps a missing photo for 60 seconds. #468 has a published
photo send `s-maxage=86400`, so Cloudflare keeps it for a day, not the year its `max-age` asks of a browser
([ADR 0109][0109]).

[0024]: 0024-mount-the-session-cookie-in-admin-and-mcp-alone-and-let-public-read-it-by-hand.md
[0032]: 0032-keep-the-theme-in-a-site-theme-cookie-the-browser-sets-and-draw-it-with-light-dark.md
[0106]: 0106-count-feed-fetches-on-the-server-and-capture-outbound-clicks-from-the-beacon.md
[0109]: 0109-let-cloudflare-keep-a-published-photo-for-one-day.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
