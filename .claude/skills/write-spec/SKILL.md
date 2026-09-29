---
description: Draft a product spec and file it as a GitHub issue.
name: write-spec
---

# Write a spec

A spec says what we are building and how a reader knows it works. It is a GitHub issue, labelled `spec`,
and the work hangs off it as sub-issues.

## 1. Read the rules

Read `.claude/CLAUDE.md`. The writing rules there apply to the spec.

## 2. Draft it

```markdown
## Problem
What is wrong today and who it hurts. One or two paragraphs.

## Solution
What the user gets and how it behaves. Behaviour, not implementation.

## Scope
What this covers, and under `### Out of scope`, what it does not.

## Acceptance criteria
- [ ] Something a reader can check.
- [ ] Another one.

## Open questions
Anything still undecided. Cut the section when there is nothing in it.
```

Drop any section you have nothing to put in. Do not repeat the title as a heading. The spec should read in two
minutes.

Write only what the user has decided. A spec that names a library nobody picked has invented a decision. Put that in
`## Open questions` instead.

## 3. Show it to the user

Present the draft and take the edits. Do not file anything until the user says so.

## 4. File it

Issues live on GitHub. Work from [`.claude/issues.md`][issues] for every command and label here.

File the issue:

- **Title:** the spec title, with no `Spec:` prefix.
- **Body:** the draft from step 2.
- **Labels:** `spec`, plus an area label for each slice it touches.
- **Milestone:** only when the spec matches a milestone that already exists. Do not make a new one.
- **Parent:** when the spec splits a larger one, make it a sub-issue of that spec.

## 5. Hand off

Print the issue number and its URL, then: `invoke /plan <number> when you are ready`.

[issues]: .claude/issues.md
