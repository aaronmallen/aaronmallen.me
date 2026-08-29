---
description: Draft a request for comment and file it in Linear.
name: write-rfc
---

# Write an RFC

An RFC argues for an approach before anyone commits to it. Write one when the choice crosses component boundaries,
changes something other code already leans on, or has two defensible answers.

An RFC is an issue in Linear, labelled `rfc`.

## 1. Read the rules

Read `.claude/CLAUDE.md`. The writing rules there apply to the RFC.

An RFC is not a record. A record says what we decided and lives in `docs/adr`. An RFC asks. If the decision is
already made, stop and invoke `/write-adr` instead.

## 2. Draft it

```markdown
## Summary
The proposal in one paragraph.

## Motivation
Why this comes up now. What the code does today and where it falls down.

## Goals
What the proposal has to achieve, and under `### Non-goals`, what it does not.

## Proposal
The design. Show the code where the shape of an API is the argument.

## Alternatives
Each one you weighed and what made you put it down.

## Open questions
What has to be answered before this can be built.
```

`## Alternatives` carries the weight. An RFC with one option is a decision wearing a costume.

## 3. Show it to the user

Present the draft and take the edits. An RFC should be readable by somebody who has not been in the problem.

## 4. File it

Use the claude.ai Linear connector (`claude_ai_Linear`) for every Linear call here, and file under the
`Site Refactor` project in the `Personal` team. Never use `linear-complish`: that is a different workspace.

Create the issue with `save_issue`:

- `team`: `Personal`
- `project`: `Site Refactor`
- `labels`: `["rfc"]`
- `title`: `RFC: <what it proposes>`
- `description`: the body from step 2

## 5. Hand off

Print the issue key and its URL, then: `settle the RFC, then invoke /plan <key>`.
