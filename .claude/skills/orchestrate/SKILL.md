---
description: Run every sub-issue of a spec through /implement, in dependency order.
name: orchestrate
---

# Orchestrate

Take a spec and build all of it, in waves of agents that run side by side.

## 1. Read the spec

Issues live on GitHub. Work from [`.claude/issues.md`][issues] for every command and label here, and from
[`.claude/vcs.md`][vcs] for every jj command.

Read the spec by its number, then list its sub-issues. Read what blocks each one. Those relations are the order.
Issue numbers are not, and neither is the order somebody filed them in.

Take `needs review` off every sub-issue that is closed. GitHub leaves the label on when a push closes the issue.

A sub-issue that is closed or in `needs review` is done. Leave it out, since running one twice undoes finished
work, and count it as done when you read what blocks the rest.

## 2. Work out the waves

Sort the open sub-issues so nothing runs before the issue that blocks it. If two block each other, stop and say
so. Nothing else here fixes a cycle.

A wave is the issues whose blockers are all done or in an earlier wave. Keep a wave to between three and seven.
When more than seven are ready, hold back the ones that touch the same files as one already in the wave, since
they conflict when you linearize.

## 3. Show the waves and wait

Print each wave, and each issue in it with its number, title and blockers. Then ask before starting.

This writes code and commits it, for hours, without checking back. Do not start without a yes.

## 4. Run a wave

Give each issue in the wave a workspace of its own, off the current tip, as [`.claude/vcs.md`][vcs] says under
"Work in parallel workspaces". Then spawn one agent per issue, all at once, and give each this:

```text
Invoke /implement <number>. Follow the skill as written, including the review and the commit.

Work only in <workspace>. Never touch the main repo directory or another workspace, and never run a jj command
that rewrites a commit outside your own working copy. Never print .env. Pass -R aaronmallen/aaronmallen.me to
every gh command. End with your change described and an empty `jj new` on top.

Report which acceptance criteria hold and which do not.
```

One agent per issue, and a new one each time. A single context that implements a whole spec has forgotten the
first issue by the time it reaches the last.

Wait for every agent in the wave and read each report.

## 5. Linearize the wave

Put the wave's commits in one line on the tip, as [`.claude/vcs.md`][vcs] says under "Linearize workspaces".
Forget each workspace and delete its directory.

Then read the descriptions on the line. Each issue keeps one `Closes #<n>`, on its last commit, and its earlier
commits say `See #<n>`. Agents in one wave finish at different times and cannot tell which of them is last, so
two may close the spec, or none may. When the wave finishes the spec, keep `Closes #<spec>` only on the last
commit of the line, and add it there if no commit has it. When it does not, no commit closes the spec.

Run `mise run lint` and `mise run test` once from the repo root. Fix what breaks before the next wave.

## 6. Stop at the first failure

If an agent leaves its issue `in progress`, finish linearizing the wave, then stop. Do not start the next one.

The next wave builds on this one, so carrying on builds on code that does not work. Tell the user what stopped,
what landed, and what is left.

If an agent comes back with a question rather than a failure, put the question to the user. Do not answer it
yourself and keep going.

## 7. Report

Say which issues landed, which did not, and what is still open.

Do not close the spec or any sub-issue with `gh`. The commits close them when the owner pushes. Check that the
last commit on the line says `Closes #<spec>` once every sub-issue is done.

[issues]: .claude/issues.md
[vcs]: .claude/vcs.md
