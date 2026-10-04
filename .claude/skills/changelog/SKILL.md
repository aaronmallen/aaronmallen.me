---
description: Write Unreleased entries in CHANGELOG.md from the commits since the last tag.
name: changelog
---

# Changelog

Add entries under `[Unreleased]` in `CHANGELOG.md` for the commits it does not cover yet.

Releases stay manual, because a new tag deploys within five minutes. Never move `[Unreleased]` under a version, never
bump a version and never run a tag command, in `git` or `jj`.

Versions follow [CalVer](https://calver.org) as `YY.M.MICRO`: the two digit year, the month with no zero padding, and
a counter that starts at 0 each month. The UTC day of the tag sets the date. When the user asks what the next release
is called, run `mise run release:next` and give its answer. It reads the tags and changes none. Never count tags by
hand.

## 1. Read the rules

Read `.claude/CLAUDE.md`. The writing rules there apply to every entry. Then read `CHANGELOG.md` in full, so you know
its voice and what `[Unreleased]` already says.

## 2. Find the new commits

The newest commit that is either tagged or changed `CHANGELOG.md` marks where the changelog stops. Every commit
after it, up to the parent of the working copy, is new:

```sh
jj log --no-pager --no-graph \
  -r 'heads(::@ & (tags() | files("CHANGELOG.md")))..@- ~ empty()' \
  -T 'commit_id.short() ++ "\n" ++ description ++ "\n"'
```

When the working copy has already changed `CHANGELOG.md`, it marks the stop itself and the list comes out empty.

**If the list is empty, say the changelog is up to date and stop.** Do not touch the file.

Read the diff of any commit whose message leaves you unsure what changed:

```sh
jj diff --no-pager --stat -r <commit>
```

## 3. Decide what goes in

The changelog is for someone who uses the site, the admin, the MCP server or the `mise` tasks. Leave out a commit
when that reader would never notice it:

- Records in `docs/adr`, and changes to them.
- Changes under `.claude`.
- Refactors, tests and tooling that change no behaviour.
- A fix to work that has not shipped yet. The fix folds into the entry for that work.

Several commits often make one change. Write one entry for the change, not one per commit. When a new commit
extends something `[Unreleased]` already lists, rewrite that entry to say so rather than add a second one.

## 4. Write the entries

Put each entry under one of these headings, in this order, inside `[Unreleased]`:

| Heading | For |
| --- | --- |
| `### Added` | Something new. |
| `### Changed` | Something that works differently. |
| `### Deprecated` | Something that will go away in a later release. |
| `### Removed` | Something that has gone. |
| `### Fixed` | Something broken that works now. |
| `### Security` | A fix for a weakness. |

Add a heading only when an entry sits under it. Keep the ones already there.

Each entry:

- Is one bullet in plain prose, wrapped at 120 characters with a two-space hanging indent.
- Names what a reader sees, such as a page, a tile, a button, an MCP tool or a `mise` task, not the class that
  carries it.
- Says what changed, in the present tense: "A Unique visitors tile on Today counts today's visitors."
- Names the fault a fix removed, so a reader knows whether it hit them.

Read each entry against the writing rules before you go on.

## 5. Leave the rest alone

Change nothing outside `[Unreleased]`. Every released section, its date, every heading and every compare link at
the foot of the file stay as they are.

## 6. Check it

```sh
mise run lint
```

Then show the user the `[Unreleased]` section and list which commits you left out and why. Do not commit. The user
reviews the entries and commits them through `/commit`.
