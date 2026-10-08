---
id: "0053"
title: Navigate the admin through a command palette, not a tab strip
status: superseded
created: 2026-09-28
area: [admin, assets]
superseded-by: "0128"
issue: AA-659
amended: ["#17", "#87", "#201", "#297", "#303", "#311", "#314", "#282", "#320", "#745", "#768"]
tags: [admin, navigation, palette, keyboard, accessibility, design]
---

# ADR 0053: Navigate the admin through a command palette, not a tab strip

![Superseded][status]

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
  of what waits there, then an Actions group. A query filters the sections and the actions alike, and searches
  unfinished tasks.
- `Nav::SlashButton` floats in the corner and opens the palette with a tap.

`app/assets/js/admin/palette.js` opens the palette on `/` from anywhere outside a field, and on `⌘/` or `Ctrl+/`
from anywhere at all. Since #297 it binds those keys through the admin's one key map, `keys.js`, as
[ADR 0101][0101] records.

An action is an entry in `Admin::Operations::ListActions::ALL`: its name, icon, route and route params, and the dialog
it opens if it has one. Each entry once took a `shows` check on the current path, but none used it, and #607 dropped it.
A new action joins by adding its entry and the `label` and `text` locale keys `Structs::Action` reads for it. `Palette`
draws a row per entry in list order, matches on the label and the text together, and `palette.js` runs any row from its
`href` and `dialog`, so neither changes for a new action. The Actions group sits above the tasks, so a query that
matches an action lists it first. #303 made the list, and it now holds these rows:

- "Create task" shuts the palette and opens the new task dialog on the page you are on, and goes to
  `/admin/tasks/new` when that page has no dialog.
- "Create decision" goes to `/admin/decisions/new`.
- "Create journal entry" shuts the palette and, since #768, opens the journal modal on the page you are on. Without
  a script it goes to `/admin/journal?write=1`, which draws the entry field with `autofocus`.
- "New post" goes to `/admin/posts/new`.
- "New social post" goes to `/admin/social?write=1`, which puts `autofocus` on the composer's first part.
- "Start task", "Complete task" and "Pause task" act on the task on screen.
- "Complete {title}" and "Pause {title}" list each task in progress when no task is on screen.

Since #311 an entry can also `post` to its target, and can say what it `needs` on screen. "Start task", "Complete task"
and, since #314, "Pause task" need a task: the one open in the task flyout, or else the one the task page shows.
`Tasks::Controls` marks its start, complete and pause forms with `data-task-act`, and the row posts to the form's
address, so a row shows only where the task page would offer the same button. Pausing posts to the stop action, which
returns the task to open and ends its work session. "Complete {title}" and "Pause {title}" need no task on screen. Each
entry names a `from` route, `/admin/tasks/in-progress`, with `from_params` that pick the action each row posts to
(`act=pause`, or complete when left out), and `Palette` draws a `template` in place of a row. `palette.js` fetches each
route the first time the palette opens with no task on screen, and clones one row per task in progress. The route keeps
what [ADR 0091][0091] set for such routes: it reads the session alone, answers 401 without one, and answers `no-store`.
The layout still reads no task. A posted row sends the page's own address as `return_to`, and start, complete and stop
redirect there when it is an admin path, so I stay on the screen I ran it from.

Since #320 a Saved views group sits below the actions. It stays hidden until I type, then lists each saved view
whose name holds the query, with its screen beside it, and opens the screen with the view's filters set.
`palette.js` fetches `GET /admin/saved-views/palette` the first time the palette opens on a page and clones one row
per view from the group's `template`. The route keeps what [ADR 0091][0091] set: it reads the session alone, answers
401 without one, and answers `no-store`. The layout reads no saved view, so a view deleted elsewhere leaves the
palette on the next page.

A section is a row in `Admin::Operations::ListSections::ALL`: its name, group, icon and route, in the order the
palette lists them. A new section joins by adding its row and the locale keys `Structs::Section` reads for it. A row
whose route does not exist drops out.

## Alternatives

**Keep the tab strip.** It shows every section at once, holds a badge, and works without JavaScript. It lost because
the design replaced it and answered each cost above. Tasks, tags and task types then joined as palette rows
rather than as more tabs, and #17 took the task types row out again (ADR 0065).

## Consequences

The dot and each row's count hold the unread figures, the slash button serves a phone, and the empty query lists
every section. The combobox AA-372 warned about is ours to keep: `palette.js` owns the focus, the keys and the
spoken count, and `spec/slices/admin/browser/palette_spec.rb` is what checks them.

Every signed-in admin page pays for the palette. `ListSections` counts unread messages and pending webmentions.
`BuildNavigation` loaded every open task so the palette could search them, though it shows five at most, until #201
moved them to a fetch the palette makes when it opens, as [ADR 0091][0091] records.

One dialog does two jobs. It holds navigation and the actions, so a change to either touches the other's markup and
script.

`/` belongs to the admin. Any admin screen that wants the key for itself, outside a field, has to take it back from
the palette. #297 moved every admin key into one key map, and an open palette now silences the rest of them.

Without JavaScript the admin chrome links to no admin screen but Today. Palette rows are `div role="option"` with
the target in `data-palette-href`, and the jump and slash buttons are `type="button"`, so the site header's public
links and the way back to Today are all the chrome holds. A section is then reached by typing its address.

[0091]: 0091-fetch-the-palettes-open-tasks-from-a-session-only-admin-route-when-it-opens.md
[0101]: 0101-bind-every-admin-key-through-one-key-map-that-reads-keys-from-the-markup.md
[status]: https://img.shields.io/badge/0128-black?style=for-the-badge&label=Superseded&labelColor=orange
