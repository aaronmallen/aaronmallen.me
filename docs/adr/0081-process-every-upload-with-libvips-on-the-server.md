---
id: "0081"
title: Process every upload with libvips on the server
status: active
created: 2026-09-30
area: [admin]
issue: "#133"
tags: [media, photos, uploads, libvips, libheif, heic, metadata, privacy, gps]
---

# ADR 0081: Process every upload with libvips on the server

![Active][status]

## Context

Issue #128 lets the writer drop a photo into any Markdown editor in the admin. Photos from a phone carry GPS
coordinates, so posting one straight from the camera roll can publish a home address. They also carry a rotation
tag, come as HEIC from an iPhone, and run to sizes no page needs.

Whatever cleans a photo has to run on every upload, including one that skips the editor and posts to the endpoint
directly.

## Decision

The upload endpoint passes every photo through libvips on the server before it reaches the store. libvips rotates
it upright from its rotation tag, strips all of its metadata, shrinks it so its long edge is at most 2560px, and
turns HEIC into JPEG. libvips reads HEIC through libheif.

Before libvips sees a file, the endpoint enforces the limits:

- It refuses a file over 20 MB.
- It judges the type by the file's bytes, not its name or the type the browser sent.
- It takes JPEG, PNG, WebP, GIF and HEIC, and refuses SVG and everything else.

The photo is stored under a random name. No step after this one sees the original file.

libvips and libheif join the system libraries the site needs: on the Pi (ADR 0006), on every dev machine and in CI.

## Alternatives

**Re-encode on a canvas in the browser.** Drawing the photo to a canvas and saving it drops the metadata and can
resize it, with no new library on the server. It lost because a request sent straight to the endpoint skips the
browser, so a photo with its GPS data could still land in the store. Only Safari decodes HEIC, so the other
browsers could not read an iPhone photo at all.

**Strip metadata in pure Ruby.** Removing the EXIF block needs no system library. It lost because it does nothing
else: no rotation, no resize, no HEIC.

## Consequences

No photo reaches the store, and so no page, with its location or any other metadata on it. A file that only looks
like a photo, or an SVG with scripts in it, never gets that far.

The site now needs two system libraries that mise does not manage (ADR 0005). The Pi, each dev machine and CI each
install them through their own package manager, and the versions can drift between them. A Pi that lacks them
cannot process uploads, and the setup notes have to say how to install them.

The Pi does the work. Each upload holds a web thread while libvips decodes and encodes the photo, and a large photo
costs the Pi far more time and memory than a page does.

Stripping all metadata takes the color profile and the camera details with it, and a JPEG or WebP loses a
little quality to the second encode. The original file is gone, so a later change to these limits applies only to
new uploads.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
