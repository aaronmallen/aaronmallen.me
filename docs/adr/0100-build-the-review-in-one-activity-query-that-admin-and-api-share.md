---
id: "0100"
title: Build the review in one activity query that admin and api share
status: active
created: 2026-10-03
area: [activity, admin, api]
issue: "#340"
amended: ["#623"]
tags: [activity, review, tasks, posts, social, journal, commits, time, exports]
---

# ADR 0100: Build the review in one activity query that admin and api share

![Active][status]

## Context

The spec in #293 adds a review: one week or month of tasks done and carried, time worked, posts and social posts
published, journal entries, commits by repo and, once #272 lands, decisions. An admin screen shows it, and an API
endpoint and MCP tool return the same numbers.

The sections read tables that `tasks`, `record`, `posts` and `social` own. [ADR 0003][0003] bars a slice from
another's repos, and [ADR 0021][0021] lets SQL read another slice's tables but never write them. The `activity` slice
already reads across them, and `admin` imports its queries for Today. MCP reaches the API through the endpoints in
`api`, as [ADR 0088][0088] says.

## Decision

One query in the `activity` slice builds every section of the review for a period, week or month, and a day in it.
It reads the other slices' tables in SQL and writes none of them.

`activity` exports the query. `admin` imports it for the screen, and `api` imports it for the review endpoint that
its MCP tool calls. The screen and the tool then run the same code over the same range, and read one set of numbers.

The query takes contributor terms (#623). They narrow the done tasks alone, which `review_tasks` reads with each
task's contributors, the owner when it lists none ([ADR 0115][0115]). The carried tasks, the time worked and the
other sections stay whole, so the time report and the review still agree on hours.

## Alternatives

**An admin operation beside its own API endpoint.** Each door would build the review itself. It loses because two
copies of the same sums drift, and a fix in one leaves the other wrong.

**The admin screen calls the API endpoint.** The API would be the one place the review gets built. It loses because
the screen would then depend on the endpoint's JSON shapes, and a change made for the CLI or the MCP tool would break
the page.

## Consequences

The screen, the endpoint and the tool share one result, and a new section, such as decisions in #272, lands once.

`api` gains its first import from `activity`.

The query reads columns in `tasks`, `commits`, `journal_entries`, `posts`, `social_posts` and the work session
table from #259. A change to one of those can break the review without touching `activity`, and only its specs will
say so.

`activity` grows from a feed into the place that sums the record, and its exports widen with it.

[0003]: 0003-reach-another-slice-only-through-its-exports.md
[0021]: 0021-let-sql-read-another-slices-tables-never-write-them.md
[0088]: 0088-hold-the-layer-the-api-and-mcp-share-in-the-api-slice-and-call-it-in-process.md
[0115]: 0115-keep-task-contributors-in-their-own-table-and-list-the-owner-when-a-task-has-none.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
