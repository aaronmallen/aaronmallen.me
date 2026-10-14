---
id: "0157"
title: Publish a project's tasks through its board flag
status: active
created: 2026-10-12
area: [db, admin, api, mcp, projects, public]
issue: "#1163"
amended: ["#1182", "#1315"]
tags: [projects, tasks, kanban, board, public, privacy, visibility, tags]
---

# ADR 0157: Publish a project's tasks through its board flag

![Active][status]

## Context

Tasks have never shown on the public site. Spec #1162 lets a visitor see what I am working on through a read-only
board at `/projects/:slug`, using the slug made from the project's name. A project already holds a visibility of
public or private and an archive date, kept apart by [ADR 0119][0119]. Tasks carry only private tags
([ADR 0074][0074]).

## Decision

**A flag on the project publishes its tasks.** Projects gain a "Publish Kanban" flag, saved from the project editor
and carried by `save_project`, `read_project` and `list_projects`. It stands beside visibility and the archive date.

**A project shows its board when it is public and the flag is on.** Archived public projects keep their board. A
private project, or one without the flag, reads "That board isn't public." at its board URL.

**A published board shows every linked task, and little of each.** A card shows the task's number, title, and its
done or canceled date. It shows no tags, notes, comments, time or issue links. Since #1182 each card links to a
page for its task that shows its notes, comments, related tasks and issue link, but no tags or time, as
[ADR 0160][0160] records. Since #1315 a task sits on one board at most, the one in `tasks.project_id`, and its
card shows its `KEY-n` label ([ADR 0166][0166]).

## Alternatives

**A public flag on each task.** I would have to mark each task by hand, and a board would show a partial set of its
tasks. The flag on the project decides once for all of them.

**Hide tasks by tag.** A task would go public unless I remembered to tag it, and the tag would steer a page that
shows no tags.

## Consequences

Turning the flag on publishes every task ever linked to the project, past ones too, and every task linked later. A
task linked to a published project shows in public whatever it says, so its title has to be fit to read.

Cards show no tags, since every task tag is private.

Cloudflare keeps the board for five minutes ([ADR 0090][0090]), so a card move or turning the flag off reaches
visitors late.

[0074]: 0074-split-tags-into-a-public-and-a-private-scope.md
[0090]: 0090-let-cloudflare-keep-anonymous-public-pages-for-five-minutes.md
[0119]: 0119-mark-a-project-archived-by-its-archive-date-and-keep-visibility-in-its-own-enum.md
[0160]: 0160-open-a-public-page-for-each-task-on-a-published-board-without-its-tags-or-time.md
[0166]: 0166-give-each-task-one-project-and-a-number-postgres-gives-out-within-it.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
