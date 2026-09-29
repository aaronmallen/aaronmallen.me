---
description: Draft a request for comment and file it as a GitHub issue.
name: write-rfc
---

# Write an RFC

An RFC argues for an approach before anyone commits to it. Write one when the choice crosses component boundaries,
changes something other code already leans on, or has two defensible answers.

An RFC is a GitHub issue, labelled `rfc`.

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

Issues live on GitHub. Work from [`.claude/issues.md`][issues] for every command and label here.

File the issue:

- **Title:** `RFC: <what it proposes>`.
- **Body:** the draft from step 2.
- **Labels:** `rfc`, plus an area label for each slice it touches.

The repository is public. Keep hostnames and details of the home network out of the RFC.

## 5. Hand off

Print the issue number and its URL, then: `settle the RFC, then invoke /plan <number>`.

[issues]: .claude/issues.md
