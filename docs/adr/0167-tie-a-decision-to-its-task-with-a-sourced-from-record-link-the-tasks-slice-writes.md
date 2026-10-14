---
id: "0167"
title: Tie a decision to its task with a sourced from record link the tasks slice writes
status: active
created: 2026-10-14
area: [db, decisions, links, tasks]
issue: "#1324"
tags: [decisions, tasks, links, record-links, schema, enums, constraints, slices, transactions]
---

# ADR 0167: Tie a decision to its task with a sourced from record link the tasks slice writes

![Active][status]

## Context

Spec #1323 opens a task at the end of the next list for each new decision, titled `Resolve decision #123: <title>`. The
task follows the decision. A rename renames it, a resolve completes it, a drop cancels it, and a reopen reopens it,
or adds a new one if the owner deleted the old one. Nothing the owner does to the task changes the decision.

The site has to tell its own task from tasks the owner links to the decision by hand, and only its own task follows
the decision. The spec rules out new fields on tasks. A record link joins a task and a decision today, but it is an
unordered pair with no type ([ADR 0093][0093]), so a plain link can't say which task the site made.

`links` owns `record_links` and imports `repos.decision_queries` from `decisions`, so `decisions` can't call a
`links` operation without a cycle [ADR 0123][0123] forbids. `tasks` already writes `record_links` when a task rule
links tasks to projects ([ADR 0122][0122], [ADR 0021][0021]). It imports from `media`, `projects` and `record`, and
none of those import from `decisions`.

## Decision

**A record link carries a relation.** A new migration adds a `record_link_relation` enum (ADR 0015) with `related`
and `sourced_from`, and a `relation` column on `record_links` that defaults to `related`. Every link made so far, and
every link `Links::Operations::LinkRecords` makes, is `related`, so the owner can't make a `sourced_from` link by
hand.

**The pair stays sorted, and the left side is sourced from the right.** `task` sorts before `decision` in
`record_kind`, so the task is the left side and the decision the right. A check, `record_links_sourced_from_check`,
holds a `sourced_from` link to a task on the left and a decision on the right. `record_links_pair_key` still holds
one link per pair, whatever its relation.

**A decision has at most one sourced task.** A partial unique index on `(right_kind, right_id)` where the relation
is `sourced_from` holds it.

**`tasks` writes the link, and `decisions` calls it.** `tasks` exports the operations that open, rename, close and
reopen a decision's task, and writes the link through `Tasks::Relations::RecordLinks`, as it writes project links.
`decisions` imports them. Each one runs inside the decision operation's transaction, which `Blog::Operation` nests as
a savepoint, the way `AddDecisionComment` calls `media.operations.claim_photos`. A failure rolls back the decision
with the task, as [ADR 0165][0165] does for a series.

**The link is the only tie.** A deleted task takes its link with it through the `tasks_drop_record_links` trigger, so
a reopen that finds no `sourced_from` link opens a new task. An unlink by hand cuts the tie the same way. The Linked
section lists the link like any other.

## Alternatives

**A decision id on tasks.** It would need no change to links. It lost in the #1323 brainstorm: the owner wants no
new fields on tasks, and a record link already ties the two.

**Let `links` write the link.** `links` owns the table, so the write would stay in its slice. It lost because
`decisions` calling `links` closes a cycle with `links` reading `decisions`, and ADR 0123 allows only its three named
cycles.

## Consequences

`decisions` gains its first import from `tasks`. An import from `tasks` back to `decisions`, or to any slice that
imports `decisions`, now closes a cycle.

`record_links` takes writes from `links` and from two paths in `tasks`, and ADR 0021 lists both.

Every decision operation that touches the task now writes in two slices' tables, and its specs need both slices'
rows. A new way to open, edit, resolve, drop or reopen a decision has to call the tasks side, or the task falls out
of step.

The left to right rule rides on the order of `record_kind`. A future `sourced_from` pair whose source kind sorts first
can't use it as it stands, and needs the check, and maybe a new relation value, changed in a new migration.

A link's relation does not show in the Linked section, so the owner can unlink the site's task without knowing it
was the site's. The task then stops following the decision.

[0021]: 0021-let-sql-read-another-slices-tables-never-write-them.md
[0093]: 0093-link-any-two-records-through-one-record-links-table-in-a-links-slice.md
[0122]: 0122-widen-task-tag-rules-into-task-rules-that-assign-projects-and-match-a-projects-repo.md
[0123]: 0123-export-only-read-repos-and-operations-and-keep-write-repos-in-their-slice.md
[0165]: 0165-keep-task-recurrence-in-a-series-beside-tasks-and-copy-the-last-task-when-it-closes.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
