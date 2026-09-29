---
id: "0076"
title: Page flat lists by number and day-grouped lists by whole day
status: active
created: 2026-09-29
area: [public, admin, mcp, activity, record]
issue: "#92"
tags: [paging, lists, feeds, journal, activity, commits, settings]
---

# ADR 0076: Page flat lists by number and day-grouped lists by whole day

![Active][status]

## Context

Spec #91 pages every list that grows. Most lists load every row on every visit: `/admin/social`, the journal,
`/writing`, the Atom feeds and most MCP list tools. Some lists are flat, one row after another. The journal,
activity and commits group their rows by day, and a page that cut a day in two would show half of it.

`MCP::Tools::DayWindow` already pages `read_activity` by day. An answer stops near its cap, then finishes the day
it is on, and hands back `partial: true` with `continue_to`, the day to ask for next.

Paging has to stay plain GET links that work with scripts off (ADR 0055) and on a phone (ADR 0054).

## Decision

Lists page in one of two shapes.

**Flat lists page by number.** A page takes `?page=N` and links to the older and newer pages. The public site
shows 25 rows a page, and the admin and MCP show 100. The page sizes come from settings. This covers posts, social
posts, tasks, messages, webmentions, tags, suggestions and sprints. Each Atom feed carries the
newest 25 posts and a `rel="next"` link to older ones (RFC 5005).

**Day-grouped lists page by whole day.** The journal, activity and commits take a day cursor. A page stops near the
page size, then runs on to the end of the day it is on, so a day never splits. The MCP tools for these lists share
the one cursor `DayWindow` holds, and `read_activity` drops its own copy.

Every MCP list tool in #91 answers with one page, sets `partial: true` when more remain, and hands back a cursor
that fetches the rest: the next page number for a flat list, the next day for a grouped one.

## Alternatives

**Page numbers everywhere.** One shape for every list, but a numbered page holds a fixed count of rows and cannot
round a journal page out to whole days.

**A keyset cursor everywhere.** Rows would hold still between pages, but links would lose their page numbers, and
each sort order would need its own cursor format and its own index.

## Consequences

Two shapes to learn, not one, and a new list has to pick one: flat or grouped by day.

When new rows land, rows on a numbered page shift down. A reader moving to the next page can see a row twice, or
miss one that moved to the page behind them.

A day-grouped page can run well past the page size when one day holds many rows.

MCP list tools that sent back every match now send one page. A client that never asked for paging gets part of the
answer and has to read `partial` to know it.

A new migration adds indexes for the sort orders that lack one: messages, journal entries, commits and finished
tasks.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
