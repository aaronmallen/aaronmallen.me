---
id: "0144"
title: Claim social post photos by row, and send them as native media
status: active
created: 2026-10-10
area: [social, media, admin, db]
issue: "#1071"
tags: [social, mastodon, bluesky, media, photos, uploads, claims, alt-text, sweep]
---

# ADR 0144: Claim social post photos by row, and send them as native media

![Active][status]

## Context

Spec #1065 lets me add photos to each part of a social post, with alt text for each one, and has Mastodon and
Bluesky show them as images, not links.

Under [ADR 0082][0082] a photo belongs to the records whose Markdown points to it: saving a record scans its text for
`/media/<key>` URLs and claims what it finds. A social post part is plain text, not Markdown. A photo URL there would
go out to the networks as a link, the opposite of what the spec asks for, so the text cannot hold the photo.

## Decision

A social post part holds its photos in rows of its own, and claims them through those rows.

- **Upload as any photo.** A photo goes through `upload_photo` into the media slice, like a journal or post photo
  ([ADR 0080][0080], [ADR 0081][0081]).
- **A row ties it to the part.** A table in the social slice ties each photo to a part, with its place in the order
  and its alt text. Alt text lives on that row, not on the photo, since it describes the photo where it is used.
- **Saving claims by row.** Saving a part makes its claims in the media slice match its rows, and deleting the post
  releases them, under the rules of ADR 0082. The social slice reaches the media slice only through its exports
  ([ADR 0003][0003]). A photo a part holds never shows in the part's text.
- **Four to a part.** A part holds up to four photos, the most both networks take on one post. The contract and the
  database both enforce it.
- **Native media at send.** When a part goes out, the delivery uploads its photos through each network's own media
  API with their alt text, and attaches them to that part.

## Alternatives

**Share the photos through `aa.cool`.** The first idea turned each photo into an `aa.cool` file, listed in the Files
tab. It lost once the networks could take the photo as an image: the share would add a link nobody needs and fill
the Files tab with photos nobody shared on purpose. Social post photos never reach the shares table or its bucket.

**Claim by the text.** Put the `/media/<key>` URL in the part and let ADR 0082's scan claim it. It lost because the
URL would reach the networks as a link, and the text has nowhere to keep alt text or order.

## Consequences

ADR 0082 now has two ways to claim: by reference in Markdown, and by row for social post parts. The sweep, the
releases and the last-release delete work the same for both.

The media slice needs a claim that takes photos by key, not by scanning text, and `photo_owner` gains a value for
social post parts.

Each network gets its own copy of every photo. Deleting the post here releases the photo in the media store, but
leaves the copies on Mastodon and Bluesky.

Each network caps image size its own way, and Bluesky's cap is near 1 MB, so the delivery has to resize a large
photo before it uploads. Nobody has checked the current limits yet (#1065).

Alt text goes out with the image, and neither network lets the app change it everywhere afterward.

[0003]: 0003-reach-another-slice-only-through-its-exports.md
[0080]: 0080-store-photos-in-an-s3-store-and-serve-them-through-the-site.md
[0081]: 0081-process-every-upload-with-libvips-on-the-server.md
[0082]: 0082-tie-a-photo-to-the-records-whose-markdown-points-to-it.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
