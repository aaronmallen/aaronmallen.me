# Writing ADRs

An architecture decision record says what we decided, why, and what it costs. One record holds one decision.
Records live in [`docs/adr`][adr], numbered as [numbers](#numbers) says.

The point is not process. It is that six months from now the code will not tell you why journal entries live in the
admin slice and posts do not, and neither will the person who wrote it. The record will.

## When to write one

Write a record when a choice is hard to reverse and shapes code nobody has written yet. In practice that means:

- A new slice, or a change to what goes in `app/`, `lib/` or a slice.
- A schema shape that other tables will hang off, like a view that joins every content kind.
- Taking on a dependency that reaches through the codebase, or turning off part of Hanami.
- A choice about auth, privacy or data kept about visitors that later code has to honour.
- Picking one of several workable approaches for a reason that is not obvious from the result.

Do not write one for a dependency bump, a rename, a bug fix, or a new component that follows an existing pattern. A
record you have to write to satisfy a rule is a record nobody will read.

If you cannot name the alternative you rejected, you probably do not have a decision. You have an implementation.

## When to write it

Write the record before the code, in its own commit, sitting directly under the commits that carry it out. The log
then reads as the decision followed by the work, and a reviewer can argue with the reasoning before reading the
diff.

## Status

A record is `active` the day it lands. We do not commit decisions we have not made, so there is no status for a
record still under discussion. That argument happens before the commit, usually in the spec on GitHub.

| Status | Badge | Meaning |
| --- | --- | --- |
| `active` | ![Active][active] | Decided. The code follows it. |
| `deprecated` | ![Deprecated][deprecated] | We stopped doing this and nothing replaced it. |
| `superseded` | ![Superseded][superseded] | A later record replaced it. Its number goes in the badge. |

The status appears twice: in the front matter, where you can search it, and as a badge under the title, where you
can see it. Keep the two in step.

Superseding takes three edits to the old record: the `status`, the `superseded-by` key, and the badge, whose
`XXXX` becomes the number of the record that replaced it. Its row in the [index][adr] takes the same badge. The new
record lists the old one under `supersedes`, and the old record lists the new one's issue under `amended`. #33 did
all of this when ADR 0069 superseded ADR 0048.

## Editing a record that landed

The site has run since 1.0.0 on 2026-09-27. A record that landed describes something that shipped, and a reader
needs to know it was once true, so we never rewrite the decision in a shipped record. Migrations follow the same
rule: we never edit one that has shipped, and a change takes a new migration.

Three kinds of change come up, and each has one answer.

**A name went stale.** Correct it in place. `Admin::Operations::ListTabs` became `ListSections`, and a record naming
a class nobody can find is worse than a record somebody edited. A moved file and a dead link go the same way. Only
the words change. Whatever the record decided, it still decides.

**A detail changed, and the decision stands.** Amend the record in place. Change the sentence the detail lives in,
or add the new fact beside the decision that explains it, and leave the rest alone. #37 replaced the row editor
ADR 0055 described with a task dialog, and the record now says so where it names the scripts that call `fetch`. A
fact that needs its own context is a new record.

**The decision changed.** Supersede the record. Write a new one that says what we do now, why, and what changed,
and give the old one the three edits in [Status](#status). Leave the rest of the old record as it stands: its
context, decision and consequences say what was true while it held. ADR 0069 now says how we read GitHub, and ADR
0048 still says how we read it before #33.

If the title still states what we do, the decision stands. If it does not, the decision changed.

Every edit names the issue behind it. Put that issue in `amended`, after the ones already there, and name it where
you changed the text, the way ADR 0055 does: "#37 replaced the row editor that opened from a checkbox". A reader can
then tell a later fact from the original, and the record does not quietly become something nobody decided.

Before launch we corrected records in place, decision and all, since nothing had shipped. The records written then
keep the shape those corrections gave them.

## Front matter

Every record opens with front matter. Leave out any key you have nothing to put in.

| Key | Holds |
| --- | --- |
| `id` | The record's number, quoted, so the padding survives YAML. |
| `title` | The title from the heading, without the `ADR NNNN:` part. |
| `status` | `active`, `deprecated` or `superseded`. |
| `created` | The day the record landed, such as 2026-09-29 for ADR 0068. Records from before launch carry 2026-09-28. It never changes, whatever later happens to the record. |
| `area` | The parts of the codebase the decision lands in. Every value names a place the tree holds today: the commit scopes `app`, `assets`, `config`, `db` and `lib`, or the name of a directory under `slices/`. A decision that binds every slice names every slice. |
| `supersedes` | The numbers of the records this one replaces, each quoted like `id`: `["0048"]`. |
| `superseded-by` | The number of the record that replaced this one, quoted like `id`. |
| `issue` | The issue that asked for the record: a quoted GitHub number like `"#12"`, or a Linear key like `AA-213` for records from before the move. Quote every `#` number, since YAML reads an unquoted `#` as the start of a comment. |
| `amended` | The issues that changed the record after it landed, in the order they did. Quote each `#` number, as in `issue`: `["#37"]`. |
| `tags` | Anything worth searching on later. |

## How to write one

Name the file with its number, four digits, then a short slug: `0045-count-visitors-with-a-daily-hash.md`.
[Numbers](#numbers) says which number.

Title the record with the decision, not the topic. "Keep journal records in the admin slice" tells a reader what
happened. "Journal storage" does not.

Write in the present tense and the active voice: "We keep journal records in the admin slice". The
[writing rules][rules] apply here as they do everywhere else.

Take the reasoning from the spec and issue that asked for the record, and from the code. Never invent a reason
or an alternative nobody weighed.

Say what it costs. A record with no consequences worth naming is either a decision that did not matter or a record
that is not finished. Include the bad ones. The record earns its keep the day somebody hits a cost we already knew
about and finds it written down.

Keep it to a page. Cut every sentence that a reader could have worked out from the section above it.

Then add a row to the [index][adr].

## Numbers

Before launch, the numbers followed the order a reader needs, not the order we wrote the records: the stack and
platform first, then data rules, then app-wide patterns (sign-in, operations, contracts, views, CSS, testing), then
one block per feature. A new record took its place in that order and moved every record after it up one. Every
record from then carries 2026-09-28 as its `created` day.

Since launch, a new record takes the number after the highest one in the [index][adr], and no number moves again.
A number is never reused: a new record taking it would answer to every citation of the old one.

## The template

```markdown
---
id: "<ID>"
title: ADR Title
status: active
created: YYYY-MM-DD
area: []
supersedes: []
superseded-by:
issue: "#00"
tags: []
---

# ADR NNNN: The decision, stated as a decision

![Active][status]

## Context

The forces in play. What the code looked like, what we needed it to do, and the constraints that ruled anything
out. Enough that a reader who was not there can reach the same decision.

## Decision

What we decided, in the present tense and the active voice. Name the parts of the codebase it lands in.

## Alternatives

The options we turned down and the reason each one lost. Leave the section out if there were none worth naming.

## Consequences

What follows from this, good and bad. What gets easier, what gets harder, and what we will have to live with.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
```

[active]: https://img.shields.io/badge/Active-green?style=for-the-badge
[adr]: adr/README.md
[deprecated]: https://img.shields.io/badge/Deprecated-red?style=for-the-badge
[rules]: ../.claude/CLAUDE.md
[superseded]: https://img.shields.io/badge/XXXX-black?style=for-the-badge&label=Superseded&labelColor=orange
