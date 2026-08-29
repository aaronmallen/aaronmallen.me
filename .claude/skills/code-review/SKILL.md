---
description: Review the current diff in one pass.
name: code-review
---

# Code review

Read the change once, check it against what it has to do and against this project's rules, and report what is
wrong.

Do not run this on a change that is only mechanical: a rename, a formatting pass, a dependency bump. Say so and
stop.

## 1. Read the current diff

**Always review the current diff. Never ask which revision.**

Read the working change the way [`.claude/vcs.md`][vcs] describes. That is the work in flight, which is what
this skill reviews. Keep the diff, the file list and the log.

Stop if the diff is empty. Say the working copy is clean and stop there.

## 2. Run the gate first

```sh
mise run lint
mise run test
```

**A red gate stops the review.** Report which check failed and stop. A failing build buries real findings under
symptoms of it.

A green gate means anything the linter or the suite would catch is already caught. Do not report it again.

## 3. Review it

Read every changed file in full, not only the hunks. Then check the change against:

- **What it has to do.** The issue or spec it carries out, when there is one. Does it do that for every input it
  will see?
- **This project's rules.** `.claude/CLAUDE.md`, `README.md` and the records in `docs/adr` that cover the area.
- **The code beside it.** A new file looks like the files next to it.

Report only what you can point at: a file, a line and what goes wrong. A finding you cannot tie to a line is a
guess, so leave it out. Behaviour the change never set out to add is a question for the user, not a finding to
fix.

## 4. Report

List each finding with its file and line, what goes wrong, and how bad it is: **blocking** when the change is
wrong or breaks a rule, **advisory** otherwise. Put the worst first.

End with one line: the blocking count and the worst finding.

[vcs]: .claude/vcs.md
