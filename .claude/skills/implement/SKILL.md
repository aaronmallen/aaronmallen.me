---
description: Implement one issue, from reading it to the commit.
name: implement
---

# Implement

Take one Linear issue from open to committed.

## 1. Read the issue

Use the claude.ai Linear connector (`claude_ai_Linear`) for every Linear call here, and file under the
`Site Refactor` project in the `Personal` team. Never use `linear-complish`: that is a different workspace.

```text
get_issue AA-###
```

Read the story for the why and the criteria for the what. Every criterion has to hold when you are done.

Read the code the issue touches before you change any of it. Read the tests too. A test name states the intent,
so read it before you call any behaviour a bug.

Then set the issue to `In Progress` with `save_issue`.

## 2. Write the code

Read `.claude/CLAUDE.md`, the README and the records in `docs/adr` that cover the area. Then:

- **The tests are the contract.** A failing test means the code is wrong. Change a test only when the issue asks
  for the behaviour to change.
- **Write tests for what you add**, covering the behaviour and the edges.
- **Follow what is already there.** A new file looks like the files beside it.
- **Change only what the issue names.** Anything else you spot goes to the user, not into the diff.

When the issue is the record for a decision, invoke `/write-adr` and stop there. The record lands in its own
commit, under the code that carries it out.

## 3. Check it

```sh
mise run format
mise run lint
mise run test
```

All three pass before you go on. Run the whole lint, not one language.

## 4. Review it

Invoke `/code-review`. Fix what it finds, or say why a finding stands.

## 5. Commit

Invoke `/commit`.

## 6. Close it

Set the issue to `Done` with `save_issue`.

Then check the parent spec. Read its sub-issues with `list_issues` and `parentId`. When none of them is still
open, set the spec to `Done` too.

If a step failed and you could not fix it, leave the issue `In Progress` and tell the user what stopped you. Do
not mark work done that is not.
