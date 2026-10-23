---
id: "0160"
title: Open a public page for each task on a published board, without its tags or time
status: active
created: 2026-10-14
area:
  - public
issue: "#1182"
amended:
  - "#1315"
  - "#1656"
  - "#1947"
tags:
  - projects
  - tasks
  - kanban
  - board
  - public
  - privacy
  - visibility
  - notes
  - comments
  - links
  - sources
  - tags
---

# ADR 0160: Open a public page for each task on a published board, without its tags or time

![Active][status]

## Context

[ADR 0157][0157] publishes a project's tasks on a read-only board at `/projects/:slug`, and keeps each card to its
number, title, and done or canceled date. The cards are not links, so a visitor who wants to know what a task is
about, why it waits or where its work lives has no way in. Spec #1181 asks for a page for each task.

A task holds more than its card shows: notes, cleaned by the sanitize gem ([ADR 0072][0072]), local and synced
comments ([ADR 0075][0075]), links to other tasks ([ADR 0117][0117]), a source issue, private tags
([ADR 0074][0074]) and time.

## Decision

**Each card on a published board links to a page for its task**, at `/projects/:slug/tasks/:number` in the public
slice. A board is published as ADR 0157 says: the project is public and its board flag is on. Since #1315 `:number`
is the task's number within that project, not its internal id, and the page answers 404 for a number the project
lacks ([ADR 0166][0166]).

**The page shows everything but tags and time.** It shows the number, title, status, column, done or canceled
date, notes cleaned as ADR 0072 cleans them, comments, related tasks named by how each relates, and a link to the
source issue. Since #1656 the site serves visitors the photos the notes and comments show ([ADR 0080][0080]). It
never shows tags, since every task tag is private, or time and work hours. Since #1947 a published board's
project tags are public and show on its cards ([ADR 0205][0205]), but this page still leaves them out.

**A related task shows only when it sits on a published board of a public project.** The page leaves out every
other link, so a private task's title never reaches the page through a relation.

**A task on no published board of a public project answers 404**, as does a page whose project is not published.

## Alternatives

**Keep the cards as they are.** A visitor still could not learn more than a title.

**Show every related task.** A link to a task on no published board would put a private title in public.

## Consequences

Publishing a board now publishes each task's notes, comments and the photos in them as well as its title. Synced
notes and comments show as GitHub or Linear holds them, so text written for a private issue reaches the public site.
Cloudflare keeps a photo for a day ([ADR 0109][0109]), so one from a board taken down stays at the edge that long.

A source issue in a private repository shows as a link a visitor cannot open.

A reader sees only the relations to published tasks, and nothing says some are missing.

Cloudflare keeps the page for five minutes, as it keeps the board ([ADR 0090][0090]), so a task that leaves a board,
or a project that goes private, stays readable that long.

[0072]: 0072-render-raw-html-in-task-notes-through-the-sanitize-gem.md
[0074]: 0074-split-tags-into-a-public-and-a-private-scope.md
[0075]: 0075-keep-local-and-synced-task-comments-in-one-table-keyed-by-remote-id.md
[0080]: 0080-store-photos-in-an-s3-store-and-serve-them-through-the-site.md
[0090]: 0090-let-cloudflare-keep-anonymous-public-pages-for-five-minutes.md
[0109]: 0109-let-cloudflare-keep-a-published-photo-for-one-day.md
[0117]: 0117-sync-task-relations-into-task-links-with-a-parent-type-and-a-synced-flag.md
[0157]: 0157-publish-a-projects-tasks-through-its-board-flag.md
[0166]: 0166-give-each-task-one-project-and-a-number-postgres-gives-out-within-it.md
[0205]: 0205-give-each-project-its-own-tags-through-a-project-scope-on-tags.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
