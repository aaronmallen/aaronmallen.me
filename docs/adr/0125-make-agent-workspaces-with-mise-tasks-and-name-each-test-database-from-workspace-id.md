---
id: "0125"
title: Make agent workspaces with mise tasks, and name each test database from WORKSPACE_ID
status: active
created: 2026-10-07
area: [config]
issue: "#711"
tags: [mise, tasks, jj, workspaces, agents, orchestrate, database, testing, settings]
---

# ADR 0125: Make agent workspaces with mise tasks, and name each test database from WORKSPACE_ID

![Active][status]

## Context

`/orchestrate` runs agents side by side, each in a jj workspace under `.claude/worktrees`. `.claude/vcs.md` has the
orchestrator make each one by hand: `jj workspace add`, a copy of `.env` with `DATABASE_NAME=blog_ws<n>` on the end,
`mise trust`, then clean up after. No task does any of it, so each wave repeats the steps and any one can be missed.

`DATABASE_NAME` names the development and the test database at once ([ADR 0008][0008]). A workspace only needs a
test database of its own, but the hand-set name moves both.

`scripts/dev/stop` runs `compose down`, which stops Postgres and Redis while an agent in another workspace may still
be testing. [ADR 0005][0005] says `dev:stop` leaves those containers up, so the script does not do what the record
says.

## Decision

Two mise tasks make and remove a workspace, and nothing else does.

- `mise run dev:create-workspace <id> [base]` adds `.claude/worktrees/ws<id>` as jj workspace `ws<id>` on `base`,
  `@-` when left out. It lists `.claude/worktrees` in `.git/info/exclude` when it is missing, copies `.env` with
  `WORKSPACE_ID=<id>` on the end, trusts mise, installs dependencies, builds assets once and prepares the test
  database.
- `mise run dev:remove-workspace <id>` drops that test database, forgets the workspace and deletes its directory.

`WORKSPACE_ID` names the test database, not `DATABASE_NAME`. With it set, `config/settings/test.yml` names the test
database `<DATABASE_NAME or blog>_test_<id>`. With it unset, the name stays `<DATABASE_NAME or blog>_test`, so the
root checkout and CI change nothing. Development and production never read it.

`db:start` and `redis:start` join the stop tasks, and pitchfork runs them. `dev:stop` stops the pitchfork daemons
and leaves the containers up.

## Alternatives

**A `DATABASE_NAME` set by hand in each copied `.env`.** What `.claude/vcs.md` does today. It works, but moves the
development database too, and leaves every step to whoever makes the workspace.

**A Redis db for each workspace.** The suite never connects to Redis, so a db of its own would isolate nothing.

**A cap on workspace ids.** The brainstorm first held ids to 1 to 13, one per free Redis db. With no Redis db per
workspace, nothing needs the cap.

## Consequences

`/orchestrate` and `.claude/vcs.md` shrink to two commands per workspace, and every workspace looks the same.

Each workspace holds a test database of its own until `dev:remove-workspace` drops it. A directory deleted by hand
leaves that database behind.

Workspaces share one Redis. A later spec that tests against Redis has to give each workspace its own db first.

The containers outlive `dev:stop`, so they run until someone stops them with `db:stop` and `redis:stop`.

[0005]: 0005-run-every-tool-through-a-mise-task-and-pin-tool-versions-in-mise-lock.md
[0008]: 0008-build-the-database-url-from-settings-in-a-db-provider-in-every-slice.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
