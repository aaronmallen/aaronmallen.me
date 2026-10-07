---
id: "0094"
title: Keep a seen_at on task_sources, and merge the inbox in the api slice
status: active
created: 2026-10-03
area: [db, admin, api, contact, mcp, social, tasks]
issue: "#325"
amended: ["#650"]
tags: [inbox, tasks, imports, schema, slices, exports, api, mcp, messages, webmentions]
---

# ADR 0094: Keep a seen_at on task_sources, and merge the inbox in the api slice

![Active][status]

## Context

Spec #292 puts what waits on the owner in one inbox: every unread message, every pending webmention and every synced
issue the owner has not looked at, newest first. The nav shows one count for it, and an API endpoint and an MCP tool
list the same rows.

Messages and webmentions already say whether they wait: a message's status is `unread`, a webmention's is `pending`.
A synced issue says nothing of the kind. [ADR 0066][0066] keeps its origin in `task_sources`, and [ADR 0067][0067]
parks it on External, but a task stays on External long after the owner has read it.

The rows live in three slices, `contact`, `social` and `tasks`, and [ADR 0003][0003] lets a slice reach another only
through its exports. Today the admin nav asks `contact` and `social` for a count each, in
`Admin::Operations::ListSections`. [ADR 0088][0088] puts the layer the API and MCP share in the `api` slice.

## Decision

**The seen mark lives on `task_sources`.** A new migration adds a nullable `seen_at`, and sets it to now on every row
that exists, so the first inbox does not hold every issue ever synced. A source with no `seen_at` waits on the owner.
The `tasks` slice sets it in three places:

- a new mark-seen operation, which leaves the task where it is;
- any move of a sourced task;
- any change to a sourced task's tags.

A sync that imports a new issue leaves `seen_at` empty. Nothing else clears a synced issue from the inbox.

**Each slice says what waits, and `api` merges.** `contact`, `social` and `tasks` each export a query for their own
waiting rows. The `api` slice imports the three and holds the query that merges them newest first, with the count
beside it. `admin` imports that query from `api`, as it imports `queries.live_tokens` today, for both the Inbox
screen and the nav count. The inbox endpoint calls the same query, and the MCP tool reaches it through the endpoint,
as [ADR 0088][0088] says.

Bulk actions on the inbox (#290) stay out of this record. #650 records clearing the whole inbox in one step in
[ADR 0120][0120].

## Alternatives

**A seen mark on `tasks`.** It would sit empty on every task the owner made, the cost that kept source columns off
`tasks` in [ADR 0066][0066].

**Read "not yet looked at" from External.** No new column, but a task stays on External after the owner reads it, and
the spec wants an issue marked seen without moving it.

**Merge in `admin`.** The screen and the nav would agree, but the endpoint and the tool would need a second merge, and
the two would drift. `api` cannot borrow the merge from `admin`, since `admin` already imports from `api`.

## Consequences

The screen, the nav count, the endpoint and the tool read one query, so they cannot disagree on what waits.

`admin` now depends on `api` for its nav. A fault in the merge breaks the nav count on every admin page, not only the
Inbox screen.

Every operation that moves a task or changes its tags has to set `seen_at` when the task has a source. One that
forgets leaves the issue in the inbox, and nothing fails when it does.

`seen_at` says nothing about the task's state. Whether a synced issue the owner finished or canceled still waits is
for the `tasks` query to decide, not the column.

The `api` slice now imports `contact` and `social`, two more edges it has to keep free of cycles.

[0003]: 0003-reach-another-slice-only-through-its-exports.md
[0066]: 0066-keep-an-imported-tasks-origin-in-a-task-sources-table.md
[0067]: 0067-park-an-imported-task-on-an-external-list.md
[0088]: 0088-hold-the-layer-the-api-and-mcp-share-in-the-api-slice-and-call-it-in-process.md
[0120]: 0120-mark-webmentions-seen-apart-from-their-status-and-clear-the-inbox-in-one-transaction.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
