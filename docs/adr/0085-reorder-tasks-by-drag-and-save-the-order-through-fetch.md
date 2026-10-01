---
id: "0085"
title: Reorder tasks by drag and save the order through fetch
status: active
created: 2026-10-01
area: [admin, assets, tasks]
issue: "#149"
tags: [tasks, order, drag-and-drop, keyboard, fetch, javascript, forms, progressive-enhancement]
---

# ADR 0085: Reorder tasks by drag and save the order through fetch

![Active][status]

## Context

Tasks move one place per click, through up and down carets in `Admin::UI::Components::Tasks::Order`. Each click
posts a form to `post /tasks/:id/reorder/:direction` and reloads the page, so moving a task five places takes five
round trips. On a phone the carets make small, crowded tap targets, the kind [ADR 0054][0054] set out to remove.

Spec #148 puts a grip on each open task row in their place. The operator drags the grip to any place in the list
or sprint and drops it there, or moves a focused row one place with Alt+Up and Alt+Down. The new order saves with
no reload.

[ADR 0055][0055] makes every admin write a plain form POST that scripts only add to. A drag has no form to fall
back on: only a script can tell where the task landed.

## Decision

Task order changes only through a script, and the script saves it through `fetch`.

A new module in `app/assets/js/admin`, written by hand on pointer events, drives the grip with a mouse or a
finger, and moves a focused row on Alt+Up and Alt+Down. A drop or a key press posts the task and the task it now
follows to an endpoint in the admin slice, with the page's CSRF token. The endpoint places the task right after
that one in the same list or sprint, or first when nothing comes before it, and answers 204 with no page.

The carets go from task rows. Projects and work entries keep theirs, and the MCP `reorder_task` tool keeps its
up and down moves.

## Alternatives

**A hidden form that posts on drop and reloads.** The script fills a form with the task and its new place and
submits it, and the server redirects with a toast as ADR 0055 asks. A drag needs a script either way, so the form
buys no path with scripts off. It only brings back the reload the spec sets out to remove.

**SortableJS.** It handles the drag with mouse and touch, in place of a module we write. The admin's scripts are
small modules with no framework, and the bundle carries no script library today. SortableJS would be the first,
and it has no keyboard moves, so Alt+Up and Alt+Down would still need our own code.

## Consequences

A task moves any number of places in one drop and one request, and the grip can meet the 44px tap target.

With scripts off, task order cannot change in the admin. Only the MCP `reorder_task` tool can still move a task.

The server gains another write that answers with no page, the cost ADR 0055 names for writes through `fetch`.
The request specs can post to the endpoint with rack-test, but only a browser spec covers the drag and the keys.

A drag reaches only the rows on screen. With a search filter active the rows are not a task's real neighbours, so
the grips hide and the keys do nothing. On a paged list a task moves within its page.

[0054]: 0054-run-every-admin-screen-on-a-phone.md
[0055]: 0055-make-every-admin-write-a-plain-form-post-that-scripts-only-add-to.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
