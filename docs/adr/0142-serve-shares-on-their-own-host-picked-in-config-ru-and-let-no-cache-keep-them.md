---
id: "0142"
title: Serve shares on their own host, picked in config.ru, and let no cache keep them
status: active
created: 2026-10-10
area:
  - config
issue: "#1055"
amended:
  - "#1259"
  - "#1384"
  - "#1775"
  - "#1825"
tags:
  - shares
  - short-links
  - hosts
  - routing
  - rack
  - settings
  - cache
  - cloudflare
  - cache-control
  - puma
  - aa-cool
---

# ADR 0142: Serve shares on their own host, picked in config.ru, and let no cache keep them

![Active][status]

## Context

The spec in #1053 hands out files by short link, such as `https://aa.cool/k7mq2`. `aa.cool` serves shares and the
short links of #1064, and nothing else: every blog or admin path, an unknown code and a deleted share answer 404
there. [ADR 0141][0141] keeps shares in a shares slice with their own bucket.

Every slice mounts by path in `config/routes.rb`, and nothing routes by host. The public slice and MCP both
mount at `/`, so a share slice mounted beside them would answer `aa.cool/posts` with a post, and the blog's host would
answer share codes.

[ADR 0014][0014] builds every absolute URL from `settings.site.url` and never from the request. The share host is a
second origin, and the same rule has to hold for it.

Each share counts its downloads, and the owner wants a deleted or renamed link to stop working at once. A cache in
front of the site breaks both: a hit never reaches the app to be counted, and a kept copy outlives the share. Photos
take the other side of that trade. [ADR 0109][0109] lets Cloudflare keep a published photo for a day, and the first
rule in [ADR 0090][0090] makes anything that asks for it eligible.

## Decision

We serve shares on a host of their own and pick the app by host in `.config/config.ru`, ahead of `Hanami.app`.

- A new setting holds the share host. Production sets `aa.cool`, and development and test set a local host, so the
  split works on the machine running it.
- A request for the share host goes to the shares app. Every other request goes to the blog as it does today, so
  `config/routes.rb` and the slices mounted in it never see a share host request.
- The shares app answers a code from `short_codes` and nothing else. Every other path answers 404. #1259 adds a
  share group's file and zip paths under its code ([ADR 0163][0163]).
- A share link names the setting's host, never the host a request arrived on, as [ADR 0014][0014] says for the site.

No cache keeps a share, a short link redirect or a 404 on the share host. Each of them sends `Cache-Control:
private, no-store`, so Cloudflare, under the rules of [ADR 0090][0090] or any rule added later, never stores one, and
neither does a browser. Every request reaches the app.

## Alternatives

**Mount shares by path in `config/routes.rb`.** It keeps one routing table, but a path mount answers on every host.
The blog's paths would answer on `aa.cool`, and codes would need a prefix such as `/s/` to keep clear of the blog's
own paths, which makes the link longer.

**Let Cloudflare keep a share for a day, as [ADR 0109][0109] does for photos.** It would spare the Pi most of the
bytes. The download count would then miss every hit, and a deleted or renamed link would keep working for up to a
day. The owner chose no edge cache in #1053.

## Consequences

Download counts stay exact, and a share dies the moment the owner deletes it or changes its code.

Every download holds one of the five Puma threads at the defaults for the whole transfer, the cost [ADR
0080][0080] names for a photo cache miss, now paid on every request. A large file that spreads widely, or a video
that seeks with many range requests, could tie up the threads that blog pages need, so #1384 caps them. The
`share_site.transfers` setting, which `SHARE_TRANSFERS` sets, caps the downloads, range requests and zips each worker
streams at once. Unset, it leaves two threads free, so three at the defaults. Past the cap the share host answers
`503` with `Retry-After` at once rather than wait for a thread. A share group's page and a short link's redirect stay
outside the cap. Since #1775 an image's preview does too: an upload stores a copy no wider or taller than 1280px
beside the original, and `?preview` reads that copy whole and sends it with no slot taken. It counts no download and
carries `no-store` like the rest, so deleting the share or its group stops it at once. A one-time backfill (#1849)
stores the copy for images uploaded before #1775. An image libvips cannot read has no copy, and its preview streams
the original under the cap as before.

`.config/config.ru` holds routing for the first time. A spec has to build the app from that file to reach the share
host, as the strict transport spec does under [ADR 0111][0111], and any other way to start the site has to use it or
lose the share host.

The share host needs its own Cloudflare zone and a tunnel hostname rule that points at the same service. Both live
outside the repo, so #1061 writes them down.

[0014]: 0014-build-every-absolute-url-from-the-site-setting.md
[0080]: 0080-store-photos-in-an-s3-store-and-serve-them-through-the-site.md
[0090]: 0090-let-cloudflare-keep-anonymous-public-pages-for-five-minutes.md
[0109]: 0109-let-cloudflare-keep-a-published-photo-for-one-day.md
[0111]: 0111-send-strict-transport-security-from-the-app-for-the-apex-alone.md
[0141]: 0141-keep-file-shares-in-a-shares-slice-with-their-own-bucket.md
[0163]: 0163-serve-a-share-groups-page-files-and-streamed-zip-under-its-code-on-the-share-host.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
