---
id: "0134"
title: Store each pull request once and read it twice in the activity view
status: active
created: 2026-10-09
area: [record, activity, db]
issue: "#814"
tags: [pull-requests, github, activity, view, schema]
---

# ADR 0134: Store each pull request once and read it twice in the activity view

![Active][status]

## Context

Spec #813 brings the pull requests I author into the activity feed ([ADR 0052][0052]). Each one adds up to two rows:
an opened row when it is ready for review, and a merged or closed row when it ends. A draft opens at the time it was
marked ready, and a draft closed before that adds no rows. The feed shows each pull request as it stands now, so a
reopened pull request loses its closed row until it ends again. A history of reopens is out of scope.

## Decision

The `record` slice keeps each pull request in one row of a `pull_requests` table, with its ready, merged and closed
times. The import overwrites the row with what GitHub says now.

The `activities` view reads that table in two branches. One gives a `pull_request_opened` row at the ready time. The
other gives a `pull_request_merged` row at the merged time, or else a `pull_request_closed` row at the closed time.
A row with no ready time adds nothing to either branch, and a merged pull request never yields a closed row.

## Alternatives

**A `pull_request_events` table, like `decision_events`** ([ADR 0099][0099]). The import would append an event each
time a pull request opened, merged, closed or reopened, and the view would read the events. It keeps a history of
reopens, but every import would have to compare what GitHub sends with what it stored to work out which events to
write. Nobody asked for that history, so the diff buys nothing.

## Consequences

The import stays an upsert, and the feed can never show a stale closed row: reopening clears the closed time, so
the closed row goes on the next import.

We keep no record of a reopen or of earlier closes. Wanting that later means a new table and an import that diffs.

The view gains two branches over one table, and both read its columns, so a migration that changes those columns
replaces the view ([ADR 0052][0052]).

[0052]: 0052-read-activity-through-one-view-across-every-content-kind.md
[0099]: 0099-keep-decision-logs-in-a-decisions-slice-with-decision-events-and-a-decision-timeline-view.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
