---
id: "0112"
title: Give every tag rule a provider, and match Linear issues by workspace and team
status: active
created: 2026-10-06
area: [db, admin, api, mcp, record, tasks]
issue: "#506"
amended: ["#911"]
tags: [tasks, tags, rules, imports, sync, github, linear, providers]
---

# ADR 0112: Give every tag rule a provider, and match Linear issues by workspace and team

![Active][status]

## Context

[ADR 0103][0103] tags an imported task from rules that match a GitHub repo, `owner/name` or `owner/*`. The Linear
client hands over no `origin`, so Linear issues match no rule, and the owner tags each one by hand. Spec #505 asks
for Linear issues to take rule tags the way GitHub issues do: at import, and once when a rule is created.

A Linear issue has no repo. Its URL, `https://linear.app/acme/issue/ENG-12/...`, names its workspace, and its key
names its team. A GitHub owner and a Linear workspace can share a name, so `acme/*` alone cannot say which of the
two it means.

## Decision

**Every rule names a provider.** `task_tag_rules`, now `task_rules` ([ADR 0122][0122]), takes a `provider` column of the
`task_source_provider` type that `task_sources` already uses, and a new migration sets every rule that exists to
`github`. A pattern is unique per provider, so a GitHub rule and a Linear rule for `acme/*` are two rules.

**A Linear rule matches `workspace/team`.** The pattern reads `acme/ENG`, or `acme/*` for every team in the
workspace, and ignores case as a GitHub pattern does. The Linear client in `lib/record/linear` sets `origin` to the
workspace from the issue's URL and the team from its key, as [ADR 0070][0070] keeps provider details in the client.

**A rule matches only its own provider.** `SyncIssues` already knows the provider it syncs, and hands it to
`Tasks::Repos::TaskRuleQueries#targets` beside the `origin`. #911 corrected the table and method names here. The one
pass when a rule is created reads only the `task_sources` of the rule's provider, and reads the workspace and team from
a Linear URL as it reads the repo from a GitHub one.

Everything else in [ADR 0103][0103] holds: rule tags land at import beside label tags, later syncs add none, and
editing or deleting a rule changes no task's tags. The admin, the API and the MCP tools show and take the provider
through the same operations.

## Alternatives

**A shared namespace.** Rules keep one pattern and match the origin of any provider. It lost because a GitHub owner
and a Linear workspace with the same name would take each other's tags, and the owner could not set them apart.

**A `linear:` prefix in the pattern.** `linear:acme/ENG` names the provider inside the pattern, with no new column.
It lost because every surface would have to parse the provider out of a string, and nothing in the schema could
check it.

**A separate table for Linear rules.** Linear rules get their own table and tag join. It lost because it doubles the
repo, the operations, the admin screen, the API and the MCP tools for rules that differ only in what they match.

## Consequences

The owner sets a Linear team's tags once, and its new issues arrive tagged, as a GitHub repo's do.

Every rule now needs a provider, so each surface that saves a rule has to take one or fall back to GitHub the same
way.

The one pass on create now depends on Linear's URL shape as well as GitHub's, and imports read the `origin` each
client builds. The two can still disagree, and nothing checks them against each other.

A Linear rule can match only a workspace and a team. Matching on a project, label, state or priority would take a new
pattern shape or a new record.

A third provider that wants rule tags has to join the `task_source_provider` type, hand over an `origin` in an
`owner/name` shape, and teach the pass on create to read that shape from its URLs.

[0070]: 0070-share-one-issue-sync-across-providers-and-run-each-provider-as-its-own-job.md
[0103]: 0103-tag-an-imported-task-from-repo-rules-on-import-and-once-on-create.md
[0122]: 0122-widen-task-tag-rules-into-task-rules-that-assign-projects-and-match-a-projects-repo.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
