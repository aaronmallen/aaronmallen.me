---
description: Draft one issue and file it in Linear.
name: write-issue
---

# Write an issue

One issue is one piece of work a person finishes in a sitting.

## 1. Read the rules

Read `.claude/CLAUDE.md`. The writing rules there apply to the issue.

## 2. Draft it

```markdown
## Story
As a <role>, I want <capability> so that <benefit>.

## Context
Why this comes up and what it has to fit: where it lands, the record in `docs/adr` that binds it, the
code it touches. One to three paragraphs.

## Acceptance criteria
- [ ] Something a reader can check.
- [ ] Another one.
- [ ] `mise run lint` and `mise run test` pass.
```

Rules for the body:

- The story and the criteria are required. Cut `## Context` only when there is nothing a reader needs.
- Say what and why. An implementation plan belongs in the code, not the issue.
- Every criterion has to be checkable by somebody who did not write it.
- No heading repeats the title.

## 3. File it

Use the claude.ai Linear connector (`claude_ai_Linear`) for every Linear call here, and file under the
`Site Refactor` project in the `Personal` team. Never use `linear-complish`: that is a different workspace.

Create the issue with `save_issue`:

- `team`: `Personal`
- `project`: `Site Refactor`
- `labels`: one type from `bug`, `chore`, `enhancement`, `fix`, `optimization`, `release`, `spike`
- `parentId`: the spec's key, when the issue came from one
- `priority`: `1` urgent, `2` high, `3` medium, `4` low
- `title`: the code that lands, not the outcome for a user

## 4. Hand off

Print the issue key and its URL, then: `invoke /implement <key> when you are ready`.
