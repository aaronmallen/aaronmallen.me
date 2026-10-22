---
id: "0196"
title: Keep a copy of each session's memory index, searches and reads
status: active
created: 2026-10-20
area:
  - db
  - agents
  - admin
  - mcp
issue: "#1869"
amended:
  - "#1893"
tags:
  - agents
  - memory
  - sessions
  - mcp
  - index
  - search
  - admin
---

# ADR 0196: Keep a copy of each session's memory index, searches and reads

![Active][status]

## Context

Since #1860 `start_session` returns an index of memory files with no facts, and an agent reads a file with
`read_memory_file` or finds facts with `search_memory` ([ADR 0195][0195]). A session records only loads: one row in
`agent_session_loads` per file it read or a search hit, deleted with its file ([ADR 0190][0190]). The drawer cannot
show the index an agent began with, the searches it ran or the facts they returned, and a file a search hit looks
the same as a file the agent opened.

Spec #1868 asks the drawer to show what an agent got. Files, descriptions and facts change after a session starts,
so the drawer has to show them as they were.

## Decision

A session keeps three new records beside its loads, in the `agents` slice.

- **Index lines.** `start_session` records each line it returns: path, scope, description and fact count.
- **Searches.** Each `search_memory` call records its time, query and filters, and each hit records the fact's text
  and its file's path.
- **Reads.** Each `read_memory_file` call records its file and time. A repeat read records a second row.

Index lines and hits hold a copy of what the agent saw, not a pointer to what the file holds now. Each keeps a link
to its memory file, which goes to null when the file is deleted, so the line stays and the admin marks it as a
deleted file. `agent_session_loads` stays as it is.

## Alternatives

RFC #1867 and the brainstorm for #1868 weighed these.

**Extend loads with a time and a flag.** One table, with a flag for a search hit and a time for each read. Loads
hold one row per file and go when the file goes, so they cannot hold the query, the hits, a repeat read or a
deleted file.

**Rebuild the index on display** from the session's repo, project and tasks. It needs no record, but the drawer
would show what an agent would get now, not what it got.

**One event log for every memory call.** One table covers the index, searches and reads. Loads already have their
own table and the drawer reads it, so the log is worth it only if more call types join.

**Cascade deletes, as loads do.** The drawer stays tidy, but deleting a file would erase what a session saw.

## Consequences

The drawer shows what an agent got, even after its files change or go.

Each session stores a copy of its index and every hit's text, so the tables grow with each run and each search, and
a removed fact's text lives on in the hits that returned it. Nothing prunes them.

Since #1893 a scope is global, a project or a task ([ADR 0199][0199]), so an index line or a search that named the
old `repo` scope now names `project`. A search keeps the repo the agent sent.

Loads and reads now record the same `read_memory_file` call twice. Code that counts reads has to pick one, and a
session from before #1868 has loads and no reads.

[0190]: 0190-open-and-close-agent-sessions-through-tools-and-close-idle-ones-from-a-job.md
[0195]: 0195-load-agent-memory-as-an-index-and-read-it-on-demand.md
[0199]: 0199-attach-agent-memory-and-sessions-to-projects-and-treat-a-repo-as-a-lookup.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
