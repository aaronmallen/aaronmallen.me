---
id: "0103"
title: Tag an imported task from repo rules on import, and once when a rule is saved
status: active
created: 2026-10-03
area: [db, record, tasks]
issue: "#389"
tags: [tasks, tags, rules, imports, sync, github, linear, providers, repos]
---

# ADR 0103: Tag an imported task from repo rules on import, and once when a rule is saved

![Active][status]

## Context

Spec #388 gives each repo the private tags its issues should carry, such as `ruby` and `projects`. Today the sync
tags a task only from its labels, so the owner tags every new issue by hand. On 2026-10-03, 19 tasks needed it.

[ADR 0077][0077] tags a task from its labels once, in `Tasks::Operations::SyncIssues#import`, and never creates a
tag, so a tag the owner removes stays gone. [ADR 0070][0070] keeps every field that belongs to one provider in that
provider's client. [ADR 0066][0066] keeps an imported task's origin, URL included, in `task_sources`.

## Decision

**Rules live in their own table in the `tasks` slice.** A rule holds a pattern and its tags. A pattern names one
repo (`owner/name`) or every repo of an owner (`owner/*`), and ignores case. A rule's tags sit in a join table to
private tags, the way `task_tags` holds a task's. Rules stack: an issue takes the tags of every rule it matches.

**Each client hands over a neutral origin.** The GitHub client sets `origin` to the issue's `nameWithOwner`. The
Linear client sets none, so Linear issues match no rule. `SyncIssues` reads `origin` without knowing which provider
filled it.

**Rule tags join label tags at import.** `import` adds the tags of every matching rule beside the label tags, in the
same transaction. `follow` reads no rule, so a tag the owner removes stays off, as [ADR 0077][0077] holds for labels.

**Saving a rule creates its tags and tags existing tasks once.** The save creates any tag the rule names that does
not exist, as a private tag. Then it adds the rule's tags to every task already imported from a
matching repo, found by the repo in `task_sources.url`. After that, only new imports take the rule's tags. Deleting a
rule, or dropping a tag from one, takes no tag off any task.

The admin calls these operations to save and delete rules, and the MCP reaches the same operations through the API,
as [ADR 0088][0088] says.

## Alternatives

**A field on projects.** A project already holds a `repo`, so it could hold that repo's tags too. It lost because a
project names one repo and cannot say `owner/*`, a repo with no project could take no tags, and the owner means to
rename projects or make them private apart from this work.

**A map in the settings file.** Repo patterns and tags sit in `config/settings`. It lost because a change would take
a deploy, the owner wants to edit rules in the admin and the MCP, and the one pass over existing tasks has no save to
run from.

**A tagging job after each sync.** The import stays as it is, and a job tags new tasks from the rules. It lost for
the reason [ADR 0077][0077] turned down a job for labels: the owner could remove a tag before the job ran, and the
job would add it back.

## Consequences

The owner sets a repo's tags once, and every new issue from it arrives tagged.

The one pass on save reads the repo from `task_sources.url`, so it depends on GitHub's URL shape, and imports read it
from `origin`. The two can disagree, and nothing checks them against each other.

The pass on save runs on every save, edits included, so it brings back a rule's tag on any matching task the owner
took it off.

Nothing records which tags came from a rule, a label or the owner, so no later change can tell them apart.

A new provider that wants rule tags has to hand over an `origin` in the same `owner/name` shape.

[0066]: 0066-keep-an-imported-tasks-origin-in-a-task-sources-table.md
[0070]: 0070-share-one-issue-sync-across-providers-and-run-each-provider-as-its-own-job.md
[0077]: 0077-tag-an-imported-task-from-its-labels-only-on-import.md
[0088]: 0088-hold-the-layer-the-api-and-mcp-share-in-the-api-slice-and-call-it-in-process.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
