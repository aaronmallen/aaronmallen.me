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
`XXXX` becomes the number of the record that replaced it. The new record lists the old one under `supersedes`.

No record is superseded yet, and none will be until the site deploys. Until then we correct the record that turned
out wrong.

## Editing a record that landed

Nothing has deployed, and the history squashes to one commit. A reader opening the repository meets every record
at once, in no order, so two records about one decision read as a contradiction rather than as a history. Until
the site deploys, correct in place any record that no longer matches what we do, whatever changed, including the
decision. Migrations already work this way: correct the original, never write a corrective one.

Three kinds of change come up, and each has one answer.

**A name went stale.** Correct it. `Admin::Operations::ListTabs` became `ListSections`, and a record naming a class
nobody can find is worse than a record somebody edited. A moved file and a dead link go the same way. Only the
words change. Whatever the record decided, it still decides.

**A fact belongs beside one already in the record.** Add it there. The note on how a nested Phlex kit finds its
render methods sits in ADR 0002's section on slice directories, and anywhere else nobody would find it. Add a fact
only where a decision already in the record explains it. A fact that needs its own context is a new record.

**The decision was wrong.** Correct the record, decision and all. Rewrite the context, the decision, the
alternatives and the consequences until they say what we do now and why, and keep every reason from the old text
that still holds. The record keeps its number and its `created` day. The approach we left goes in
`## Alternatives`, with the reason it lost, since the wrong turns are half of why the current shape is what it is.
AA-422 corrected ADR 0001 that way: it now says the app is sliced by feature, it keeps the audience split as the
alternative that lost, and it carries the privacy reasoning both versions rested on.

Supersession starts the day the site deploys. A record then describes something that really shipped, and a reader
needs to know it once was true, so from that day a wrong decision gets a new record and the old one gets the three
edits above. Before it, nothing shipped, so nothing is superseded.

Every edit names the issue behind it. Put that issue in `amended`, and when you add a fact, say so where you add
it, the way ADR 0002 does: "AA-370 added this section and AA-414 the note on nested kits". A reader can then tell
a later fact from the original, and the record does not quietly become something nobody decided. A corrected
record needs this most, since `amended` is the only trace left of the turn it took.

## Front matter

Every record opens with front matter. Leave out any key you have nothing to put in.

| Key | Holds |
| --- | --- |
| `id` | The record's number, quoted, so the padding survives YAML. |
| `title` | The title from the heading, without the `ADR NNNN:` part. |
| `status` | `active`, `deprecated` or `superseded`. |
| `created` | Before launch, the launch day, 2026-09-28. After it, the day the record landed. Either way it never changes, whatever later happens to the record. |
| `area` | The parts of the codebase the decision lands in. Every value names a place the tree holds today: the commit scopes `app`, `assets`, `config`, `db` and `lib`, or the name of a directory under `slices/`. A decision that binds every slice names every slice. |
| `supersedes` | The numbers of the records this one replaces. |
| `superseded-by` | The number of the record that replaced this one. |
| `issue` | The issue that asked for the record: a GitHub number like `#12`, or a Linear key like `AA-213` for records from before the move. |
| `amended` | The issues that changed the record after it landed, in the order they did. |
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

Until the site launches on 2026-09-28, the numbers follow the order a reader needs, not the order we wrote the
records: the stack and platform first, then data rules, then app-wide patterns (sign-in, operations, contracts,
views, CSS, testing), then one block per feature. A new record takes its place in that order, and every record
after it moves up one, with every citation of it. A record folded into another closes its gap the same way, so the
set has no gaps. Every record's `created` is the launch day.

After launch, a new record takes the number after the highest one in the [index][adr], and no number moves again.
A number is never reused. Correcting one record into another leaves a gap, and the gap stays; a new record taking
the number would answer to every citation of the old one.

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
issue: AA-000
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
