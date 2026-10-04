---
id: "0109"
title: Let Cloudflare keep a published photo for one day
status: active
created: 2026-10-04
area: [public]
issue: "#468"
tags: [media, photos, cache, cloudflare, cache-control, privacy, public]
---

# ADR 0109: Let Cloudflare keep a published photo for one day

![Active][status]

## Context

[ADR 0080][0080] serves a photo a published post claims with `public, max-age=31536000, immutable`. The first
Cloudflare rule in [ADR 0090][0090] honours that header, so the edge keeps the photo for a year.

A photo stops being public when no published post claims it any more: the owner takes it out of the post, takes the
post down, or deletes it, and [ADR 0082][0082] releases the claim or deletes the photo. The site then answers the
photo's URL with an empty 404. Cloudflare does not ask. It keeps serving its copy until the year runs out, so taking
a photo down for privacy does nothing a visitor can see.

## Decision

A published photo's `Cache-Control` adds `s-maxage=86400`:
`public, max-age=31536000, s-maxage=86400, immutable`. `Public::Actions::Media::Show` sends it as
`CACHE_PUBLISHED`. A shared cache reads `s-maxage` ahead of `max-age`, so Cloudflare keeps the photo for a day and
then fetches it again. A photo taken down drops off the edge within a day. A browser still keeps its copy for a
year.

## Alternatives

**Purge the photo from Cloudflare when its last claim goes.** It would clear the edge at once. It needs a Cloudflare
API token, a client and a job, as the purge [ADR 0090][0090] turned down for pages does, and a purge that fails
leaves the photo up for a year with no one told.

## Consequences

A photo taken down stays on the edge for up to a day, and in the browser of anyone who already saw it for up to a
year. The site cannot reach either copy.

Each edge fetches each published photo once a day instead of once a year. Every fetch holds a Puma thread while the
store sends the photo, the cost [ADR 0080][0080] names, so a post full of photos costs the Pi a little more each
day.

[0080]: 0080-store-photos-in-an-s3-store-and-serve-them-through-the-site.md
[0082]: 0082-tie-a-photo-to-the-records-whose-markdown-points-to-it.md
[0090]: 0090-let-cloudflare-keep-anonymous-public-pages-for-five-minutes.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
