---
id: "0148"
title: Edit a task in the task drawer, and keep the task modal for new tasks
status: active
created: 2026-10-11
area:
  - admin
  - assets
issue: "#1102"
tags:
  - admin
  - tasks
  - drawer
  - dialog
  - forms
  - progressive-enhancement
  - design
---

# ADR 0148: Edit a task in the task drawer, and keep the task modal for new tasks

![Active][status]

## Context

[ADR 0071][0071] gives each task a read page and an edit page, and a script loads the read page into the task panel
and the edit page into the task modal. [ADR 0128][0128] made the panel a wide drawer on the right and kept the edit
page in the modal. To edit a task, the owner leaves the drawer: Edit closes it and opens the form in the modal.

Spec #1101 brings the drawer up to the design in `tmp/design/assets/admin3-task.jsx`. There the drawer has a header
bar, a body that scrolls and a footer that stays put, and it edits the task without leaving.

## Decision

**A task edits in its drawer.** Edit, or `E` with no field in focus, swaps the drawer's read blocks for the edit form
and its footer for Cancel and Save. Save stores the task and returns the drawer to read mode with the new values. A
failed save keeps the drawer in edit mode and shows the errors, the way the modal does today. Cancel returns the
drawer to read mode unchanged. This replaces the part of ADR 0128 that kept the edit page in the task modal, and the
part of ADR 0071 that loads the edit page there.

**The edit page stays.** `GET /admin/tasks/:id/edit` remains a full admin page, so a browser with no script still
edits a task, and the drawer's form posts where that page's form posts. Every write in the drawer stays a plain form
POST under [ADR 0055][0055].

**The task modal creates tasks and nothing else.** New tasks open in it as they do today.

**The read page takes the drawer's layout.** `GET /admin/tasks/:id` draws the header bar, body and footer as a page,
centred. The drawer swaps all three when it moves to another task, so the header and footer never show a stale task.

## Alternatives

**Keep editing in the task modal.** ADR 0128 chose it, and it costs nothing more to build. It lost because editing
takes a trip out of the drawer, and the design edits in place.

**Drop the edit page.** With the form in the drawer, the page has no caller that runs scripts. It lost because a
browser with no script would then have no way to edit a task, and ADR 0055 asks every admin write to work without
one.

## Consequences

Editing no longer closes the drawer, so the owner keeps their place in the task and its timeline.

The edit form now serves the drawer and the full edit page. A change to its markup has to work in both, and only a
browser spec catches a drawer that breaks while the page still works, as ADR 0071 already warns for the read page.

The script swaps more of the drawer than before: header, body and footer, in read mode and in edit mode. Each swap
is one more place where the script and the page must agree on markup.

[0055]: 0055-make-every-admin-write-a-plain-form-post-that-scripts-only-add-to.md
[0071]: 0071-load-a-tasks-read-and-edit-pages-into-dialogs-with-fetch.md
[0128]: 0128-lay-out-the-admin-as-a-full-width-pill-nav-shell-with-right-side-drawers.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
