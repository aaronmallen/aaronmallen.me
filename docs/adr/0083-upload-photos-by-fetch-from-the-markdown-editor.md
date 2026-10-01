---
id: "0083"
title: Upload photos by fetch from the Markdown editor
status: active
created: 2026-09-30
area: [admin, assets]
issue: "#135"
tags: [media, photos, uploads, fetch, javascript, forms, markdown, editor, progressive-enhancement]
---

# ADR 0083: Upload photos by fetch from the Markdown editor

![Active][status]

## Context

Spec #128 lets the writer drag, paste or pick a photo in any Markdown editor in the admin. A placeholder shows at
the cursor while the photo uploads, then turns into `![](url)`. If the upload fails, the placeholder goes and the
editor says why.

[ADR 0055][0055] makes every admin write a plain form POST that scripts only add to, so that each write works with
scripts off. [ADR 0071][0071] made one exception, for the task modal, and that form still posts in full without a
script. An upload cannot keep to the rule the same way: its result is a URL that has to land at the cursor of a
form the writer has not saved yet.

## Decision

The Markdown editor uploads a photo through `fetch`, and the upload needs scripts.

`markdown_editor.js` (#129) takes the drop, the paste or the file the toolbar picks, and posts the photo to an
upload endpoint in the admin slice with the editor's CSRF token. The endpoint answers with the photo's URL, or with
a message saying why it refused the file. The script puts the URL into the textarea at the cursor, or shows the
message.

The endpoint is a POST behind sign-in like every other admin write, but it answers with data for the script to
insert, not with a page or a redirect.

## Alternatives

**An upload form with no script.** The writer posts the photo from a form of its own, and the server redirects
back with the URL for the writer to paste by hand. It keeps the rule in ADR 0055, but costs a second screen and a
round trip away from the draft, all for a writer with scripts off, a case that does not come up.

## Consequences

Photos go in where the writer is typing, and the draft never leaves the page.

With scripts off, the editor takes no photo. The writer can still link by hand to one hosted somewhere else.

The server gains a second way to answer a write, the cost ADR 0055 names for writes through `fetch`. The request
specs can still post to the endpoint with rack-test, but only a browser spec covers the drop, the paste and the
insert at the cursor.

[0055]: 0055-make-every-admin-write-a-plain-form-post-that-scripts-only-add-to.md
[0071]: 0071-load-a-tasks-read-and-edit-pages-into-dialogs-with-fetch.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
