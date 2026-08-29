---
description: Turn a spec into the issues that build it.
name: plan
---

# Plan

Take a spec and work out what to build first.

## 1. Read the spec

Use the claude.ai Linear connector (`claude_ai_Linear`) for every Linear call here, and file under the
`Site Refactor` project in the `Personal` team. Never use `linear-complish`: that is a different workspace.

```text
get_issue AA-###
```

Pull out the acceptance criteria, the parts of the codebase the work touches, and anything that reads like a
decision rather than a task.

Check the records in `docs/adr` for one that already settles part of it. If a record answers the question, say
which one and move on. If the work argues with a record, say so now, before anybody writes code.

## 2. Say how big it is

One issue or several. Say which, and why, then ask the user before you file anything.

- **One issue** when the work sits in one place and satisfies every criterion in a sitting.
- **Several** when it spans several, or when a criterion can ship on its own and be checked on its own.

Do not split work to look thorough. Two issues that must land together are one issue.

## 3. Handle the decision first

If the work makes a choice that is hard to reverse and shapes code nobody has written, it needs a record. Read
`docs/writing-adrs.md` for what counts.

The record comes first, in its own issue. File it as the first sub-issue, titled `Record the decision to <the
decision>`, labelled `chore`, and block every other issue on it. Invoke `/write-adr` when that issue gets
implemented, not now.

## 4. File the issues

One `save_issue` per issue, each with:

- `team`: `Personal`
- `project`: `Site Refactor`
- `parentId`: the spec's key, so the work hangs off the spec
- `labels`: one type from `bug`, `chore`, `enhancement`, `fix`, `optimization`, `release`, `spike`
- `milestone`: the spec's milestone, when it has one
- `priority`: `2` for work the rest waits on, `3` for the body of it, `4` for polish
- `description`: the shape in `/write-issue`

Then set `blockedBy` on the issues that have to wait. Order comes from those relations, not from the order you
filed them in.

Title an issue after the code that lands, not the outcome for a user. `Render posts from Markdown with Rouge`, not
`Make posts look nice`.

## 5. Report

Give the user the spec key, the issue keys with titles, and what blocks what. Say which issues can be worked in
any order.

Then: `invoke /implement <key> when you are ready`, naming the first unblocked issue.
