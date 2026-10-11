---
id: "0153"
title: Update admin row actions and filters in place by fetch and morph, and let them need scripts
status: active
created: 2026-10-11
area: [admin, assets]
supersedes: ["0055"]
issue: "#1126"
tags: [admin, forms, filters, javascript, fetch, idiomorph, morph, toast, history, noscript]
---

# ADR 0153: Update admin row actions and filters in place by fetch and morph, and let them need scripts

![Active][status]

## Context

[ADR 0055][0055] makes every admin write a plain form post that scripts only add to, and gives every filter a
`noscript` submit button. So starting, pausing or moving a task, pulling it into a sprint, or changing a filter on the
activity view reloads the whole page. Spec #1120 asks that anything short of an outright form submission update in
place, and the owner said a converted control need not work with scripts off.

[ADR 0118][0118] already refetches the page and morphs it with idiomorph when the event stream says something changed,
keeps Phlex the only renderer, and runs every module's setup again on `admin:morphed`. Each row action already answers
with a redirect and sets its toast in the flash, and a filter is an `Admin::UI::Components::AutoForm` that
`autosubmit.js` submits as a GET.

## Decision

This record replaces the part of ADR 0055 that covers row actions and filters. Create and edit forms stay full posts,
and the rest of ADR 0055 holds.

**Row actions post by fetch and morph the page they land on.** A form opts in through a data attribute. A script posts
it by `fetch`, follows the redirect, morphs the page from the answer the way `live.js` does, and shows the toast that
page carries. The actions do not change: they keep their redirects and their flash. A failed action shows its error
toast and leaves the page as it was. This covers task controls and the row actions on the inbox, posts, messages,
calendar, webmentions, links, sessions, comments and sprints.

**Filters fetch the filtered page and morph it in.** `autosubmit.js` fetches the form's GET URL, morphs the results,
and sets the address with `history.replaceState`, so the view stays linkable, saved views read the new query, and Back
leaves the page. `AutoForm` drops its `noscript` submit button.

**Both may need scripts.** With scripts off, nothing promises a row action or a filter works.

## Alternatives

**Keep a no-JS fallback.** Every converted control would carry a second path, such as the `noscript` buttons, and
specs for both. The owner turned it down in #1120.

**Answer 204 and let the event stream refresh.** Each action would change its answer, and the toast rides on the
redirect's flash, so it would show nowhere. The page would also wait on the trigger, the hub and the refetch before it
moved.

**Render fragments per action.** Each action would need a second answer that draws only the parts it changed, and it
would have to know every part the change reaches, such as the sprint pool and the counts. Morphing the whole page the
redirect lands on needs neither, and keeps one way to render a page.

## Consequences

A row action or a filter no longer reloads the page, so scroll, focus and open dialogs survive it. The actions keep
their redirects, so the request specs still drive them with rack-test, but the update in place shows only in browser
specs.

With scripts off a filter has no button to apply it.

A row action renders two pages: the one its redirect lands on, and the one the event stream refetches when the
trigger fires.

The toast comes from the flash of the page the redirect lands on, so the race [ADR 0118][0118] names still holds: a
refetch in another tab can read it first, and then it never shows.

[0055]: 0055-make-every-admin-write-a-plain-form-post-that-scripts-only-add-to.md
[0118]: 0118-keep-admin-pages-live-through-postgres-notify-a-hijacked-event-stream-and-a-morph.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
