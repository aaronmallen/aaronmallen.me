---
id: "0099"
title: Keep decision logs in a decisions slice with decision_events and a decision_timeline view
status: active
created: 2026-10-03
area: [db, activity, admin, api, mcp]
issue: "#273"
tags: [decisions, slices, history, timeline, view, postgres, enums, constraints, comments, tags]
---

# ADR 0099: Keep decision logs in a decisions slice with decision_events and a decision_timeline view

![Active][status]

## Context

Spec #272 adds decision logs. A decision has a title and a Markdown problem statement, gains options over days, and
ends resolved with one of its own options or dropped, each with a Markdown reason. It can reopen, with a reason,
and reopening clears the choice. A closed decision edits like a published post: a change to the problem statement
or an option needs a note ([ADR 0084][0084]). I can comment on a decision, tag it with private tags, and link it to
tasks. Its page shows one timeline, oldest first, and every event reaches the feed.

The spec asks to build this the way #257 builds task history, which [ADR 0092][0092] records: typed events in one
table, comments in their own, and a view that unions them. [ADR 0015][0015] types a closed set as an enum, and
[ADR 0017][0017] puts every rule over stored state in Postgres. Links to tasks go through `record_links`
([ADR 0093][0093]), not a join of their own.

## Decision

**A new `decisions` feature slice owns every table here.** It exports its operations and queries to `admin`, `api`
and `mcp` ([ADR 0003][0003]).

**`decisions`** holds the title, the problem statement, a `decision_status` enum (`open`, `resolved`, `dropped`) and
`resolved_option_id`. A `CHECK` holds that a resolved decision has a choice and an open or dropped one has none.

**`decision_options`** holds each option's title and Markdown body, with a stable id. An edit changes the row in
place, never a replace of the whole set. A unique key on `(decision_id, id)` lets `decisions` point at it with a
composite foreign key on `(id, resolved_option_id)`, so Postgres refuses an option from another decision, and the
resolve operation maps that refusal to a field error. The foreign key does not cascade, so Postgres refuses to
delete the chosen option.

**`decision_events`** is append-only. A `decision_event_kind` enum names what happened: `opened`, `option_added`,
`option_edited`, `edited`, `resolved`, `dropped` and `reopened`. Typed columns hold what changed: the option, the
reason, the note. A `CHECK` per kind holds the columns that kind needs, so `resolved`, `dropped` and `reopened`
cannot land without a reason, and `resolved` cannot land without its option. Each write and its event share a
transaction ([ADR 0019][0019]).

**The edit note is checked under the decision's lock**, as `SavePost` does. The operation locks the row, reads the
stored status, and fails a blank note as a field error when the decision is closed and the problem statement or the
option changed. The note lands on the `edited` or `option_edited` event.

**`decision_comments`** holds Markdown comments I can add, edit and delete, with photos claimed as a task comment's
are ([ADR 0082][0082]).

**`decision_tags`** joins decisions to private tags, held to that scope in Postgres as [ADR 0074][0074] lays out.

**A `decision_timeline` view** unions events and comments, keyed by decision and stamped with the time each
happened. A later migration replaces the `activities` view with a branch for each table ([ADR 0052][0052]).

**Deletes cascade from the decision.** Its options, events, comments and tags go with it, and the `record_links`
trigger takes its links.

## Alternatives

**One comments table for tasks and decisions.** It would give both kinds one set of comment operations. It lost
because `task_comments` holds synced rows keyed by remote id ([ADR 0075][0075]), so a shared table would move live
synced rows and collide with the work #257 does on that table.

**Comments as event rows.** It would leave the view with one table to read. It lost because events are
append-only and a comment can be edited and deleted, the reason ADR 0092 keeps `task_comments` apart.

**A home in the `record` slice.** Decisions stay private like the journal `record` keeps. It lost because
[ADR 0001][0001] splits slices by what the code is about, not who reads it, and a decision with options, states and
comments has nothing in common with journal entries, commits or sync states.

## Consequences

A decision's timeline is one query against one relation, and the feed reads it through the same shape.

A new kind of event is `ALTER TYPE ... ADD VALUE`, a `CHECK` branch and its columns. The timeline and activities
views read these tables' columns, so changing one means replacing both views.

An option event points at its option, and deleting the option deletes its events. A reopened decision that frees
an option lets a delete take the `resolved` event that once chose it off the timeline.

The note rule lives in the operation, not in Postgres. A write that skips the operation, or forgets the event,
leaves a closed edit with no note or a gap in the timeline, and nothing in Postgres notices.

ADR 0001 counts the feature slices, and ADR 0017 lists the mapped names. #274 updates both when it adds the slice.

[0001]: 0001-split-the-app-into-slices-by-feature.md
[0003]: 0003-reach-another-slice-only-through-its-exports.md
[0015]: 0015-type-a-closed-set-as-a-postgres-enum-and-a-format-as-a-domain.md
[0017]: 0017-enforce-rules-over-stored-state-in-postgres-not-in-contracts.md
[0019]: 0019-open-every-transaction-as-a-savepoint.md
[0052]: 0052-read-activity-through-one-view-across-every-content-kind.md
[0074]: 0074-split-tags-into-a-public-and-a-private-scope.md
[0075]: 0075-keep-local-and-synced-task-comments-in-one-table-keyed-by-remote-id.md
[0082]: 0082-tie-a-photo-to-the-records-whose-markdown-points-to-it.md
[0084]: 0084-keep-edit-notes-in-a-post-edits-table-and-require-one-under-the-posts-lock.md
[0092]: 0092-keep-task-history-in-task-events-and-a-task-timeline-view.md
[0093]: 0093-link-any-two-records-through-one-record-links-table-in-a-links-slice.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
