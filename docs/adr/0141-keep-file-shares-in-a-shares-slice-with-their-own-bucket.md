---
id: "0141"
title: Keep file shares in a shares slice with their own bucket
status: active
created: 2026-10-10
area: [config, db, lib, media]
issue: "#1054"
amended: ["#1259", "#1447", "#1775", "#1825"]
tags: [shares, short-codes, uploads, s3, buckets, providers, slices, media, photos]
---

# ADR 0141: Keep file shares in a shares slice with their own bucket

![Active][status]

## Context

Spec #1053 lets me hand anyone a file by a short link on `aa.cool`. A share can be any type of file, and it has to
reach the reader byte for byte: a screenshot keeps its GPS and camera data if I upload it with them.

The media slice cannot hold that. `upload_photo` takes only GIF, JPEG, PNG, WebP and HEIC, strips all its
metadata, shrinks the image and refuses a file over 20 MB ([ADR 0080][0080], [ADR 0081][0081]). The `photo_key`
domain allows only those four stored types. A photo also lives only while a record's Markdown claims it, and
`SweepPhotos` deletes the rest after a day ([ADR 0082][0082]). A share has no Markdown to claim it.

The media bucket also holds photos from journal entries, tasks and drafts, which no visitor may see. Every file
shared on `aa.cool` is for anyone with the link.

The short links of #1064 draw on the same codes as shares, so `aa.cool/talk` names one thing.

## Decision

Shares get their own feature slice, `shares`, and their own bucket.

- **A `short_codes` table holds every code on `aa.cool`.** Each share points at one, and so will each short link.
  Postgres holds the code format and keeps each code unique ([ADR 0017][0017]). The shares slice owns the table, so
  short links reach it through the slice's exported operations, never by writing it ([ADR 0021][0021],
  [ADR 0123][0123]). #1259 lets a share group own a code too, with its files under it and no code of their own
  ([ADR 0163][0163]).
- **A `shares` table** holds the original filename, content type, size, alt text and download count. #1447 moves
  these rows into `share_group_files`, where each file has a code or a group ([ADR 0177][0177]).
- **A separate S3 bucket holds only shares.** Its own setting, shaped like `media_store`, names it, and its own
  store provider reads that setting ([ADR 0009][0009]). The client and provider live in `lib/shares` beside the
  media ones; the relations, repos, contracts and operations live in `slices/shares` ([ADR 0126][0126]).
  #1825 took "public" out of this record's title: the bucket stays private, and the site streams each share
  itself, as [docs/shares.md][shares] says.
- **Nothing in the slice touches media.** Shares never pass through `upload_photo`, never sit in `photos`, and
  never meet a claim or `SweepPhotos`. The bytes go to the bucket as I uploaded them, with no size cap. #1775 borrows
  media's `detect_photo_type` and `process_photo` to store a small preview of an image beside it in the shares
  bucket, and leaves the original as it was.

## Alternatives

**Send images through `upload_photo`, and only other files through a new path.** One pipeline would hold every
image on the site. It lost because it strips the metadata I want kept, re-encodes the bytes, caps the size, and
ties a share's life to claims it has no way to make. Two kinds of share would also behave in two ways.

## Consequences

A file shared on `aa.cool` is exactly the file I picked, so a phone photo publishes where it was taken. Nothing
strips it for me.

The store gains a third bucket, beside media and backups ([ADR 0105][0105]), with its own setting and credentials.

Nothing sweeps the shares bucket. Deleting a share deletes its object, but an object left with no row stays until I
remove it by hand.

Short links depend on the shares slice for their codes, so #1064 cannot ship without it.

An image shared on `aa.cool` and the same image in a post are two copies, stored and served apart.

[0009]: 0009-register-every-service-client-with-or-without-its-credentials.md
[0017]: 0017-enforce-rules-over-stored-state-in-postgres-not-in-contracts.md
[0021]: 0021-let-sql-read-another-slices-tables-never-write-them.md
[0080]: 0080-store-photos-in-an-s3-store-and-serve-them-through-the-site.md
[0081]: 0081-process-every-upload-with-libvips-on-the-server.md
[0082]: 0082-tie-a-photo-to-the-records-whose-markdown-points-to-it.md
[0105]: 0105-dump-the-database-nightly-to-a-private-backups-bucket-and-keep-the-newest-7.md
[0123]: 0123-export-only-read-repos-and-operations-and-keep-write-repos-in-their-slice.md
[0126]: 0126-keep-only-base-classes-and-gem-wrappers-in-lib-and-give-the-rest-a-hanami-shape.md
[0163]: 0163-serve-a-share-groups-page-files-and-streamed-zip-under-its-code-on-the-share-host.md
[0177]: 0177-keep-single-shares-and-group-files-in-one-table-with-a-code-or-a-group.md
[shares]: ../shares.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
