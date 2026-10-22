---
id: "0154"
title: Draw admin row menus on the server when they open, and submit them by fetch and morph
status: active
created: 2026-10-11
area:
  - admin
  - assets
issue: "#1145"
tags:
  - admin
  - context-menu
  - menu
  - javascript
  - fetch
  - idiomorph
  - morph
  - keyboard
  - confirm
  - live
  - toast
---

# ADR 0154: Draw admin row menus on the server when they open, and submit them by fetch and morph

![Active][status]

## Context

An admin row shows a few actions in its hover bar, and anything else means a trip to the edit form. Spec #1144 adds a
right-click menu to every admin row with actions, holding every action the row supports, tags among them. The menu
sits beside the hover bar, which stays as the way to reach row actions on a touch screen.

[ADR 0153][0153] lets row actions need scripts and submits them by fetch, morphing the page the redirect lands on.
[ADR 0101][0101] keeps keys quiet while a modal `dialog` is open, and [ADR 0118][0118] holds a live morph while one
is open. A menu is not a modal `dialog`, so neither rule covers it today. [ADR 0055][0055] asks before a delete
through `data-confirm`.

## Decision

**The server draws the menu when it opens.** Each row carries the URL of its menu. On open, a script fetches that URL
and shows what comes back, so the menu shows the record as it stands now, not as the page drew it. A view in the
admin slice draws each menu with the same components and locale keys as the rest of the admin.

**Menu items are real forms.** An action is a form that posts to the route the hover bar or the edit page uses, or
to a new one where none exists, with the attribute that opts it into ADR 0153's fetch and morph. It keeps its redirect
and its flash, so the page updates in place and shows the toast it shows today. Drop and Reopen on a decision open
the reason form in a dialog, since a reason stays required. Copy and open items run in the browser and show the toast
`record_key.js` shows.

**Deletes confirm inline.** Delete turns into "Click again" and posts on the second click. Escape or closing the menu
before then deletes nothing. Menu deletes do not use `data-confirm`.

**Keys open it, and some clicks keep the browser's menu.** Right-click on a row opens its menu at the pointer. The
Menu key and Shift+F10 on a focused row open it beside the row. Shift+right-click, and right-click on a link inside a
row, show the browser's own menu. Arrow keys move through items and into submenus, Enter and Space run an item, and
Escape closes the menu and hands focus back to the row.

**A More button opens it too.** A row may carry a quiet "…" button marked `data-menu-more`, as each jobs tab row does
(#1848). A click opens the row's menu below the button, and Enter or Space opens it with focus on its first item.
Escape hands focus back to the button.

**An open menu counts as a modal dialog.** While it is open, `keys.js` runs no plain key and `live.js` keeps the
newest answer and morphs when the menu closes, as each does for a modal `dialog`.

## Alternatives

**Rows declare their items in the markup.** Every row would carry every item and submenu, tag lists among them, in
every page and every morph. The items would show the record as the page last drew it. The owner picked fetch on open
in #1144.

**Replace the hover bar.** A touch screen has no right-click, so the hover bar would leave with no way to reach row
actions there.

## Consequences

A menu waits on a request before it shows, and each row kind with a menu needs its own route, action and view.

Menus need scripts, as ADR 0153 allows. With scripts off a right-click shows the browser's menu.

Each action posts to a route, so request specs still drive it, but opening, keys, copy and the inline confirm show
only in browser specs.

A menu that stays open hides live updates from the page until it closes.

[0055]: 0055-make-every-admin-write-a-plain-form-post-that-scripts-only-add-to.md
[0101]: 0101-bind-every-admin-key-through-one-key-map-that-reads-keys-from-the-markup.md
[0118]: 0118-keep-admin-pages-live-through-postgres-notify-a-hijacked-event-stream-and-a-morph.md
[0153]: 0153-update-admin-row-actions-and-filters-in-place-by-fetch-and-morph-and-let-them-need-scripts.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
