---
id: "0128"
title: Lay out the admin as a full-width pill-nav shell with right-side drawers
status: active
created: 2026-10-07
area: [admin, assets, config]
supersedes: ["0053"]
issue: "#745"
amended: ["#873", "#919"]
tags: [admin, layout, navigation, palette, drawer, keyboard, responsive, design]
---

# ADR 0128: Lay out the admin as a full-width pill-nav shell with right-side drawers

![Active][status]

## Context

[ADR 0053][0053] put twenty flat sections behind a palette, a context bar and a floating slash button.
`--container-admin` holds every admin screen to a 1280px column, so a 4K monitor shows a narrow strip with empty
space on both sides, and finding what needs attention means hunting through pages.

Spec #744 rebuilds the admin's look and layout from the designer's Admin v3 handoff in `tmp/design/`. Its
`README.md` covers the visuals and `assets/admin3.css` holds the measurements. The handoff changes how the admin
looks, never what it does: where it differs from the app on function, the app wins.

## Decision

**The admin fills the window.** No admin screen has a max-width container. `--container-admin` goes, and the gutter
grows with the window, `clamp(20px, 2.2vw, 56px)`. Prose keeps its own measure: a post body, a lede and a settings aside
cap at `--container-measure`, 44em, in `config/tailwind.css`. #919 moved that rule here from [ADR 0034][0034], which ADR
0136 superseded.

**A sticky top bar replaces the context bar and the slash button.** It holds, in order, the wordmark, six pills,
a search button that opens the palette, and an avatar menu. The pills are Today, Tasks, Journal, Publish, Inbox
and Insights, and the active one carries `aria-current="page"`. Each pill's screens show as sub-tabs under the
page header, in the README's table, and the time report sits under Insights. The Inbox pill wears the dot the
jump button wore. Settings (tags, people, task rules, webmentions, API tokens, connected services, MCP clients and
security) move to the avatar menu, with the site links, the key help, the theme toggle and sign out. Pills and
sub-tabs are links, so every screen they name opens without scripts. `live.js`
morphs the top bar where it morphed the context bar ([ADR 0118][0118]).

**The palette stays, regrouped.** It lists Actions, Records, Saved views, one group per category (Today, Tasks,
Journal, Publish, Inbox, Insights and Settings) and Search, in that order. Each screen sits under its category's
header and keeps its jump letter, and Settings holds every Settings tab. A search hides each header whose rows it
filters out, and a category's name finds its screens. Records search works as it does today ([ADR 0096][0096]).
Actions keep `ListActions::ALL` and its `needs` and `from` rules, and a new action joins as an entry there.

**Drawers open from the right.** A drawer is `min(620px, 100%)` wide, or 760px for the wide variant, with a header,
a body that scrolls and a footer. The task panel becomes the wide drawer and loads `/admin/tasks/:id` the way it
does now ([ADR 0071][0071]); the edit page keeps the task modal. Every other drawer, the avatar menu, the bulk bar
and the confirm open markup the page already drew. The confirm draws in place of the button that asked, and keeps
what [ADR 0055][0055] asks of it: it stops the submit only on No, and with scripts off the form posts without
asking.

**Two breakpoints.** The admin folds at 700px and 860px alone. Two-column layouts start at 860px, and the pill nav
drops onto its own row below it. Between them the pills and the search button shrink with `clamp` rather than at
another breakpoint. Below 700px every tap target keeps [ADR 0054][0054]'s 44px square.

**Keys stay, and three join.** Every key [ADR 0101][0101] binds works as it does today. `⌘K` opens the palette
beside `/` and `⌘/`, `w` opens a journal entry, and `e` opens a highlighted row on lists where no row key claims
it. On a task row `e` keeps editing the task.

The rebuild adds no `fetch` exception to ADR 0055. The task drawer fetches what the panel fetches today, and
nothing else the rebuild draws calls `fetch`.

## Alternatives

**Keep the palette-only nav and the 1280px column.** It costs nothing to build, and ADR 0053 answered the unread
count, the phone and discovery with the jump dot, the slash button and the empty query. It lost on the two faults
that #744 names: a 4K screen wastes most of its width, and twenty flat sections hide what needs attention.

**An opt-in v3 layout, or a settings flag.** Either lets the old and new admin run side by side. Both lost to
rebuilding in place: two layouts would each need their own specs and styles until one went, and the whole
redesign ships in one milestone anyway.

## Consequences

The chrome now reaches every screen without scripts. ADR 0053 left the jump and slash buttons as `type="button"`,
so without scripts a section was reached by typing its address.

Lines run long at 4K. Prose keeps its 44em measure, but anything in a card that never opted in, such as a
table cell or a meta line, stretches with the window.

The top bar is sticky, so it takes height on every screen, and side columns stick under it at 86px.

Screens look mixed until the milestone ends. We rebuild one screen at a time inside the new shell, and each keeps
its old layout until its turn.

`e` means two things. It edits on a task row and opens anywhere else, so the key help shows whichever the screen
has.

The handoff's key list, palette and route map live in `tmp/design/`, which the repository does not keep. Once the
rebuild lands, the README's table of pills and sub-tabs survives only in the code.

[0034]: 0034-hold-every-page-to-a-1040px-column-and-prose-to-its-own-measure.md
[0053]: 0053-navigate-the-admin-through-a-command-palette-not-a-tab-strip.md
[0054]: 0054-run-every-admin-screen-on-a-phone.md
[0055]: 0055-make-every-admin-write-a-plain-form-post-that-scripts-only-add-to.md
[0071]: 0071-load-a-tasks-read-and-edit-pages-into-dialogs-with-fetch.md
[0096]: 0096-search-every-kind-through-tsvector-columns-and-one-view-in-a-search-slice.md
[0101]: 0101-bind-every-admin-key-through-one-key-map-that-reads-keys-from-the-markup.md
[0118]: 0118-keep-admin-pages-live-through-postgres-notify-a-hijacked-event-stream-and-a-morph.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
