---
id: "0164"
title: Cap board columns, grow each by URL param, and drop closed tasks after 14 days
status: active
created: 2026-10-14
area:
  - admin
  - public
  - tasks
  - config
issue: "#1268"
tags:
  - projects
  - tasks
  - kanban
  - board
  - paging
  - load-more
  - settings
  - position
  - completed-at
---

# ADR 0164: Cap board columns, grow each by URL param, and drop closed tasks after 14 days

![Active][status]

## Context

Each project board, in the admin and on the public site ([ADR 0157][0157]), draws every task linked to the
project in five columns ([ADR 0156][0156]). Nothing limits a column, so a project with a long history shows a long
backlog, and its done and canceled columns grow forever. Spec #1267 asks for short columns on both boards.

[ADR 0076][0076] pages flat lists by number, with older and newer links. A board is not one list: it is five side by
side, and each grows on its own.

The admin board refreshes itself through a morph whenever a task changes ([ADR 0118][0118]), and a card move
redirects back to the board. Open columns order by `position`, the same field that orders a task in its list or
sprint. Done and canceled order by `completed_at`, newest first, and reopening a task clears `completed_at`.

## Decision

**Each column shows at most 20 cards.** A column that holds more ends in a Load More control that shows the next 20
and says how many are left. Column totals and the facts bar count every task the board would show, not those on
screen.

**Each column keeps its size in its own URL param.** The live refresh, a reload and the move redirect carry the
params, so a grown column stays grown. On the admin board Load More fetches and morphs in place
([ADR 0153][0153]). On the public board it is a plain link and needs no script. This extends ADR 0076 with a third
shape for boards: grow one column, not page the whole list.

**A task that changes column goes to the top of its new column**, whatever moved it: the board, a sync or MCP. An
open column takes the task first by `position`. Done and canceled already put the newest close first. A task that
keeps its column keeps its place. This extends ADR 0156: a column change still runs the real task action, and that
action now sets the task's place as well.

**A closed task leaves both boards 14 days after its last close.** The age counts from `completed_at`, so a task
that reopens and closes again starts over. The task stays everywhere else: task lists, sprints, saved views, MCP,
the API and its own public page ([ADR 0160][0160]). Nothing gets deleted. Old closed tasks count toward neither the
totals nor Load More.

The cap and the age live in settings beside `page_size`.

## Alternatives

**Page each board by number, as ADR 0076 pages lists.** One `page` param would move all five columns at once, and
a new page would swap a column's cards out where Load More adds to them.

**Clear every closed task from the board once every 14 days.** The owner chose an age per task, counted from its
own close, so a task closed the day before a sweep does not vanish early.

**Hide old closed tasks everywhere.** The owner limited it to boards. A task list or MCP still needs to find what
closed last month.

**Count only the cards on screen in the column head.** The owner chose the real total, so a capped column does not
read as smaller than it is.

**Move only board moves to the top.** A task a sync or MCP started would land wherever its `position` put it, and
could sit hidden past the cap in a full column.

## Consequences

The admin board URL can carry five extra params, and every link, form and redirect that returns to the board has to
pass them on.

Putting a task at the top of an open column sets its `position`, which also moves it to the top of its list or
sprint. Every operation that changes a column has to set it, not only the board's.

A closed task leaves the board on its own, with no event, when it passes 14 days. The admin board shows it until
the next refresh or reload, and Cloudflare keeps the public board for up to five minutes ([ADR 0090][0090]).

Board queries need counts per column and a limit per column in place of one array grouped in Ruby.

[0076]: 0076-page-flat-lists-by-number-and-day-grouped-lists-by-whole-day.md
[0090]: 0090-let-cloudflare-keep-anonymous-public-pages-for-five-minutes.md
[0118]: 0118-keep-admin-pages-live-through-postgres-notify-a-hijacked-event-stream-and-a-morph.md
[0153]: 0153-update-admin-row-actions-and-filters-in-place-by-fetch-and-morph-and-let-them-need-scripts.md
[0156]: 0156-keep-a-board-stage-on-tasks-beside-their-status.md
[0157]: 0157-publish-a-projects-tasks-through-its-board-flag.md
[0160]: 0160-open-a-public-page-for-each-task-on-a-published-board-without-its-tags-or-time.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
