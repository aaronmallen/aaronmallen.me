---
description: Explore a rough idea with the user and turn it into a spec.
name: brainstorm
---

# Brainstorm

Turn a rough idea into a spec, or split a spec that grew too big.

## 1. Work out the mode

The user gives you either a rough idea or an issue number.

Issues live on GitHub. Work from [`.claude/issues.md`][issues] for every command and label here.

A number such as `#12` means split an existing spec. Read it and find the seams: the parts
that ship on their own, the parts that wait.

A rough idea means start from nothing. Send the idea to the **brainstormer** agent. It reads
`.claude/CLAUDE.md`, the records in `docs/adr`, the code and the tests, and comes back with what already exists,
what constrains the idea, and what nobody has decided yet. Work from that report, not from your own guess at the
codebase.

## 2. Ask one question at a time

Ask, wait for the answer, then ask the next. Never send a list.

Start with the open questions the brainstormer raised. The point is to find out what the user has already decided
and what they have not. A question whose answer changes nothing is a question you can skip.

When the user states the shape outright, take it. Ask no question to check it.

## 3. Offer two to five approaches

Skip this step when the user stated the shape.

Once the problem is clear, name between two and five ways to build it. For each one say what it costs and what it
rules out later. Ground every one in a pattern the codebase already has or a record in `docs/adr` it would break.

Say which one you would take and why.

Then ask with `AskUserQuestion` so the user picks one.

## 4. Write the spec

Invoke `/write-spec` with the approach the user picked. That files the spec on GitHub and prints its number.

Pass on the session too: the user's prompt, word for word, and each question you asked with its answer.
`/write-spec` ends the spec with them. Leave out the brainstormer's report and the approaches you offered. Pass them
as they stand: `/write-spec` redacts them before it files, by the list in [`.claude/issues.md`][issues].

Splitting a large spec means one `/write-spec` per piece, each one filed as a sub-issue of the original. Pass the
same prompt and questions to each piece.

[issues]: .claude/issues.md
