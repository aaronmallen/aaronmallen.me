---
description: Draft a product spec and file it in Linear.
name: write-spec
---

# Write a spec

A spec says what we are building and how a reader knows it works. It is an issue in Linear, labelled `spec`,
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

Use the claude.ai Linear connector (`claude_ai_Linear`) for every Linear call here, and file under the
`Site Refactor` project in the `Personal` team. Never use `linear-complish`: that is a different workspace.

Create the issue with `save_issue`:

- `team`: `Personal`
- `project`: `Site Refactor`
- `labels`: `["spec"]`
- `title`: the spec title, with no `Spec:` prefix
- `description`: the body from step 2
- `milestone`: only when the spec matches a milestone that already exists. Do not make a new one.

## 5. Hand off

Print the issue key and its URL, then: `invoke /plan <key> when you are ready`.
