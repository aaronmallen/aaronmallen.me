---
id: "0053"
title: Navigate the admin through a command palette, not a tab strip
status: active
created: 2026-09-28
area: [admin, assets]
issue: AA-659
tags: [admin, navigation, palette, keyboard, accessibility, design]
---

# ADR 0053: Navigate the admin through a command palette, not a tab strip

![Active][status]

## Context

AA-217 gave the admin a tab strip and AA-344 put its tabs in order. Then the design handoff replaced it
(`admin-nav.jsx`): a context bar that says where you are, a palette that lists every section, and a floating button
that opens it. Tasks, tags and task types had yet to land, and tasks and tags were each going to add a tab.

AA-372 named what a palette does not carry for free:

- **The unread count.** A tab can wear a badge. A palette has no surface that stays on screen, so the count needs a
  home or nobody sees it.
- **A phone.** A palette is opened from the keyboard, and a phone has no shortcut. Without something to tap, the
  admin is out of reach on the screen AA-346 set out to serve.
- **Finding what exists.** A tab strip shows every section. A palette shows what you can name.
- **It is a hard widget.** A combobox driving a listbox, with focus, arrow keys, filtering and results read out to a
  screen reader. Nothing like it was in the codebase.

## Decision

The admin has no tab strip. `Admin::UI::Layouts::Application` calls `operations.build_navigation` on every signed-in
request and draws three parts from what it returns:

- `Nav::ContextBar` shows the group and section you are on, a link back to Today on every other screen, and a jump
  button. The jump button carries a dot when any section has something waiting.
- `Nav::Palette` is a modal `dialog`. With an empty query it lists every section under its group, with the count
  of what waits there. A query filters the sections, searches unfinished tasks, and offers to add the query to
  Today as a task through a hidden form that posts to the tasks route.
- `Nav::SlashButton` floats in the corner and opens the palette with a tap.

`app/assets/js/admin/palette.js` opens the palette on `/` from anywhere outside a field, and on `⌘/` or `Ctrl+/`
from anywhere at all.

A section is a row in `Admin::Operations::ListSections::ALL`: its name, group, icon and route, in the order the
palette lists them. A new section joins by adding its row and the locale keys `Structs::Section` reads for it. A row
whose route does not exist drops out.

## Alternatives

**Keep the tab strip.** It shows every section at once, holds a badge, and works without JavaScript. It lost because
the design replaced it and answered each cost above. Tasks, tags and task types then joined as palette rows
rather than as more tabs.

## Consequences

The dot and each row's count hold the unread figures, the slash button serves a phone, and the empty query lists
every section. The combobox AA-372 warned about is ours to keep: `palette.js` owns the focus, the keys and the
spoken count, and `spec/slices/admin/browser/palette_spec.rb` is what checks them.

Every signed-in admin page pays for the palette. `ListSections` counts unread messages and pending webmentions,
and `BuildNavigation` loads every open task through `tasks.queries.open_tasks` so the palette can search them,
though it shows five at most.

One dialog does two jobs. It holds navigation and the form that adds a task to Today, so a change to either touches
the other's markup and script.

`/` belongs to the admin. Any admin screen that wants the key for itself, outside a field, has to take it back from
`palette.js`.

Without JavaScript the admin chrome links to no admin screen but Today. Palette rows are `div role="option"` with
the target in `data-palette-href`, and the jump and slash buttons are `type="button"`, so the site header's public
links and the way back to Today are all the chrome holds. A section is then reached by typing its address.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
