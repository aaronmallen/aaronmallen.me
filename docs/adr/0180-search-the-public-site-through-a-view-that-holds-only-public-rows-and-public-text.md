---
id: "0180"
title: Search the public site through a view that holds only public rows and public text
status: active
created: 2026-10-15
area:
  - db
  - public
issue: "#1465"
amended:
  - "#1947"
tags:
  - search
  - postgres
  - full-text
  - view
  - public
  - privacy
  - visibility
  - posts
  - projects
  - tasks
  - tags
---

# ADR 0180: Search the public site through a view that holds only public rows and public text

![Active][status]

## Context

Spec #1461 gives visitors a `/search` page. The admin search from [ADR 0096][0096] runs on one
`search_documents` view that unions thirteen kinds with no public filter: drafts, scheduled posts, private
projects, tasks on unpublished boards, mail and the journal all sit in it. A visitor who saw one of those in a hit,
an excerpt or a count would learn something the site never meant to show.

## Decision

**One rule decides what a visitor can find: a record is searchable only if it has a public page, and only through
the text that page shows.**

- Posts: published only.
- Projects: public ones, archived public projects among them.
- Tasks: on a published board of a public project ([ADR 0157][0157]), matched on title and notes. Never tags or
  time, which the task page leaves out ([ADR 0160][0160]).
- Public tag names on posts and projects match. Task tags are private ([ADR 0074][0074]) and never match. Since
  #1947 project tags never match either, on a task or a post ([ADR 0205][0205]).

**A new `public_search_documents` view holds only those rows and that text.** The public slice reads this view and
no other for search. Hits, counts, ranking and paging all come from it, so a count cannot hint at a private record.
A kind or a column joins the view only when a public page shows it.

## Alternatives

**A `public` scope on `search_documents`.** It reuses one view, but every public query would have to call the
scope, and one that forgot would leak. The view also lacks the columns a scope would test, such as whether a project
is public or a board published, so it would have to widen first.

**Merge per-slice public queries in Ruby.** Each slice already knows what it publishes. Ranking, counts and paging
would then run on rows pulled into memory, which ADR 0096 turned down for the admin search.

## Consequences

A query that forgets a filter cannot leak, since the view holds nothing private to leak.

The view repeats each slice's publish rule in SQL. When a rule changes, such as what makes a board published, the
view needs a new migration in step with it, or search and the page disagree.

Postgres refuses to change a column the view reads, as with `search_documents`, so a migration that touches one
rebuilds both views.

[0074]: 0074-split-tags-into-a-public-and-a-private-scope.md
[0096]: 0096-search-every-kind-through-tsvector-columns-and-one-view-in-a-search-slice.md
[0157]: 0157-publish-a-projects-tasks-through-its-board-flag.md
[0160]: 0160-open-a-public-page-for-each-task-on-a-published-board-without-its-tags-or-time.md
[0205]: 0205-give-each-project-its-own-tags-through-a-project-scope-on-tags.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
