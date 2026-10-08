---
description: Draft one issue and file it on GitHub.
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
- Write only what the spec and the user decided. An edge case a review raised is not a requirement until the user
  says so.
- Say what and why. An implementation plan belongs in the code, not the issue.
- Every criterion has to be checkable by somebody who did not write it.
- No heading repeats the title.

## 3. File it

Issues live on GitHub. Work from [`.claude/issues.md`][issues] for every command and label here.

File the issue:

- **Title:** the code that lands, not the outcome for a user.
- **Labels:** one type from `bug`, `chore`, `enhancement`, `fix`, `optimization`, `release`, `spike`, an area
  label for each slice it touches, and one priority from `p0` to `p4`.
- **Parent:** when the issue came from a spec, make it a sub-issue of that spec.

## 4. Hand off

Print the issue number and its URL, then: `invoke /implement <number> when you are ready`.

[issues]: .claude/issues.md
