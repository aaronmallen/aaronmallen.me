---
id: "0186"
title: Keep agent memory, artifacts and sessions in an agents slice
status: active
created: 2026-10-17
area:
  - db
  - admin
  - api
  - mcp
  - links
issue: "#1741"
amended:
  - "#1745"
  - "#1750"
  - "#1790"
  - "#1859"
  - "#1860"
  - "#1893"
tags:
  - agents
  - memory
  - artifacts
  - sessions
  - slices
  - mcp
  - privacy
---

# ADR 0186: Keep agent memory, artifacts and sessions in an agents slice

![Active][status]

## Context

Agents work on the site through MCP, but nothing they learn outlives the run. Each session starts cold. Plans, specs
and handoffs live in the repo or in chat, and the only trace of an agent is a task contributor row
([ADR 0115][0115]). I cannot see, fix or undo what an agent knows, and one agent cannot pass context to the next.

Spec #1739 adds three stores built for agents first: memory files of typed facts, numbered artifacts with versions,
and sessions that tie the two to a run. MCP is the main way in. The admin lets me read, edit and revert.

## Decision

A new feature slice, `agents`, owns memory files, facts and their history, artifacts and their versions, and
sessions ([ADR 0001][0001]). Its relations, repos, contracts and operations live in `slices/agents`. Other slices
read it through its exported read repos and operations and never write its tables ([ADR 0123][0123]).

- **MCP tools forward to API endpoints** in the `api` slice, as every tool does ([ADR 0088][0088]).
- **Memory files and artifacts join `record_links`** as the `memory_file` and `artifact` kinds
  ([ADR 0093][0093]), so they link to tasks, projects, commits and each other. They stay out of global search and
  the activity feed. Since #1860 agents find facts through `search_memory`, which reads only memory and sits under
  the `agents` scope ([ADR 0195][0195]).
- **Nothing is public.** No public page reads the slice.
- **I fix memory in the admin.** Since #1750 the memories screens add, edit, remove and revert facts, move a file
  to another scope, link it to other records and delete it. Each change names me as its author. A move adds a
  `scope` entry to the file's history, and agents move a file the same way through `move_memory_file`. Since
  #1893 a file's scope is global, a project or a task; the `repo` scope is gone, and a repo only finds its project
  ([ADR 0199][0199]).
- **Nothing expires.** History, versions and sessions stay. A cap on artifact bodies (100,000 characters) keeps each
  row small. #1859 dropped the cap on fact text, so an agent can save a whole gotcha; the request body limit still
  bounds what a client sends. Since #1790 `read_memory_file` and the admin memory file page read history a
  page at a time, newest first, so a busy file does not send every change it ever had.
- **Artifact tags sit in a `text[]` column on `artifacts`**, with a CHECK that holds each one to the tag slug format,
  not in the shared `tags` table. A join to `tags` would put artifacts on the tag screens and in the tag counts,
  which the slice stays out of, as it stays out of search. A `tag_name[]` column would carry the domain, but
  Sequel reads an array of a domain back as a plain string, so the CHECK stands in for it.

## Alternatives

**Leave memory and handoffs in the repo as files.** That is how agents work today. The files belong to one checkout,
so an agent on another machine or in another repo cannot read them, and nothing records who wrote a fact or lets me
revert it.

## Consequences

Agent data sits in one place, so the `agents` scope ([ADR 0188][0188]) has one slice to guard.

Deleting a task or project deletes the memory files scoped to it, so the slice reaches into rows another slice owns
through foreign keys.

With no pruning, history, versions and sessions grow for good.

Since #1859 fact text has no cap. Since #1860 `start_session` returns an index of the files in scope and no facts
([ADR 0195][0195]), so a long fact grows only the replies of the agents that read its file or match it in a
search.

Leaving the slice out of search and the activity feed means I find a fact or an artifact only through the Agents
screens, the MCP tools or a record link.

[0001]: 0001-split-the-app-into-slices-by-feature.md
[0088]: 0088-hold-the-layer-the-api-and-mcp-share-in-the-api-slice-and-call-it-in-process.md
[0093]: 0093-link-any-two-records-through-one-record-links-table-in-a-links-slice.md
[0115]: 0115-keep-task-contributors-in-their-own-table-and-list-the-owner-when-a-task-has-none.md
[0123]: 0123-export-only-read-repos-and-operations-and-keep-write-repos-in-their-slice.md
[0188]: 0188-gate-agent-memory-artifacts-and-sessions-behind-an-agents-scope.md
[0195]: 0195-load-agent-memory-as-an-index-and-read-it-on-demand.md
[0199]: 0199-attach-agent-memory-and-sessions-to-projects-and-treat-a-repo-as-a-lookup.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
