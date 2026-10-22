---
id: "0189"
title: Name an agent by the slugs it reports on each write
status: active
created: 2026-10-17
area:
  - db
  - admin
  - api
  - mcp
issue: "#1741"
amended:
  - "#1764"
tags:
  - agents
  - identity
  - contributors
  - models
  - domains
  - history
---

# ADR 0189: Name an agent by the slugs it reports on each write

![Active][status]

## Context

Every fact change, artifact version and session in the `agents` slice ([ADR 0186][0186]) names its author, so I can
see who taught an agent something and revert it. The author is an agent on a model, or me.

The site already names agents this way on tasks. [ADR 0115][0115] keeps a task contributor as an agent slug and a
model slug in the `contributor_slug` domain, with no table of agents.

## Decision

An agent names itself on each write. MCP writes and `start_session` carry an agent slug, such as `claude-code`, and
a model slug, the model's own id, such as `claude-opus-5-5`. Both sit in the `contributor_slug` domain, as on
`task_contributors`. A write from the admin names me, with no slugs.

The API and MCP refuse a write to memory or artifacts that leaves out either slug. So a token write always names an
agent and reads back marked untrusted, whatever slugs it reports, and an edit through a token never turns an agent's
fact into mine. Only the admin writes as me.

There is no table of agents. The admin works out a brand from the model slug for display, and filters match the
stored slug.

## Alternatives

**A table of agents.** Each write would point at a row. The table would need a screen to keep it, and a new agent or
model would need a row before its first write.

**Tie an agent to its OAuth client.** The token would name the author, so an agent could not claim another name. One
client runs many agents and models, though, and the client's name says neither.

## Consequences

An agent can name itself anything. Two agents that report the same slugs read as one, and a client could write under
another agent's name. Only the scopes on its token limit what it can do.

Since #1764 each history entry that replaces or removes a fact's text keeps who wrote that text, in `was_agent` and
`was_model`. A revert of an edit hands the old text back to its author, so an agent's fact I edit and then revert
loads marked untrusted again. The revert entry still names whoever reverted.

[0115]: 0115-keep-task-contributors-in-their-own-table-and-list-the-owner-when-a-task-has-none.md
[0186]: 0186-keep-agent-memory-artifacts-and-sessions-in-an-agents-slice.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
