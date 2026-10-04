---
id: "0111"
title: Send Strict-Transport-Security from the app, for the apex alone
status: active
created: 2026-10-04
area: [config, lib]
issue: "#471"
tags: [security, https, hsts, cloudflare, headers, middleware]
---

# ADR 0111: Send Strict-Transport-Security from the app, for the apex alone

![Active][status]

## Context

The site sent no `Strict-Transport-Security` header, so a browser that typed the bare name made its first request
over plain HTTP, where anyone on the path could read or change it. [ADR 0006][0006] puts the site behind a Cloudflare
Tunnel, and Cloudflare ends TLS, so either Cloudflare or the app could send the header.

The header has to reach every response, error pages too. Hanami renders a 404 or a 500 in `RenderErrors`, which sits
outside the middleware `config/app.rb` adds, so a header set there misses those pages.

## Decision

The app sends `Strict-Transport-Security: max-age=31536000` on every response in production. A browser then keeps
to HTTPS for a year.

`Blog::StrictTransport` in `lib/blog/strict_transport.rb` sets the header. `.config/config.ru` wraps `Hanami.app` in
it when `Hanami.env?(:production)`, so it sits outside the whole app, error pages included. Development and test
send no header, since they run over plain HTTP on localhost.

The header leaves out `includeSubDomains` and `preload`. The app answers for the apex and nothing else, and it
cannot vouch that every subdomain the owner sets up serves HTTPS.

## Alternatives

**Cloudflare's HSTS setting.** It needs no code, but it lives in a dashboard no commit records, and a spec cannot
check it.

**Middleware in `config/app.rb`, or Hanami's default action headers.** Both sit inside `RenderErrors`, so a 404 or
a 500 would go out without the header.

## Consequences

Once a browser sees the header, it refuses plain HTTP to the apex for a year. If the site ever has to serve over
HTTP again, browsers that visited stay locked out until `max-age` runs out, and lowering it only reaches a browser
on its next HTTPS visit.

Subdomains get no cover from the header, so a first visit to one can still go over plain HTTP. Adding
`includeSubDomains` later takes a new record, and so does a place on the browsers' preload list.

The spec reads `.config/config.ru` to build the app, since the header lives outside `Hanami.app`. Any other way to
start the site has to use that file or lose the header.

[0006]: 0006-run-the-site-on-a-raspberry-pi-behind-a-cloudflare-tunnel-with-its-data-on-the-nas.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
