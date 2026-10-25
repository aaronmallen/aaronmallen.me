---
id: "0195"
title: Load agent memory as an index and read it on demand
status: active
created: 2026-10-20
area:
  - db
  - agents
  - admin
  - api
  - mcp
issue: "#1861"
amended:
  - "#1868"
  - "#1893"
tags:
  - agents
  - memory
  - sessions
  - mcp
  - search
  - index
  - context
---

# ADR 0195: Load agent memory as an index and read it on demand

![Active][status]

## Context

`start_session` and `read_memory` hand an agent every memory file in scope, every fact in full, as one markdown
reply ([ADR 0186][0186], [ADR 0190][0190]). Nothing caps that reply, and since #1859 nothing caps a fact. It grows
with each fact an agent adds. The pod project's memory has outgrown what one tool reply can hold, so an agent
starting work there cannot read its own memory. The agent reads every fact before it knows which ones it needs.

Spec #1860 asks how much memory should reach an agent at the start of a run, and how it finds the rest.

## Decision

An agent loads an index at the start of a run and reads facts when the work calls for them.

- **The index.** `start_session` and `read_memory` return one line per memory file in scope (global, the
  project, the tasks) with the file's ID, scope, path, description and fact count, and no facts. Neither keeps a
  way to load every fact. Until #1893 the scope held the repo and its projects; now a repo only finds its project
  ([ADR 0199][0199]).
- **Descriptions.** Each memory file carries a one-line description that says what it covers and when to read it.
  `create_memory_file` requires one, and a tool sets it on an existing file. The column ships nullable, one agent
  run writes a description for every existing file, and a later migration makes it required.
- **Reads.** `read_memory_file` still returns one file whole. A new `search_memory` tool, an API endpoint under the
  `agents` scope ([ADR 0188][0188]), matches the text of live facts, filters by project, task and scope, and
  returns each fact with its file's ID and path. It filtered by repo until #1893, which made a repo a lookup for
  the project. Text an agent wrote keeps its untrusted marker. Since #1983 `read_memory_file` leaves out the
  file's history unless the call passes `history: true`.
- **Loads.** A session records the files the agent read, not the files the index listed. `read_memory_file` and
  `search_memory` take an optional `session_id`. A read records its file, and a search records each file it hit.
  `start_session` records none, and the admin session drawer lists only what the session read. Since #1868
  `start_session` records the index lines it returns, and the drawer shows them above the searches and reads
  ([ADR 0196][0196]).

Memory stays out of the global `search` tool.

## Alternatives

The brainstorm for #1860 weighed four ways to load some facts at the start of a run. The first three load a set
that nothing bounds, so each would hit the reply limit again as that set grows.

**Always load global files.** Every global file loads into every run, whatever the repo.

**Always load gotchas.** Nothing stops a scope gathering more gotchas than one reply holds.

**A pin flag on each file.** Someone has to choose the pins, and nothing bounds the pinned set.

**Load as much as fits a size budget.** The reply stays small, but which facts make the cut depends on order, and
the agent cannot tell what it missed.

**Keep a full-load option.** The owner dropped it: the index, `read_memory_file` and `search_memory` cover every
read, and a full load breaks the same way on a large scope.

## Consequences

The reply from `start_session` grows with the number of files, not the number or length of facts.

An agent sees no fact it did not ask for. A gotcha reaches it only if the index line or a search leads it there, so
a vague description hides the facts under it, and a file whose facts drift from its description misleads every
agent that reads the index.

An agent that wants context takes more calls: one for the index, then a read or a search for each file it opens.

A session's loads now show what the agent chose to see, so the admin drawer tells me what a run read, not what it
was offered.

Until the later migration lands, a file can have no description, and its index line gives an agent no reason to open it.

[0186]: 0186-keep-agent-memory-artifacts-and-sessions-in-an-agents-slice.md
[0188]: 0188-gate-agent-memory-artifacts-and-sessions-behind-an-agents-scope.md
[0190]: 0190-open-and-close-agent-sessions-through-tools-and-close-idle-ones-from-a-job.md
[0196]: 0196-keep-a-copy-of-each-sessions-memory-index-searches-and-reads.md
[0199]: 0199-attach-agent-memory-and-sessions-to-projects-and-treat-a-repo-as-a-lookup.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
