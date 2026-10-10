---
id: "0101"
title: Bind every admin key through one key map that reads keys from the markup
status: active
created: 2026-10-03
area: [admin, assets]
issue: "#297"
amended: ["#745", "#915"]
tags: [admin, keyboard, shortcuts, palette, help, accessibility, javascript]
---

# ADR 0101: Bind every admin key through one key map that reads keys from the markup

![Active][status]

## Context

Spec #289 adds keys to every admin list: `j` and `k` to move through rows and Enter to open one, row keys such as
`x` to complete a task, `g` then a letter to jump to a section, `c` to create and `?` for a list of the keys on
the screen. No key may fire in a text field, and every key action must also be a tap or a click.

Two scripts bind keys today, each with its own `keydown` listener on the document. [ADR 0053][0053] gives `/` to
`palette.js`, which checks for a field itself, and says a screen that wants a key outside a field has to take it
back from there. `task_order.js` moves a focused task row on Alt+Up and Alt+Down ([ADR 0085][0085]). Admin scripts
are small modules with no framework that work through data attributes, and the Phlex views write those attributes
and every label through the locale files ([ADR 0055][0055]).

## Decision

**One key map.** `app/assets/js/admin/keys.js` holds the admin's only `keydown` listener on the document. It
decides when keys stay quiet, finds the binding and runs it. `palette.js` and `task_order.js` drop their own
listeners and bind through it.

Since #915 one kind of listener sits beside it: one that only closes an open menu or disclosure on Escape, wherever
focus sits. `social_account_picker.js` closes the account menu this way, and `app/assets/js/disclosure.js` closes
each disclosure. A listener on the menu itself would miss Escape while focus is outside the menu.

**Keys live in the markup.** A view declares a key by putting `data-key` on the button, link or submit that
already does the job, with `data-key-label` holding its label from the locale files. The key map runs a key by
clicking that control, so a key does nothing a click cannot, and a screen that draws no control for a key has no
such key. A published post draws no publish button, so `p` does nothing on it.

- **Rows.** A list marks itself with `data-key-list` and each row with `data-key-row`. `j` and `k` move focus to
  the next or previous row's open control, the link or button marked `data-key-open`, and scroll it into view. The
  highlight is that focus, so Enter opens the row the way the browser opens any focused link, and Alt+Up and
  Alt+Down find the row the way they do today. A row with no open control, such as a message, takes focus
  itself, and Enter does nothing there, as a click on it does nothing. A `data-key` inside a row runs against the
  row that holds focus, and does nothing when no row does.
- **Screen keys** such as `c` sit on a control outside any row, such as the create button.
- **Jumps.** Each row of `Admin::Operations::ListSections::ALL` gains its jump letter, and the palette draws it as
  `data-key="g t"` on the section's row. After `g` the key map waits for one more key, and a key with no section
  ends the wait.
- **Help.** The admin layout draws the help overlay as a modal `dialog`, opened by a button in the context bar
  that carries `data-key="?"`. The layout draws the keys no control carries (`j`, `k`, Enter and the chords) into
  the overlay with their labels from the locale files. On opening, the overlay adds every `data-key` on the page by
  its label, so it lists what the screen has at that moment. Since #745 the context bar is gone and the button
  sits in the avatar menu ([ADR 0128][0128]).
- **Chords in script.** `keys.js` exports `bind` for a key held with Ctrl, Meta or Alt, which may fire where plain
  keys may not. `palette.js` binds `⌘/` and `Ctrl+/`, and since #745 `⌘K`, and `task_order.js` binds Alt+Up
  and Alt+Down. `/` is a plain key, on the slash button alone, and since #745 on the search button that replaced it.

**Keys #745 adds.** `w` sits on a control that opens a journal entry, as `c` sits on the create button. `e`
opens the highlighted row on lists where no row key claims it, and on a task row it keeps editing the task.

**When keys stay quiet.** A plain key does nothing while focus is in a field that takes text (a text input, a
`textarea`, a `select` or anything `contenteditable`), or while any modal `dialog` is open, the palette and help
among them. A checkbox is not a field, so a ticked row ([ADR 0098][0098]) still takes keys. A plain key held with
Ctrl, Meta or Alt is left to the browser. Escape belongs to the open dialog.

## Alternatives

**Keys bound per screen.** Each list script listens for its own keys. Every script would copy the field and dialog
check, two scripts could claim one key unseen, and help could not learn what each listener binds.

**A registry in script.** One module maps screens to their keys and actions. The script would have to know which
screen it is on and which controls each row draws, which the view already knows, and the labels would leave the
locale files. A key could also outlive the control it stands for, and so run something no tap can reach.

**Leave `/` with `palette.js`.** Two listeners would each need the quiet rule, and the palette is the reason a
modal dialog silences keys.

## Consequences

The quiet rule lives in one function, and a new key is an attribute and a locale key in a view, with no script.

Every list view has to mark its list, rows and open control before `j` and `k` reach it, so a list that misses its
attributes takes no keys and nothing warns.

Letters are spread across the views that draw them, so changing one, or finding a clash on a screen, means
searching the views. Only a browser spec on the screen catches two controls claiming one key.

Moving focus as the highlight means a row's open control must take focus. A row without one gets `tabindex="-1"`
from the key map when `j` or `k` first reaches it.

Jump letters live with the sections, so a section added to `ListSections::ALL` has to pick a letter no other
section uses.

[0053]: 0053-navigate-the-admin-through-a-command-palette-not-a-tab-strip.md
[0055]: 0055-make-every-admin-write-a-plain-form-post-that-scripts-only-add-to.md
[0085]: 0085-reorder-tasks-by-drag-and-save-the-order-through-fetch.md
[0098]: 0098-run-each-bulk-action-as-one-operation-per-list-in-one-transaction.md
[0128]: 0128-lay-out-the-admin-as-a-full-width-pill-nav-shell-with-right-side-drawers.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
