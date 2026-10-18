---
id: "0190"
title: Open and close agent sessions through tools, and close idle ones from a job
status: active
created: 2026-10-17
area: [config, db, api, mcp]
issue: "#1741"
amended: ["#1747", "#1752", "#1750"]
tags: [agents, sessions, mcp, sidekiq, scheduled-jobs, memory]
---

# ADR 0190: Open and close agent sessions through tools, and close idle ones from a job

![Active][status]

## Context

A session ties an agent's run to the memory it loaded, the facts it changed and the artifacts it wrote
([ADR 0186][0186]). I read sessions in the admin to see what each run did.

MCP keeps no state between calls ([ADR 0058][0058]). `/mcp` builds a new server for each request and hands the SDK
no session, so the server cannot tell where a run starts or ends.

## Decision

An agent opens a session with `start_session` and closes it with `end_session`.

- **`start_session`** takes a title, agent and model slugs ([ADR 0189][0189]), a client string, a repo, a branch
  and tasks. It records which memory files loaded and returns the session id with that memory as markdown, so one
  call both opens the run and hands the agent its memory.
- **Writes name the session.** Memory and artifact writes take an optional session id and record the change against
  it. A write without one belongs to no session. Each call that names a session moves its last-seen time. Since
  #1747 a write that names a session that ended or never existed is refused.
- **`end_session`** sets the end time. A second call is refused.
- **A sidekiq-scheduler job** closes each session not seen for 2 hours, and #1747 sets its end time to when a call
  last named it. It never retries and catches up on its next run ([ADR 0012][0012]).

Sessions stay for good. Since #1752 the admin lists them by day under Agents, read only, and a drawer shows each
one's tasks, the memory it loaded and changed and the artifacts it wrote. Today counts the day's sessions, the
memory changes agents made and the artifacts they wrote. Since #1750 the drawer links each memory file to its page,
and Today's memory line opens the memories screen.

## Alternatives

**Sessions from the MCP transport.** The SDK's streamable HTTP transport keeps sessions of its own. ADR 0058 turned
it down for one stateless action, and a transport session ends with the connection, not with the agent's work.

## Consequences

An agent has to call the tools. One that never calls `start_session` writes into no session, and one that never
calls `end_session` shows as open for 2 hours after its last call.

Nothing ties a session to the token that opened it, so any client holding `agents` can write into any open session
whose id it knows.

Since #1747 a session keeps its tasks and loaded files as links, so deleting a task or a memory file drops it from
each session that named or loaded it.

[0012]: 0012-never-retry-a-scheduled-job-and-make-its-next-run-catch-up.md
[0058]: 0058-serve-mcp-as-one-stateless-post-action.md
[0186]: 0186-keep-agent-memory-artifacts-and-sessions-in-an-agents-slice.md
[0189]: 0189-name-an-agent-by-the-slugs-it-reports-on-each-write.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
