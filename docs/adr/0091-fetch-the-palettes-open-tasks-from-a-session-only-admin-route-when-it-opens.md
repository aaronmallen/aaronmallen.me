---
id: "0091"
title: Fetch the palette's open tasks from a session-only admin route when it opens
status: active
created: 2026-10-01
area: [admin, assets]
issue: "#201"
tags: [admin, palette, tasks, fetch, json, javascript, performance]
---

# ADR 0091: Fetch the palette's open tasks from a session-only admin route when it opens

![Active][status]

## Context

[ADR 0053][0053] has `BuildNavigation` load every open task through `tasks.queries.open_tasks` on every signed-in
admin page, so `Nav::Palette` can draw one hidden row per task for `palette.js` to search. The palette shows five at
most, and only once I type. Every admin page pays for the read and the rows, opened or not. Each row needs only the
task's id, its title and its list.

Nothing else on the page holds the same data, so the palette has nothing to borrow. The JSON API from
[ADR 0086][0086] lists tasks, but it admits API tokens alone, and the admin signs in with a session.

## Decision

The layout loads no tasks. `BuildNavigation` returns the sections alone.

`GET /admin/tasks/palette`, served by `Admin::Actions::Tasks::Palette`, answers with every open task as JSON:
`{"tasks": [{"id", "title", "list"}]}`, where `list` names the view the task sits in, such as `next` or `upcoming`.
The answer is `no-store`. The route reads the admin session and nothing else: with no session it answers 401, where
other admin routes redirect to sign-in, and it leaves the sign-in's `return_to` alone, so a lapsed session never
sends me to a page of JSON after I sign in.

`palette.js` fetches the route the first time the palette opens on a page, and never again on that page unless the
fetch fails. `Nav::Palette` draws the empty Tasks group, carrying the route and, per list, the link and the "in
next" line in data attributes, plus a `template` holding one `PaletteRow`. The script clones the template for each
task, so the markup and the words stay in Ruby. Matching works as before: no task shows until I type, and five at
most show.

## Alternatives

**Keep loading tasks in the layout.** It needs no route and no script, and the rows are there the moment the palette
opens. It lost because every admin page reads every open task for a palette that may never open.

**Call the JSON API.** `/api/v1` already lists tasks. It lost because it admits API tokens alone, so the admin page
would have to hold a token beside the session it already has.

## Consequences

Admin pages draw with no read of the tasks table, except the pages that list tasks themselves.

The first search after opening costs a round trip. A task I type for before the reply lands shows when it lands. A
failed fetch leaves the Tasks group empty until the palette opens again.

The palette lists the tasks that were open when it first opened on the page. A change made since without a reload
shows on the next page.

The script and `Nav::Palette` must agree on the template's markup and the data attributes, and only the browser spec
checks that they do.

[0053]: 0053-navigate-the-admin-through-a-command-palette-not-a-tab-strip.md
[0086]: 0086-serve-a-json-api-behind-long-lived-tokens-minted-in-the-admin.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
