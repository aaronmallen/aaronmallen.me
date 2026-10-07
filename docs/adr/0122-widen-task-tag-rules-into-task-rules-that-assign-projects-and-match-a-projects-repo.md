---
id: "0122"
title: Widen task tag rules into task rules that assign projects, and match a project's own repo
status: active
created: 2026-10-07
area: [db, admin, api, mcp, projects, record, tasks]
issue: "#660"
tags: [tasks, projects, tags, rules, imports, sync, github, linear, providers, repos, links]
---

# ADR 0122: Widen task tag rules into task rules that assign projects, and match a project's own repo

![Active][status]

## Context

Spec #645 asks for a synced issue to link to projects on import, the way it takes tags. The owner links each one by
hand today. A task links to a project through `record_links`, as [ADR 0093][0093] says.

[ADR 0103][0103] tags an imported task from rules in the `tasks` slice, and [ADR 0112][0112] gives each rule a
provider. A rule must hold at least one tag, which the `task_tag_rules_last_tag` trigger enforces. ADR 0103 turned
down rules on projects, since a project names one repo and cannot say `owner/*`. Yet an issue often comes from a
repo that some project already names in `projects.repo`, which is unique.

## Decision

**Tag rules become task rules.** A new migration renames `task_tag_rules` and `task_tag_rule_tags` to task rules and
adds a join table from a rule to projects. A rule still names a provider and a pattern, and holds tags, projects or
both. It must hold at least one of the two, so the trigger that keeps a tag on every rule now keeps a tag or a
project. A rule may name a private or archived project. The admin page, the API and the MCP tools take the new name
and a projects field.

**An issue from a project's own repo links to that project with no rule.** On import, `SyncIssues` links a GitHub
issue whose `origin` equals a project's `repo` to that project. It links the projects of every rule the issue
matches beside it, and a project both name links once.

**Each link lands once, as ADR 0103 holds for tags.** Imports link; `follow` reads no rule and no repo, so a link the
owner removes stays removed. Creating a rule links the issues already imported that match it, and giving a project a
repo, on create or edit, links the issues already imported from that repo. Both find those issues by
`task_sources.url`. Editing or deleting a rule, or clearing a project's repo, unlinks nothing.

## Alternatives

**A separate table of project rules.** Project rules get their own table, repo, operations, admin page, API endpoints
and MCP tools. It lost because it doubles the rule system for rules that differ only in what they hand out.

**Projects on tag rules under the old names.** The join table hangs off `task_tag_rules` and nothing is renamed. It
lost because a "tag rule" that holds only projects says something false on every surface that names it.

## Consequences

The owner links a repo's issues to its project by giving the project a repo, and needs a rule only for `owner/*`, a
Linear team, or a second project.

The rename touches the schema, the repo, the operations, the admin page, the API and the MCP tools at once, and any
client that calls `save_task_tag_rule` or `list_task_tag_rules` breaks.

Only GitHub issues match a project's repo, since a project names a GitHub repo and a Linear `origin` names a team.
Linear issues reach a project only through a rule.

The one pass on create now runs from two places, a rule and a project, and both read `task_sources.url` while imports
read `origin`. The two can still disagree, and nothing checks them against each other.

Nothing records whether a project link came from the repo, a rule or the owner, so no later change can tell them
apart. A project added to a rule after it was created never reaches past imports, so the owner links those by hand.

[0093]: 0093-link-any-two-records-through-one-record-links-table-in-a-links-slice.md
[0103]: 0103-tag-an-imported-task-from-repo-rules-on-import-and-once-on-create.md
[0112]: 0112-give-every-tag-rule-a-provider-and-match-linear-issues-by-workspace-and-team.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
