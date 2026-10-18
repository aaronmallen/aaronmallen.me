---
id: "0177"
title: Keep single shares and group files in one table, each with a code or a group
status: active
created: 2026-10-15
area: [db, shares]
issue: "#1447"
tags: [shares, share-groups, short-codes, schema, migrations, check-constraints]
---

# ADR 0177: Keep single shares and group files in one table, each with a code or a group

![Active][status]

## Context

Spec #1446 lets me gather single shares into a group after the upload, add shares to a group that exists, and pull a
file out of a group into a single share with a new code.

Today a file lives in one of two tables. [ADR 0141][0141] puts a single share in `shares`, which owns a code from
`short_codes`. [ADR 0163][0163] puts a group's file in `share_group_files`, which belongs to a `share_groups` row
and owns no code. The two tables hold the same columns: storage key, filename, content type, size, alt text and
download count. A move between them would delete a row in one and insert it in the other.

A group file's link is `/<code>/<id>`, so its id has to outlive every move. A single share's link is `/<code>`, so
its id appears in no link.

## Decision

`share_group_files` takes in `shares`, and `shares` goes away.

- **A file has a code or a group.** Each row gains a nullable `short_code_id` beside a `share_group_id` that turns
  nullable. A CHECK holds exactly one of the two set, so Postgres refuses a file with both or with neither
  ([ADR 0017][0017]).
- **A move changes one row.** Joining a group clears the code and sets the group; leaving one does the reverse with a
  new code. The download count stays on the row.
- **Group file ids stay.** The migration leaves every group file's row as it is, so each `/<code>/<id>` link keeps
  working. Rows from `shares` move in with new ids.

The table lives in the shares slice, and the change ships as a new migration, since the app is live.

## Alternatives

**Keep two tables and copy a row on each move.** It lost because every move would delete one row and insert
another, and a group file pulled out and later put back would come back under a new id, breaking its link.

**Make every share a group of one.** One shape would serve both. It lost because a single share's `/<code>` returns
the raw file while a group's `/<code>` renders a page, so a file moving into a group would change what its old link
serves.

## Consequences

A file joins or leaves a group in one `UPDATE`, and its group file link and download count survive the trip.

Every single share gets a new id. Its link does not change, but the API and MCP name a share by id, so an id read
before the migration no longer finds it.

Code that reads a single share now filters on `short_code_id` being set, and code that reads a group's files filters
on `share_group_id`. A query that forgets the filter mixes the two.

[0017]: 0017-enforce-rules-over-stored-state-in-postgres-not-in-contracts.md
[0141]: 0141-keep-file-shares-in-a-shares-slice-with-their-own-bucket.md
[0163]: 0163-serve-a-share-groups-page-files-and-streamed-zip-under-its-code-on-the-share-host.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
