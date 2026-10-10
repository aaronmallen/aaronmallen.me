---
id: "0120"
title: Mark webmentions seen apart from their status, and clear the inbox in one transaction
status: active
created: 2026-10-07
area: [db, admin, api, contact, mcp, social, tasks]
issue: "#650"
amended: ["#911"]
tags: [inbox, webmentions, messages, tasks, schema, bulk, transactions, savepoint, api, mcp]
---

# ADR 0120: Mark webmentions seen apart from their status, and clear the inbox in one transaction

![Active][status]

## Context

Spec #649 gives the inbox a Mark All As Seen button. It clears every row the page shows: synced issues get marked
seen, unread messages get marked read, and pending webmentions get marked seen. A row that arrives after the page
loaded stays. If one row fails, none change, and the page names the one that failed. An API endpoint and an MCP tool
do the same, given the ids.

[ADR 0094][0094] built the inbox from three queries, one per slice, merged in `api`, and left bulk actions out. Issues
already carry a seen mark in `task_sources.seen_at`, and a message leaves the inbox once read. A webmention leaves
only through a verdict: approve, ignore or spam. The owner wants cleared mentions still pending, so the Webmentions
page can judge them later.

[ADR 0098][0098] runs each bulk action as one operation per list, in one transaction, that calls the single-record
operation for each id. That covers one kind at a time. The inbox holds three.

## Decision

**A webmention's seen mark is a column, not a status.** A new migration adds a nullable `seen_at` to `webmentions`, with
no backfill, so the mentions pending today stay in the inbox. The `social` slice gains a mark-seen operation that sets
it to now on any mention that exists, whatever its status. Its exported `repos.webmention_queries` answers `#unseen` and
`#unseen_count`, which read pending mentions with no `seen_at`, and `API::Repos::InboxQueries#unseen` and
`#unseen_count` read those in place of the pending reads. #911 corrected these names. The Webmentions page, Today and
the analytics figures keep counting every pending mention.

**One `api` operation clears the inbox.** `API::Operations::ClearInbox` takes three lists of ids, `tasks`,
`messages` and `webmentions`, and opens one transaction. It calls `tasks.operations.mark_task_seen`,
`contact.operations.mark_message` with `read`, and the new social operation for each id in turn, all through slice
exports. The first failure stops the loop, steps out as `Failure[:record, kind, id, reason]` and rolls back every row
the call had changed. The contract drops repeated ids and refuses a call whose three lists are all empty. It does not
take the cap of 100 from [ADR 0098][0098]: the inbox has no pages, and the button posts every row it shows.

**Each door posts ids, never "all".** The admin posts `post "/inbox/seen"` from a form outside the rows that carries
each row's id, and imports the operation from `api` as it imports `repos.inbox_queries` (#911). The form asks to confirm
before it sends. The endpoint and the MCP tool are one class in `slices/api/endpoints`, per [ADR 0088][0088]. A failure
answers 422 and puts the failing id under its kind in `errors`.

## Alternatives

**Ignore the mentions.** No new column, since `ignored` takes a mention out of the inbox already. The owner first
picked it, then turned it down: an ignored mention leaves the Webmentions queue, and the spec wants it still there to
approve, ignore or mark spam.

**Chain the three bulk calls.** The admin or the endpoint would call `ActOnTasks`, `ActOnMessages` and
`ActOnWebmentions` one after the other. Each commits on its own, so a failure in the third leaves the first two
cleared, and the spec asks for all or none. The owner chose one transaction in #649.

**A `seen` status for webmentions.** It would sit beside the verdicts as a fourth outcome, and every query that reads
`pending` would have to read it as pending too.

## Consequences

The inbox and its nav count stop agreeing with the Webmentions page's pending count. A mention can be pending and out
of the inbox, and the two numbers differ by the mentions marked seen.

A webmention that a source sends again keeps its `seen_at`, since the column is not one a resend writes. A changed
mention stays out of the inbox.

`api` now holds a write that spans three slices. A new kind in the inbox needs a list here as well as its query, or
the button leaves its rows behind.

With no cap, a large inbox runs one long transaction that holds its row locks until the last id, and an API caller can
send as many ids as it likes.

A row moderated in another tab after the page loaded still clears, but a row deleted there fails the whole click.

[0088]: 0088-hold-the-layer-the-api-and-mcp-share-in-the-api-slice-and-call-it-in-process.md
[0094]: 0094-keep-a-seen-at-on-task-sources-and-merge-the-inbox-in-the-api-slice.md
[0098]: 0098-run-each-bulk-action-as-one-operation-per-list-in-one-transaction.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
