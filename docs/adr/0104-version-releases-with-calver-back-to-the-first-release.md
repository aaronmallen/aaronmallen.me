---
id: "0104"
title: Version releases with CalVer, back to the first release
status: active
created: 2026-10-03
area: [config]
issue: "#383"
tags: [version, calver, release, git, tags, changelog, deploy, raspberry-pi]
---

# ADR 0104: Version releases with CalVer, back to the first release

![Active][status]

## Context

Releases followed SemVer until 2026-09-29 and BreakVer after it, and no record said so. BreakVer lived only in the
`CHANGELOG.md` intro, and [ADR 0074][0074] names it in passing. Neither fits a personal site that ships when the work
is done and has no public API for anyone to pin. The numbers told a reader nothing, and the next one took a judgement
call each release.

A release is a git tag. [ADR 0073][0073] reads the running version from `git describe --tags`. Under
[ADR 0006][0006] a timer on the Pi runs the deploy script every five minutes. The script sorts remote tags by version,
highest first, and builds the first one with no folder under `releases/` and no line in `shared/failed-tags`.
`prune` keeps the last five releases and deletes the rest.

Spec #382 moves to CalVer.

## Decision

**A version reads `YY.M.MICRO`.** The two digit year, the month with no zero padding, and a counter that starts at 0
and resets each month. The fourth release of October 2026 is `26.10.3`.

**The date is the UTC date of the tag.** The name does not hang on the zone of whoever cuts the release.

**The scheme reaches back to the first release.** Each of the eight releases before the change, `1.0.0` to `1.4.1`,
takes its CalVer name, from `26.9.0` to `26.10.2`. The changelog headings, dates and compare links read as if CalVer
had run from the start, with no trace of the old numbers. The old tags stay.

**Every CalVer tag is annotated.** On a commit that holds both, `git describe --tags` picks the annotated tag over
the old lightweight one, so a checkout of `60471328` with its tags reads `26.10.2`.

**A mise task prints the next version.** It reads the tags and the UTC date, and never makes or pushes a tag. The
owner makes and pushes tags by hand.

**The cutover deploys nothing.** Every `26.x` tag sorts above every `1.x` tag, so the eight CalVer tags pushed bare
would deploy `26.10.2`, then walk the site back one release per tick. Before any reaches GitHub, all eight go into
`shared/failed-tags` on the Pi. The site serves `1.4.1` until the next real release, the first CalVer deploy.

**`newest_tag` stops at the first built or live tag.** It walks tags from highest to lowest, skips any in
`failed-tags`, and returns nothing once it meets a tag that has a release folder or is live. Before this, it took
any tag with no folder as new, so each release brought back the one prune had just removed. Now nothing older than
the live release deploys again. The script lives only on the Pi, so the owner copies the change over SSH.

## Alternatives

**SemVer.** Major, minor and patch promise something to code that depends on ours. No code does, so each bump
guessed at a promise nobody holds us to.

**BreakVer.** The same guess, narrowed to whether a change breaks anything. It still took a judgement call each
release, and the number still said nothing about when a release shipped.

**`YYYY.MM.DD`, with a counter on repeat days.** Three releases shipped on 2026-09-27, so busy days would need a
fourth part, and most names would carry one digit group that changes nothing.

**`YYYY.0M.MICRO`.** The same scheme with a four digit year and a zero padded month. The owner chose the shorter
`YY.M` form.

## Consequences

Anyone can read a release's month from its name, and the mise task names the next one with no judgement call.

Each of the first eight releases now has two tags, and [ADR 0073][0073] and [ADR 0074][0074] still name the old
numbers. A reader meets `1.x` in those records and in the log before 2026-10-03.

A release cut in the evening in the Americas can carry the next day's date, and on the last day of a month, the next
month's name.

The mise task reads local tags, so it is wrong on a checkout that has not fetched them.

The deploy script lives outside the repo, as [ADR 0073][0073] notes, so nothing here checks the fix, and a fresh Pi
needs it copied again.

A tag that sorts below the live release never deploys, so a slip in the counter deploys nothing and logs no error.
Rolling back still works, since it points `current` at a folder that already exists.

[0006]: 0006-run-the-site-on-a-raspberry-pi-behind-a-cloudflare-tunnel-with-its-data-on-the-nas.md
[0073]: 0073-read-the-app-version-from-the-git-tag-at-boot.md
[0074]: 0074-split-tags-into-a-public-and-a-private-scope.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
