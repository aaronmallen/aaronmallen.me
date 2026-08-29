---
id: "0014"
title: Build every absolute URL from the site setting
status: active
created: 2026-09-28
area: [admin, config, lib, mcp, posts, public, social]
issue: AA-655
amended: [AA-819]
tags: [urls, settings, routes, base-url, feeds, webmentions, oauth, tunnel]
---

# ADR 0014: Build every absolute URL from the site setting

![Active][status]

## Context

The site hands out URLs for somebody else to fetch later: feed entry ids, the canonical link and Open Graph tags,
the link in a post's announcement, the source of a webmention, the MCP issuer and its OAuth endpoints, and the
GitHub sign-in callback. A reader, a remote site or an MCP client keeps each one and comes back to it.

The site runs on the Pi behind a Cloudflare Tunnel, so one page can arrive on the public host, a tunnel host, the
Pi's LAN address or `localhost`. The `Host` header is whatever the caller sent, and Rack 3.2 takes
`X-Forwarded-Host` as the host too.

AA-391 found the feed, webmentions and announcements building from `request.base_url` while the canonical link
read the setting. On one host the two agree. Off it, a feed entry id moves and the post shows up unread again, a
webmention source names a LAN address the receiving site cannot fetch, and an announcement posts a link nobody
outside can follow. AA-480 found worse in the MCP discovery document: a request with
`X-Forwarded-Host: evil.example` got an issuer and all three OAuth endpoints on `evil.example`, so a client would
run the whole sign-in against a host somebody else chose.

## Decision

`settings.site.url` is the one answer to "what is this site's address". The request never answers it.

- `config/app.rb` sets `config.base_url` from `settings.site[:url]`, so Hanami's `routes.url` and phlex-hanami's
  `url` build on the setting. A caller that needs an absolute URL for a route calls `routes.url`, as
  `Posts::Operations::ComposeAnnouncement`, `Social::Operations::SendWebmentions`,
  `Public::Operations::RenderAtomFeed`, the feed actions, `Admin::Action#github_callback_url` and
  `MCP::OAuth::Metadata` do.
- `Blog::Site` reads the same base back from `Hanami.app.config.base_url` for what is not a route: the canonical
  link in `Public::UI::Layouts::Application`, the MCP issuer in `MCP::Action#issuer`, and the origin
  `Public::Action#cross_site?` checks an `Origin` header against.
- A question about identity asks the setting too. `Blog::Settings#owns?` decides whether a webmention's target
  is ours, and it accepts the setting's host alone. `Blog::Providers::HTTPProvider` names the setting in the
  User-Agent of every outbound request.

The rule stops where the question is about the connection rather than the site. `Public::Actions::Visits::Create`
still hands `request.base_url` to `Analytics::Operations::RecordVisit`, which drops a referrer on the asking host
so a click inside the site counts as direct. The `Referer` header names the host the browser is on, so the asking
host is the right thing to compare, and the URL never leaves the request. AA-391 left it on the request for that
reason, and AA-403 kept it there.

## Alternatives

**Build from the request host.** It needs no setting and names whatever host a browser or client used. It lets
the caller pick the site's name, which is how the feed ids moved in AA-391 and the discovery document pointed at
`evil.example` in AA-480. AA-391 left the MCP issuer and the GitHub callback on the request, arguing the issuer
must match the address the client dialled and the callback must return the browser to the host it left. AA-480
turned the first down, since a header could then choose the issuer, and by then the callback already built on the
setting.

**Join each URL by hand beside Hanami's builder.** AA-391 and AA-480 first built each URL as
`Blog::Site.url(routes.path(...))` through `Blog::Action#absolute_url`, and left `config.base_url` unset, which
kept the URL in settings rather than app config. Hanami then kept its default base, so `routes.url` answered
`http://0.0.0.0:2300`, and the OAuth metadata spelled three route paths as constants on `MCP::Slice` that could
drift from `slices/mcp/config/routes.rb`. AA-713 set `config.base_url` from the setting and removed the hand
joins, so the setting still holds the address and Hanami's builder agrees with it.

## Consequences

The feed, the canonical link, an announcement, a webmention source and the OAuth metadata name the same host for
the same page however the request arrived. `spec/slices/public/requests/feeds_spec.rb` and `webmentions_spec.rb`
send another `HTTP_HOST`, and `spec/slices/mcp/requests/metadata_spec.rb` sends `X-Forwarded-Host`, and each
expects the setting's host.

The app will not boot without the setting. `config/settings.rb` requires `site.url` to be an absolute `http` or
`https` URL with no path (AA-624), and `config.base_url` reads it while the app class loads.

A webmention that names the site by its tunnel or LAN address is refused as a foreign target. A real sender
arrives on the public host, so this costs nothing yet.

`config/settings/test.yml` carries the production URL, `https://aaronmallen.me`, so specs assert the links the
live site gives out, as the public request specs do when they read a page's canonical link. The cost is that a
test run cannot tell its links from production's, and a spec that needs another host has to stub
`Blog::Site.base_url`. Development sets `http://localhost:2300`, so a link built there works on the machine that
built it.

The analytics referrer check is the one place the asking host still counts. A new caller that reads
`request.base_url` has to show the same reason, or build on the setting.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
