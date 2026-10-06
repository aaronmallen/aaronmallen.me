---
id: "0117"
title: Sync task relations into task_links, with a parent type and a synced flag
status: active
created: 2026-10-06
area: [db, admin, api, mcp, record, tasks]
issue: "#631"
tags: [tasks, links, relations, sync, github, linear, providers, schema, postgres, enums, imports]
---

# ADR 0117: Sync task relations into task_links, with a parent type and a synced flag

![Active][status]

## Context

Spec #630 pulls GitHub and Linear relations into the app. The sync brings in an issue's title, body, state and
comments, but no relations, so a task blocked upstream reads as unblocked here and a sub-issue shows no parent.
Relations flow in only.

[ADR 0051][0051] stores each task link once per pair in `task_links`, typed `blocks`, `relates` or `duplicates`, and
derives the reverse on read. [ADR 0075][0075] keeps synced comments beside local ones, and the sync changes only the
synced rows. [ADR 0070][0070] cancels a synced task whose issue is taken off the operator (`unassigned`).
[ADR 0066][0066] finds a task by provider and remote id in `task_sources`.

Three choices shape the work in #632 to #635: how a parent is stored, how the sync tells its links from the
operator's, and what happens to an issue at the other end of a relation that is not assigned to the operator.

## Decision

**A parent is a `parent` link in `task_links`.** #632 adds `parent` to `task_link_type`, in a migration of its own
from `20261006000632` on ([ADR 0015][0015]). A parent row runs from parent to child, and reads "parent of" from the
`from_task_id` end and "child of" from the `to_task_id` end, wherever links show: the admin, the API and MCP. A
partial unique index on `to_task_id` where `type = 'parent'` holds a task to one parent. The pair index from
[ADR 0051][0051] still holds, so a parent and its child share no other link.

**A synced flag marks the links the sync owns.** #632 adds `synced boolean NOT NULL DEFAULT false` to `task_links`.
`LinkTasks`, behind the admin, the API and MCP, makes hand-made links and leaves it false. The sync writes `true`,
and adds, changes and deletes only rows where it is true. A pair that holds a hand-made link gets no synced link,
since the pair index refuses a second row and the sync skips the pair.

**Each client hands over relations as kind and remote id.** `Record::GitHub::Issues` (#633) and
`Record::Linear::Issues` (#634) add `relations` to every issue they return: an array of `{kind:, remote_id:}`, where
`kind` is one of `blocks`, `blocked_by`, `relates`, `duplicates`, `duplicated_by`, `parent_of` and `child_of`,
named from the issue's own side. GitHub maps blocking, blocked by, parent and sub-issues, and skips tracked by.
Linear maps `blocks`, `related`, `duplicate`, parent and children, from `relations` and `inverseRelations`, and skips
`similar`. Each relation connection rides inside the issue's fields and reads one page, as comments do. A client
that cannot read every relation of an issue leaves `relations` out, and the sync leaves that task's links alone, as
`SyncComments` does for an issue with no `comments`. The listing walks stay on `Record::Paging`, which both clients
share.

**`SyncIssues` mirrors relations after the run's imports, for open tasks only.** #635 resolves each `remote_id`
through `task_sources` under the run's provider, so the links of two issues imported in one run land in that run. For
each task still open after the run follows it, the sync turns every relation into one synced row (`blocked_by` as a
`blocks` row from the other end, and so on), updates a synced row whose type changed, and deletes each synced row
touching the task that no relation names. A closed task keeps its links, and the sync reads none of its relations,
as `SyncComments` skips a closed task's comments. When upstream gives one pair two kinds, `parent` wins, then
`blocks`, `duplicates` and `relates`.

**The other end of a relation comes in one hop out.** When no task holds a relation's remote id, the sync imports
the issue through `client.issues` and the usual `import`, so labels and tag rules apply as for any import
([ADR 0103][0103], [ADR 0112][0112]). Only relations of assigned issues import. Relations of an issue the sync reads
through `client.issues` link to tasks already here and pull in nothing new, which stops the walk at one hop on every
run, not only the first.

**A task held by a synced link stays open while unassigned.** `SyncIssues` reads `unassigned` as `open` for a task
that holds a synced link, and stores `open`. Once its last synced link goes, the next run sees `unassigned` and
cancels it, as [ADR 0070][0070] says, which #631 amends.

## Alternatives

**A `parent_id` column on `tasks`.** It holds one parent with a plain foreign key. It lost because every reader of
links would then read two places, and the admin, API and MCP would each need a second editor and a second label
path for one more kind of link.

**A mirror table of upstream relations.** The sync would own its table and never meet a hand-made link. It lost
because `blocked?` and every link reader would then merge two tables, the cost [ADR 0075][0075] turned down for
comments.

**Cancel an unassigned relation import, as for any synced issue.** It lost because the task would be canceled on the
run after it came in, and its links would point at a closed task the sync no longer reads.

**A column on `task_sources` marking a relation import.** It would keep a task open whether or not a link still holds
it. It lost because the synced links already say why the task is here, and a flag could outlive them.

## Consequences

`blocked?` and every link reader see synced links with no change, and a hand-made link always wins its pair.

A synced link the operator deletes comes back on the next run, and a hand-made link on its pair fails as `taken`
until the operator removes the synced one. A parent and child cannot also block each other.

A task that was assigned, holds a synced link and is then taken off the operator stays open, since the sync cannot
tell it from a relation import. Tasks imported one hop out fill the external list with issues the operator does not
own.

Each relation connection reads one page, so the links of an issue with more relations than a page holds stop
changing until it has fewer. The added fields raise the cost of GitHub's 100-node lookup and Linear's
25-issue page.

[0015]: 0015-type-a-closed-set-as-a-postgres-enum-and-a-format-as-a-domain.md
[0051]: 0051-store-a-task-link-once-and-derive-its-reverse-on-read.md
[0066]: 0066-keep-an-imported-tasks-origin-in-a-task-sources-table.md
[0070]: 0070-share-one-issue-sync-across-providers-and-run-each-provider-as-its-own-job.md
[0075]: 0075-keep-local-and-synced-task-comments-in-one-table-keyed-by-remote-id.md
[0103]: 0103-tag-an-imported-task-from-repo-rules-on-import-and-once-on-create.md
[0112]: 0112-give-every-tag-rule-a-provider-and-match-linear-issues-by-workspace-and-team.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
