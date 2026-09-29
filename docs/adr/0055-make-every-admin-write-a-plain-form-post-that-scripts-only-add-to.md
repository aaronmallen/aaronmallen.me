---
id: "0055"
title: Make every admin write a plain form POST that scripts only add to
status: active
created: 2026-09-28
area: [admin, assets, lib]
issue: AA-676
amended: ["#37", "#41"]
tags: [admin, forms, javascript, routes, flash, toast, fetch, method-override]
---

# ADR 0055: Make every admin write a plain form POST that scripts only add to

![Active][status]

## Context

The admin writes posts, social posts, tasks, journal entries, tags, projects and settings. Its scripts in
`app/assets/js/admin` are small modules with no framework, working through data attributes and ARIA state
(AA-219). A write could go two ways: a form the browser posts and the server answers with a page, or a script that
sends the values with `fetch` and patches the page with the reply.

## Decision

Every admin write is an HTML form that posts to the server, and the server answers with a page. Scripts add to a
form. They never replace its submit, except in the task modal, where #41 lets a script send the same form.

- **Routes.** Every create, update and delete in `slices/admin/config/routes.rb` is a `post`, and an update or a
  delete names itself in the path, such as `post "/posts/:id/delete"`. `Blog::UI::Components::Form` takes only
  `get` and `post`, and writes the CSRF field for a post (AA-700).
- **Answers.** A good write sets the toast flash through `Admin::Action#toast` and redirects, so the toast shows on
  the next page (AA-219). A refused write renders the same page again with a 422 and the errors beside the fields,
  as `Admin::Actions::Tags::Create` does.
- **Filters** submit on change through `autosubmit.js`, and each carries a submit button inside `noscript`, as
  `Admin::UI::Views::Posts::Index` does.
- **Deletes** are real forms with `data-confirm`, and `confirm.js` stops the submit only when the operator says
  no.
- **`fetch` is for reads.** The two previews call it, `post_preview.js` (AA-229) and `post_syndication.js`
  (AA-336). Both post the unsaved form and swap in HTML while the operator types, and neither stores anything.
  A task's read and edit pages load into dialogs the same way, as [ADR 0071][0071] records. #37 replaced the
  row editor that opened from a checkbox, and the claim that only the previews call `fetch`. #41 added the one
  write: the task modal sends its edit form through `fetch` so a failed save stays in the modal. The form still
  posts in full with scripts off, and ADR 0071 records the cost.

We leave `config.actions.method_override` at Hanami's default, on. No form sends `_method`.

## Alternatives

**Writes through `fetch`.** A script posts the values and patches the page, with no reload. Every write would then
need a script to run at all, which the `noscript` buttons and real delete forms show the admin avoids. The server
would also need a second way to answer, in JSON, beside the page it already renders with errors and the redirect
that carries the toast.

**Hanami's `resources` with method override.** The router can draw `PATCH` and `DELETE` routes, and Hanami mounts
`Rack::MethodOverride` by default so a form can fake them with a hidden `_method` field. AA-331 named both as
what Hanami offers in place of the hand-written routes, and closed with the verb paths still standing and no
reason written down.

## Consequences

Each write works the same way, and the request specs drive the forms with rack-test, which runs no script. A
failed write keeps what the operator typed, since the server renders it back.

Every write reloads the page. The previews and the task dialogs are the only places that pay for a script to avoid
a reload. All but one only read: the task modal writes, so a failed save can keep it open (#41).

Four places break the rule today, and each fails with scripts off:

- A journal entry's Edit and Delete in `Admin::UI::Components::Journal::Entry` are `Button`s, which default to
  `type: "button"`, and only `journal.js` makes them act. Without it the entry cannot be edited or deleted.
- `Admin::UI::Components::Toast` renders the message `hidden`, and only `toast.js` shows it, so a good write
  says nothing.
- The social composer adds and removes thread parts only through a script, so a thread cannot grow past the parts
  the page drew.
- The command palette opens only from a script, and so does the quick add form inside it. The record on the
  palette holds that cost.

Method override costs a middleware on every request and gives nothing, since no form fakes a verb.

[0071]: 0071-load-a-tasks-read-and-edit-pages-into-dialogs-with-fetch.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
