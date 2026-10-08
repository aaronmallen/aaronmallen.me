---
description: Implement one issue, from reading it to the commit.
name: implement
---

# Implement

Take one issue from open to committed.

## 1. Read the issue

Issues live on GitHub. Work from [`.claude/issues.md`][issues] for every command and label here.

Read the issue by its number.

Read the story for the why and the criteria for the what. Every criterion has to hold when you are done.

Read the code the issue touches before you change any of it. Read the tests too. A test name states the intent,
so read it before you call any behaviour a bug.

Then add the `in progress` label.

## 2. Write the code

Read `.claude/CLAUDE.md`, the README and the records in `docs/adr` that cover the area. Then:

- **The tests are the contract.** A failing test means the code is wrong. Change a test only when the issue asks
  for the behaviour to change.
- **Write tests for what you add**, covering the behaviour and the edges.
- **Follow what is already there.** A new file looks like the files beside it.
- **Change only what the issue names.** Anything else you spot goes to the user, not into the diff.
- **Fix a bug in the commit that brought it in** while that commit is unpushed, not in a fix commit on top.

When the issue is the record for a decision, invoke `/write-adr` and stop there. The record lands in its own
commit, under the code that carries it out. That commit says `See #<issue>`, and the code on top closes it.

## 3. Check it

```sh
mise run format
mise run lint
mise run test
```

All three pass before you go on. Run the whole lint, not one language.

Under `/orchestrate`, run only the specs your change touches in place of `mise run test`:

```sh
mise run test:ruby <paths>
```

The orchestrator runs the whole suite from the root after each wave.

## 4. Review it

Invoke `/code-review`. Fix what it finds, or say why a finding stands.

## 5. Commit

Find the parent spec, if the issue has one, and read its sub-issues. When every other sub-issue is closed or in
`needs review`, this issue's last commit closes the spec too.

Invoke `/commit` with the issue number, whether this is the issue's last commit, and the spec when this commit
closes it. Do not close the issue or the spec with `gh`. The commit closes them when the owner pushes.

## 6. Hand it over

Swap `in progress` for `needs review` on the issue. Then read the issues it blocks, and take `blocked` off each
one whose blockers are all closed or in `needs review`.

Then credit yourself on the task synced from the issue. Find it with `list_tasks`, searching for the issue's
title, and take the one whose source issue is this one. Read it with `read_task`, then call `save_task` with every
contributor it lists plus yourself as `{kind: "agent", agent:, model:}`, named as [ADR 0115][0115] names them:
`claude-code` and your model's id, such as `claude-opus-5-5`. `save_task` replaces the whole set, so leave none of
the old ones out. If no task syncs from the issue, or it already lists you, skip this step.

If a step failed and you could not fix it, leave the issue `in progress` and tell the user what stopped you. Do
not mark work done that is not.

[0115]: docs/adr/0115-keep-task-contributors-in-their-own-table-and-list-the-owner-when-a-task-has-none.md
[issues]: .claude/issues.md
