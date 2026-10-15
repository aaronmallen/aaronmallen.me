---
id: "0163"
title: Serve a share group's page, files and streamed zip under its code on the share host
status: active
created: 2026-10-14
area: [config, db, shares]
issue: "#1259"
amended: ["#1384"]
tags: [shares, share-groups, aa-cool, hosts, routing, zip, streaming, puma, cache-control, short-codes]
---

# ADR 0163: Serve a share group's page, files and streamed zip under its code on the share host

![Active][status]

## Context

Spec #1258 shares several files under one link. Today a share holds one file, and its code returns the raw bytes.
The owner wants a group's link to open a page that shows its images in a carousel and lists its other files, each
with a link of its own, and a "download all" button that hands over every file as one zip.

[ADR 0142][0142] has the share host answer a code from `short_codes` and nothing else, so it has no room for a page's
files or a zip. [ADR 0141][0141] gives each share a code of its own and keeps only shares in the share bucket.

A code matches `^[a-z0-9]+(-[a-z0-9]+)*$`, so it never holds a `.` or a `/`.

## Decision

A group owns one code from `short_codes`, and its files take none. The share host answers three paths for a group:

- `/<code>` renders an HTML page for the group.
- `/<code>/<id>` returns the file with that id from the group, by the rules a single share follows today: range
  requests, inline or attachment by type, and its own download count.
- `/<code>.zip` streams every file in the group as one zip, read from the share bucket as it goes out. No zip lands
  in the bucket.

A single share's code still returns its raw file, and any other path still answers 404. The page, each file and the
zip send `Cache-Control: private, no-store`, as [ADR 0142][0142] asks of everything on the host.

The page counts views by the rules a share uses for downloads, and each file and the zip keep counts of their own.

## Alternatives

**Name a file by its filename under the code.** It reads better, but two files in a group can share a name, and a
rename would break the link. The id stays the same for as long as the file sits in the group.

**Name a file by its place in the group.** Removing a file would hand its link to the one after it.

**Serve the zip at `/<code>/zip`.** It would sit beside the file paths and need a rule to keep it clear of them.
`/<code>.zip` cannot clash with a code or a file, and the link says what it returns.

**Build the zip once and keep it in the bucket.** A repeat download would cost one read. It lost because every add,
remove or delete would have to rebuild or sweep it, and the spec wants no second copy.

## Consequences

A zip download holds one of the five Puma threads for the whole transfer, as every share download does under
[ADR 0142][0142], and no cache keeps it. A zip is as large as the group, so one download can hold a thread for a long
time. The cap on share transfers that #1384 adds to [ADR 0142][0142] counts each zip as one.

The page needs nothing from the share host but these paths. Its styles and any script have to come inline or from
the blog's host.

A file in a group has no code, so a group's file cannot turn into a single share without a new link.

[0141]: 0141-keep-file-shares-in-a-shares-slice-with-their-own-public-bucket.md
[0142]: 0142-serve-shares-on-their-own-host-picked-in-config-ru-and-let-no-cache-keep-them.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
