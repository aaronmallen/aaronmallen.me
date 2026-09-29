---
description: Run every sub-issue of a spec through /implement, in dependency order.
name: orchestrate
---

# Orchestrate

Take a spec and build all of it, one issue at a time.

## 1. Read the spec

Issues live on GitHub. Work from [`.claude/issues.md`][issues] for every command and label here.

Read the spec by its number, then list its sub-issues. Read what blocks each one. Those relations are the
order. Issue numbers are
not, and neither is the order somebody filed them in.

Leave out any sub-issue already closed. Running one twice undoes finished work.

## 2. Work out the order

Sort the open sub-issues so nothing runs before the issue that blocks it. If two block each other, stop and say
so. Nothing else here fixes a cycle.

Run them one at a time even when the graph allows more. They share one working copy, and two agents writing
commits into it at once lose each other's work.

## 3. Show the order and wait

Print each issue with its number, title and blockers, in the order they will run. Then ask before starting.

This writes code and commits it, for hours, without checking back. Do not start without a yes.

## 4. Run each issue

Take the issues in order. For each one, spawn an agent and give it this:

```text
Invoke /implement <number>. Follow the skill as written, including the review and the commit.
Report which acceptance criteria hold and which do not.
```

One agent per issue, and a new one each time. A single context that implements a whole spec has forgotten the
first issue by the time it reaches the last.

Wait for each agent to finish. Read its report before you start the next one.

## 5. Stop at the first failure

If an agent leaves its issue open and `in progress`, stop. Do not start the next one.

Each issue builds on the one before it, so carrying on builds on code that does not work. Tell the user what
stopped, what landed, and what is left.

If an agent comes back with a question rather than a failure, put the question to the user. Do not answer it
yourself and keep going.

## 6. Report

Say which issues landed, which did not, and what is still open.

`/implement` closes the spec once its last sub-issue is done. Check that it did, and close the spec yourself if
it did not.

[issues]: .claude/issues.md
