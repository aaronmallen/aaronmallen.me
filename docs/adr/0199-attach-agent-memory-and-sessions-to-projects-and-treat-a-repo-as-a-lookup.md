---
id: "0199"
title: Attach agent memory and sessions to projects, and treat a repo as a lookup
status: active
created: 2026-10-21
area:
  - db
  - agents
  - admin
  - api
  - mcp
  - projects
issue: "#1894"
amended:
  - "#1899"
tags:
  - agents
  - memory
  - sessions
  - projects
  - repos
  - scopes
  - mcp
  - github
  - rules
---

# ADR 0199: Attach agent memory and sessions to projects, and treat a repo as a lookup

![Active][status]

## Context

Agent memory has two ways to name the place an agent works ([ADR 0186][0186]): a `repo` scope keyed by an
`owner/name` string, and a `project` scope keyed by a project. Everywhere else on the site a repo is a field of a
project (`projects.repo`, unique), and loading memory already pulls in a repo's project files
([ADR 0195][0195]). So one place has two homes for memory, the admin shows a scope nothing else on the site knows,
and a repo with no project holds memory no other part of the site can see. A session carries only the repo string,
so nothing ties a run to a project.

Spec #1893 asks for one home.

## Decision

Memory and sessions attach to projects. The `repo` memory scope goes away, and memory has three scopes: `global`,
`project` and `task`.

- **A repo is a lookup.** `start_session`, `read_memory` and `search_memory` take a project key, or `repo` as
  `owner/name`. A repo resolves to the project whose `repo` matches. An unknown project key is an error, since a key
  alone names no repo to build a project from.
- **An unknown repo makes a project when a session starts.** When `start_session` gets a repo that matches no
  project, the `agents` slice creates a private project for it through the `projects` slice's normal save, as the
  admin would. The project takes the repo's name part as its name and the usual generated key, and the save adds the
  GitHub task rule every project repo gets ([ADR 0122][0122]). The session then loads that project's memory. #1899
  kept `read_memory` and `search_memory` to reads: an unknown repo there finds no project, and they return what they
  would with none.
- **A session records its project.** `agent_sessions` gains the project the session resolved to. `repo` and
  `branch` stay as plain facts about where the run happened, and the admin drawer shows all three. Sessions filter
  by project.
- **Archived and private projects** still load their memory when their repo matches.
- **Existing `repo` files** move onto the project whose repo matches. The rest go; a live search found no facts in
  any of them.

Artifacts carry no repo and stay as they are. `agent_session_searches.repo` keeps the filter as the agent sent it
([ADR 0196][0196]).

## Alternatives

**Keep the `repo` scope beside projects.** It costs nothing to build, but leaves the two homes, the extra pill and
the memory nothing else can see.

**Take a project key only.** An agent would have to learn its project's key before it could start, though the
checkout already names the repo.

**Take a repo only.** Every project with memory would need a repo, and an agent could not name a project that has
none.

## Consequences

Each place has one home for memory, and a project's page, tasks and sessions all hang off the same row.

An agent can now create a project, and since #1899 only `start_session` does. Any agent that starts a session in
a new checkout adds a private project and a GitHub task rule, so a typo in `repo` leaves a stray project and rule
for me to archive or delete. Since the rule matches the repo, issues synced from that repo land in the new project.

`start_session` now writes through the `projects` slice, so a project save that slice refuses fails the session
too.

[0122]: 0122-widen-task-tag-rules-into-task-rules-that-assign-projects-and-match-a-projects-repo.md
[0186]: 0186-keep-agent-memory-artifacts-and-sessions-in-an-agents-slice.md
[0195]: 0195-load-agent-memory-as-an-index-and-read-it-on-demand.md
[0196]: 0196-keep-a-copy-of-each-sessions-memory-index-searches-and-reads.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
