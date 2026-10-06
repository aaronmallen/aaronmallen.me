---
id: "0070"
title: Share one issue sync across providers, and run each provider as its own job
status: active
created: 2026-09-29
area: [db, lib, record, tasks]
issue: "#43"
amended: ["#631"]
tags: [tasks, imports, sync, github, linear, providers, jobs, locks, sync-states, enums]
---

# ADR 0070: Share one issue sync across providers, and run each provider as its own job

![Active][status]

## Context

Spec #42 brings Linear issues assigned to the operator in beside the GitHub ones from spec #8, under the same rules.
`Tasks::Operations::SyncIssues` knows only GitHub: the provider, the client, the shape of GitHub's issue and the
rules that turn it into a `remote_state` all live in it. ADR 0066 built `task_sources` to take a second provider,
but left the operation alone.

ADR 0068's rule, act only when `remote_state` changes, has to hold for Linear as it does for GitHub. The operator
also has to see which provider failed, and a failure in one must not keep the other from running.

## Decision

One `SyncIssues` holds the rule for every provider. It takes a provider and a client, and names no provider of its
own. Each provider's client hands it issues with `remote_state` already worked out, so the operation reads no field that
belongs to one provider. Importing, following a change in `remote_state`, copying the title and body, and storing
the new state and URL stay in the operation.

Each provider runs as its own job, under its own sync name in `sync_states` (ADR 0047) and its own advisory lock.
GitHub keeps the sync name `issues`, and Linear takes `linear_issues`. The sync button queues the job of every
provider with a key set.

Linear's client maps each issue to a `remote_state` this way:

| Linear | `remote_state` | Task |
| --- | --- | --- |
| Triage, backlog or unstarted state type | `open` | Reopens |
| Started state type | `started`, a new value | Goes in progress |
| Completed state type | `completed` | Done |
| Canceled state type | `not_planned` | Canceled |
| Taken off the operator | `unassigned` | Canceled |
| Deleted | `deleted` | Canceled |
| Archived | No change | No change |
| Moved to another team | Same row, URL updated | Follows the state type |

Since #631, a task that a synced link holds stays open when either provider takes it off the operator: `SyncIssues`
reads its `unassigned` as `open`, and cancels it on the first run after its last synced link goes
([ADR 0117][0117]).

Linear archives closed issues on its own, so an archive says nothing the state type has not said already. Linear
keeps an issue's id when it moves teams, so a move keeps the same row and task, and only the key and URL change.
GitHub never reports `started`.

## Alternatives

**A parallel `SyncLinearIssues`.** A second operation for Linear alone, with the GitHub one left as it is. It lost
because ADR 0068's rule would live twice, and the two copies would drift.

**One job over every provider.** A single run reads GitHub, then Linear. It lost because one provider's failure
stops the other, and one sync name leaves Today unable to say which provider failed.

## Consequences

A new provider brings a client that works out `remote_state`, a value in `task_source_provider`, a sync name, a
lock and a job. The rule itself does not change. Each enum value takes a migration of its own (ADR 0015).

The mapping lives in each client, so the clients can disagree about what a state means, and nothing checks them
against each other. The client specs, under `spec/slices/record`, are the only place that pins each mapping.

The two syncs run apart, so one can hold its lock while the other runs, and a Linear failure leaves GitHub's
tasks current. Today shows the two failures apart.

Linear runs every workspace under one job, one sync name and one lock. A failure in one workspace fails the whole
Linear run, and Today shows it as one Linear failure.

[0117]: 0117-sync-task-relations-into-task-links-with-a-parent-type-and-a-synced-flag.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
