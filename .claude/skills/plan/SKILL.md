---
description: Turn a spec into the issues that build it.
name: plan
---

# Plan

Take a spec and work out what to build first.

## 1. Read the spec

Issues live on GitHub. Work from [`.claude/issues.md`][issues] for every command and label here.

Read the spec by its number.

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

File each issue, then make it a sub-issue of the spec so the work hangs off it. Each one gets:

- **Labels:** one type from `bug`, `chore`, `enhancement`, `fix`, `optimization`, `release`, `spike`, an area
  label for each slice it touches, and a priority: `p1` for work the rest waits on, `p2` for the body of it, `p3`
  for polish.
- **Milestone:** the spec's, when it has one.
- **Body:** the shape in `/write-issue`.

Then mark each issue that has to wait as blocked by the issues it waits on, and give it the `blocked` label. Order
comes from those relations, not from the order you filed them in.

Write only what the spec and the user decided. An edge case a review raised is not a requirement until the user
says so.

Title an issue after the code that lands, not the outcome for a user. `Render posts from Markdown with Rouge`, not
`Make posts look nice`.

## 5. Report

Give the user the spec number, the issue numbers with titles, and what blocks what. Say which issues can be worked in
any order.

Then: `invoke /implement <number> when you are ready`, naming the first unblocked issue.

[issues]: .claude/issues.md
