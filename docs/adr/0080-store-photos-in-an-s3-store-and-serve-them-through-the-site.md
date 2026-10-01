---
id: "0080"
title: Store photos in an S3 store and serve them through the site
status: active
created: 2026-09-30
area: [config, media, public]
issue: "#132"
amended: ["#137"]
tags: [media, photos, uploads, s3, rustfs, nas, providers, cloudflare, tunnel, puma]
---

# ADR 0080: Store photos in an S3 store and serve them through the site

![Active][status]

## Context

No part of the site takes a file. A photo in a post means hosting it somewhere else and pasting a link, so it has
no backup and the link can rot. #128 adds uploads to the Markdown editor, and the bytes need a home.

Photos are the one kind of data here nobody can rebuild. A lost database comes back from GitHub and the social
networks, a lost photo does not. So photos belong where the backups are, and under [ADR 0006][0006] that is the
NAS, not the Pi.

The site runs behind a Cloudflare Tunnel so that nothing at home accepts a connection from outside. Whatever holds
the photos has to keep that true.

The RFC in #7 weighed where photos live and settled on an S3 server on the NAS. RustFS runs there today, on a
single disk the NAS snapshots cover, with no public route.

## Decision

We store photos in any S3-compatible store named in settings and serve them through the site.

- A new `media` feature slice owns photos: their table and the store client. The client is a provider in the
  pattern of [ADR 0009][0009]. It reads the endpoint, region, bucket, access key, secret key and path style from
  settings, and with none of them it answers `configured?` false and the editor hides uploads.
- The site talks to the store only through the S3 API, so RustFS on the NAS, Garage, R2 or AWS differ by settings
  alone.
- The `public` slice answers `GET /media/<key>`, since a feature slice answers no route ([ADR 0001][0001]). It
  fetches the photo from the store over the LAN and streams it back with a one-year `immutable` cache header.
  Cloudflare then serves repeat requests from its own cache.
- A photo the store does not have, or a store that does not answer, gives an empty 404.

## Alternatives

**The Pi's own disk.** It is empty, fast and needs no new service. It is also the one disk in the setup with no
backup, and photos are the data we can least afford to lose.

**An NFS or SMB share mounted on the Pi.** No new service, and the app writes plain files. It ties the code to a
filesystem rather than an API, and a mount that is down at boot turns an upload into a confusing error.

**`bytea` in Postgres.** One backup covers everything. It swells the database, and every photo passes through the
connection pool that [ADR 0006][0006] budgets with care.

**Exposing the store, or redirecting to a signed URL on it.** Either saves the Pi a hop, but puts an object store at
home on the public internet, which the tunnel exists to prevent. Cloudflare's cache already absorbs most of the hop.

## Consequences

Moving photos off the NAS takes new settings and a copy of the bucket, not new code.

The NAS runs one more service, with its own key, version pin and updates. RustFS keeps objects in its own format, so
a restore means rolling back the snapshot and running RustFS on it, not copying files out.

Each cache miss holds a Puma thread for as long as the store takes to send the photo, and the web process has five
at the defaults. Cloudflare misses about once per photo per edge, so this stays rare, but a slow store or a page of
fresh photos can tie up threads that pages need.

A store that is down costs the photos and nothing else. The site still serves every page.

The site depends on an S3 client. If it is the AWS SDK, its newer checksum headers break some S3-compatible stores,
so the client has to send them only when the request needs them.

[0001]: 0001-split-the-app-into-slices-by-feature.md
[0006]: 0006-run-the-site-on-a-raspberry-pi-behind-a-cloudflare-tunnel-with-its-data-on-the-nas.md
[0009]: 0009-register-every-service-client-with-or-without-its-credentials.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
