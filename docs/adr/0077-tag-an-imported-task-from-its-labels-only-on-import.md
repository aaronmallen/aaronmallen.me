---
id: "0077"
title: Tag an imported task from its labels only on import
status: active
created: 2026-09-29
area: [record, tasks]
issue: "#107"
amended: ["#389"]
tags: [tasks, tags, labels, imports, sync, github, linear, providers]
---

# ADR 0077: Tag an imported task from its labels only on import

![Active][status]

## Context

Tasks imported from GitHub and Linear arrive with no tags, even when an issue carries a label that matches one of
the operator's private tags (ADR 0074). #106 has the sync add those tags. The sync runs every 15 minutes, and the
operator removes tags from imported tasks by hand. A tag the operator removed has to stay gone.

ADR 0068 has the sync act on a change in an issue's state, not on the state itself, and ADR 0070 keeps each
provider's fields in its client.

## Decision

Tags come from labels once, when `Tasks::Operations::SyncIssues#import` creates the task, in the same transaction.
`follow` never reads labels and never touches tags, so no later sync adds or removes one.

Each client hands the operation an issue's labels. A Linear label in a group counts by its child name alone. A label
adds an existing private tag whose name it turns into. It never creates a tag, and it never adds a public one.

Repo rules, added by #389, put their tags beside label tags in the same `import` ([ADR 0103][0103]). Rule tags differ
from label tags in two ways: saving a rule creates any tag it names, and creating one tags once every task already
imported from a matching repo.

## Alternatives

**Tag on every sync.** Each run adds the tags the issue's labels match. It lost because it brings back every tag
the operator removes, 15 minutes later.

**Store labels on `task_sources`.** Keep the last labels seen, and add a tag only when a label appears, the way ADR
0068 follows state. It lost because it adds a column no feature needs yet.

**Tag in a job queued after import.** The import stays as it is, and a second job adds the tags. It lost because
the operator could remove a tag before the job ran, and the job would add it back.

## Consequences

A tag the operator removes stays off.

A label added upstream after import never reaches the task, and neither does a tag created after it. Tasks imported
before #106 keep no tags from labels. Nothing records which tags came from a label.

With no labels stored, a later feature that follows labels, or tags tasks already imported, has to fetch them from
the providers again, or first add the column this record turned down.

A task the operator deletes and the sync brings back counts as a new import, so it takes its tags again.

[0103]: 0103-tag-an-imported-task-from-repo-rules-on-import-and-once-on-create.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
