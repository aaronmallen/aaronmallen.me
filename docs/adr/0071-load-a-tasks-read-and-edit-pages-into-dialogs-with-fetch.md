---
id: "0071"
title: Load a task's read and edit pages into dialogs with fetch
status: active
created: 2026-09-29
area: [admin, assets]
issue: "#37"
amended: ["#41"]
tags: [admin, tasks, dialog, fetch, javascript, forms, progressive-enhancement]
---

# ADR 0071: Load a task's read and edit pages into dialogs with fetch

![Active][status]

## Context

A task has no read mode. `Admin::UI::Components::Tasks::Row` opens `Tasks::Editor`, a form under the row, from a
hidden checkbox and CSS. A failed save or a failed link renders the whole tasks index again, with `editing:` or
`linking:` naming the row to open. Spec #36 gives each task a panel that slides in from the left to read it, and
edits it in the task modal that creates tasks. Rows draw on the tasks page tabs, the Today card on `/admin` and
the completed archive, and the panel opens from all three.

ADR 0055 holds that row editors open from a checkbox with no script, and that only the two post previews call
`fetch`. The panel and the modal need both parts to change. The rest of ADR 0055 stands: every write is a plain
form POST.

## Decision

Each task has two pages of its own: `GET /admin/tasks/:id` to read it and `GET /admin/tasks/:id/edit` to edit
it. Both are full admin pages, and a row's title links to the read page.

A script in `app/assets/js/admin` takes the click on those links, fetches the page with a `GET`, and swaps the
task's part of the page into a native `dialog`: the read page into the panel, the edit page into the task modal.
A linked task clicked inside the panel loads into the same panel. With scripts off, or when the fetch fails, the
link opens the page in full.

Every form inside the swapped HTML stays a plain POST under ADR 0055. An action redirects with its toast to the
page the task was opened from, through the `origin` the forms carry. A failed save answers 422 with the edit
page.

One write goes through `fetch`, which #41 added. In the modal, the script sends the edit form's own fields to the
form's own action. A 422 swaps the edit page's form into the modal, errors and all. A redirect loads the page the
modal opened on, and the toast the redirect set shows there. Any other answer, or a failed request, falls back to
posting the form. With scripts off, the form posts as before, and the server needs no second way to answer.

## Alternatives

**A hidden panel and a filled edit form inside every row.** Each row draws its task's note, links, link controls
and every field of the edit form, and a checkbox or a script shows them. It lost because every list pays for
panels nobody opens: the tasks tabs, Today and the archive would each load and draw every task's links, source
and form on each page load. It also gives no task an address of its own.

**A `?task=` param and a full reload.** The list page reads the param and draws the panel open. It lost because
the tasks page, `/admin` and the archive would each have to read the param, load the task and draw the panel, and
every open, and every click on a linked task, reloads the whole list and loses the operator's place.

**A failed save that leaves the modal for the full edit page.** Every save stays a plain POST, and the 422 page
shows the errors. #37 chose it, and #41 turned it down, since spec #36 asks for a failed save to show its errors in
the modal.

## Consequences

One page per task serves the panel, the modal, a pasted link and a browser with no script. The request specs
drive those pages with rack-test like any other.

Opening a task costs a round trip, and the panel stays empty until the reply lands. Each reply carries the whole
admin layout, which the script throws away.

The script and the pages must agree on which part of the page to swap. A change to the page's markup can break
the panel while the page itself still works, and only a browser spec will catch it.

The setup functions in `app.js` bind once, to what the page held at load. Controls inside swapped HTML, such as
the copying task key and `confirm.js` on a delete, do nothing until the script binds them again or they listen on
the document.

A failed save keeps the operator in the modal, but only because the script reads the page the server renders for
a plain POST. A change to that page's markup can break the modal while the page itself still works.

The script cannot read where a redirect points without following it, and following it spends the toast. It sets
`redirect: "manual"` and loads the page it is on instead. That page and the redirect's target agree for every
list a row draws on, except that the reload keeps a search or a pool the redirect would drop.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
