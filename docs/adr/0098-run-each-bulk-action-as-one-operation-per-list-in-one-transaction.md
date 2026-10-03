---
id: "0098"
title: Run each bulk action as one operation per list, in one transaction
status: active
created: 2026-10-03
area: [admin, api, assets, contact, mcp, posts, social, tasks]
issue: "#329"
tags: [bulk, transactions, savepoint, after-commit, forms, routes, api, mcp, paging, tasks, posts, messages]
---

# ADR 0098: Run each bulk action as one operation per list, in one transaction

![Active][status]

## Context

Spec #290 lets the admin act on many tasks, posts, messages and webmentions at once. Each list gets a checkbox per
row, a select all box for the page and a bar of actions. A bulk action changes every record or none, and a failure
names the record and why. Each action also has an endpoint under `/api/v1` and an MCP tool that take a list of ids.

The rules for one record already live in single-record operations: `CompleteTask`, `CancelTask`, `MoveTask`,
`DeleteTask`, `DeletePost`, `MarkMessage`, `ModerateWebmention` and the rest. Some do more than write a row.
`DeletePost` releases the post's photos, and `ReleasePhotos` queues their purge through `after_commit`.

Four records bound the work. [ADR 0055][0055] makes every admin write a plain form, and HTML forms cannot nest, yet
each row already holds forms of its own. [ADR 0076][0076] pages the admin lists at 100 rows. [ADR 0085][0085] puts a
drag grip on each open task row. [ADR 0088][0088] makes an endpoint and its tool one class in `slices/api/endpoints`.

## Decision

**One operation per list.** Each feature slice gains one bulk operation that takes the ids, an action from a closed
set and that action's input, such as the target list for a move or the tag for a tag change:
`Tasks::Operations::ActOnTasks`, `Posts::Operations::ActOnPosts`, `Contact::Operations::ActOnMessages` and
`Social::Operations::ActOnWebmentions`. It opens one transaction and calls the single-record operation for each id in
turn. The first failure stops the loop and steps out as `Failure[:record, id, reason]`, where `reason` is what the
single operation failed with, such as `:not_found` or a contract's errors. The step rolls back every record the loop
had changed. Where no single operation exists yet, such as adding one tag to a task (#332) or deleting a message
(#336), the slice adds one first. A check that holds only for a batch, such as deleting drafts alone (#334), lives in
the bulk operation.

**Queued work goes through `after_commit`.** [ADR 0019][0019] ties a hook to its savepoint, so a photo purge queued
for a draft whose batch rolls back never runs. A single operation a bulk one calls must queue jobs only through
`after_commit`, never with a bare `perform_async`. None of the operations #290 reuses breaks this today. Rows written
alongside the change, such as the `task_events` rows #332 adds, sit in the same transaction and roll back with it.

**At most 100 ids per call**, the admin page size, so select all on a full page fits. The bulk contract drops
repeated ids, and refuses an empty list or a longer one before any work starts.

**The admin posts one route per list.** `post "/tasks/bulk"` and its peers take `ids[]` and the action as a field.
The action bar is a `<form>` outside the rows, and each row's checkbox joins it through the `form` attribute, so
rows keep their own forms. Each action is a submit button whose name and value carry the action. The field is not
named `action`, since an element named `action` hides the form's own `action` property from scripts. A good batch
toasts and redirects back to the same list and page. A failure redirects back with a toast that names the record and
words its code.

**Select all ticks the rows on screen.** The box ticks the rows of the page in view, under whatever filter shows
them, and the form posts their ids. The server never turns "all" into a query, so a row that lands after the page
loaded is never touched. Script draws the box and shows or hides the bar. With scripts off the bar always shows and
the box does not draw. The checkbox sits outside the drag grip, so a tick never starts a drag, and a dragged row
keeps its tick, since selection is a set of ids, not places.

**The API and MCP take one endpoint and one tool per action.** Each action has its own route, such as
`post "/tasks/bulk/complete"`, and its own tool named for the action and the list, such as `complete_tasks`.
Each is one class in `slices/api/endpoints` that calls the list's operation with its action fixed. A good call
answers with the changed records. A failure answers 422 with a refusal whose message names the record and whose
`errors` hold the failing id under `ids`. A missing id is a 422, not a 404, since the call names several records.

## Alternatives

**One bulk operation per action**, such as `CompleteTasks` and `MarkMessagesRead`. Fourteen classes would repeat the
transaction, the cap and the failure shape, and the admin's one route per list would still need to pick between
them.

**One SQL write per batch**, an `UPDATE` or `DELETE` over `WHERE id IN`. One round trip, but it skips what the
single operations do: the photo release, the lookup that names a missing record and the task events. The bulk
path would keep a second copy of each rule, drifting from the one the admin uses on one row.

**Change what can change and report the rest.** Spec #290 asks for all or nothing.

**One admin route per action**, with each button sending its form elsewhere through `formaction`. Every action
would then parse the ids, check the cap and word the failure itself, and the routes would have to match the bar's
buttons one for one.

**One endpoint and one tool per list, with the action as an enum.** A move needs a target and a tag change needs a
tag, so the input would change shape with the action. JSON Schema can only say that through `oneOf`, which the
OpenAPI document and MCP clients show poorly. The single-record tools already split by action, as `complete_task`
and `cancel_task` do.

## Consequences

A bulk action keeps every rule a single record follows, and a new rule on the single operation reaches the batch with
no change to it.

A batch costs round trips: each record pays for its single operation's reads and writes and a SAVEPOINT and RELEASE,
and the database sits across the network on the NAS ([ADR 0006][0006]). A batch of 100 runs hundreds of round trips
and holds its row locks until the last one.

The first failure stops the batch, so three bad records take three tries to find.

The admin route takes its action from a field and the API from its path, so the two doors map the same set of
actions in two places.

With scripts off the operator ticks each row by hand, since select all needs a script.

Raising the admin page size past 100 lets select all tick more rows than the cap allows, and the batch refuses.

[0006]: 0006-run-the-site-on-a-raspberry-pi-behind-a-cloudflare-tunnel-with-its-data-on-the-nas.md
[0019]: 0019-open-every-transaction-as-a-savepoint.md
[0055]: 0055-make-every-admin-write-a-plain-form-post-that-scripts-only-add-to.md
[0076]: 0076-page-flat-lists-by-number-and-day-grouped-lists-by-whole-day.md
[0085]: 0085-reorder-tasks-by-drag-and-save-the-order-through-fetch.md
[0088]: 0088-hold-the-layer-the-api-and-mcp-share-in-the-api-slice-and-call-it-in-process.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
