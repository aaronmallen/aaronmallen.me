---
description: Write an architecture decision record.
name: write-adr
---

# Write an ADR

## 1. Read the rules

Read [`docs/writing-adrs.md`][writing] in full. It holds the front matter, the statuses, the badges and the
template. This skill does not repeat them.

Read `.claude/CLAUDE.md` too. The writing rules there apply to the record.

## 2. Check the decision is worth a record

A record covers one choice that is hard to reverse and shapes code nobody has written yet. If you cannot name the
alternative that lost, stop and say so. There is no decision to record.

If the user asked for a record covering two decisions, say which two and ask which one this record is for.

## 3. Find the decision

Do not write the record from the request alone. Read the code the decision produced.

Read the change the decision produced the way [`.claude/vcs.md`][vcs] describes.

Work out what the code decided, not what it does. A migration that adds a partial unique index decided that an
identity has one primary email address. That is the record. The index is the implementation.

## 4. Do not invent the reasoning

Write only what the code and the user support. If the reason for a choice is not in either, ask. Never fill
`## Alternatives` with options nobody weighed, and never name a tool the project has not picked.

State a cost you can see even when the user did not mention it. That is reading the code, not inventing.

## 5. Write it

Number the record the way the guide's numbers section says. Before launch, it takes its place in the logical
order, the records after it move up one, and you rewrite every citation of them. After launch, it takes the number
after the highest one in `docs/adr/`, a number is never reused, and a gap is never filled. Name the file
`NNNN-<slug>.md`, four digits, where the slug comes from the title.

Title the record with the decision. Copy the front matter from the template, set `created` to the launch day
(2026-09-28) before launch or to today after it, and drop every key you have nothing to put in. A new record has
no `supersedes` or `superseded-by`, so it carries neither.

Put the status badge on its own line under the heading, as a reference link with the URL defined at the bottom of
the file. The badge and the front matter `status` say the same thing, so change them together or not at all.

## 6. Update the index

Add a row to `docs/adr/README.md`, in number order, with the same badge in the status column. Keep the links
reference links, defined at the bottom of the file with the others. Records sharing a status share one definition.

## 7. Check it

```sh
mise run lint:markdown
mise run lint:editorconfig
```

Then read the record once more and cut every sentence a reader could have worked out from the one above it.

[vcs]: .claude/vcs.md
[writing]: docs/writing-adrs.md
