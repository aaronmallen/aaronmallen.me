---
id: "0073"
title: Read the app version from the git tag at boot
status: active
created: 2026-09-29
area: [lib, admin, mcp]
issue: "#27"
tags: [version, git, deploy, release, kernel]
---

# ADR 0073: Read the app version from the git tag at boot

![Active][status]

## Context

Nothing in the app says which release is running. `MCP::Protocol::Handler` in `slices/mcp/protocol/handler.rb`
hardcodes `VERSION = "1.0.0"` and reports it on `initialize`, while `1.0.2` is live. Spec #27 adds an admin footer
that shows the version, and the MCP server has to report the same one.

A release is a git tag, such as `1.0.2`, with no `v` in front. Under [ADR 0006][0006] the server builds each new
tag: the deploy script, which lives there and not in the repo, runs `git clone --depth 1 --branch <tag>` into the
release directory and starts the units in it. Each release therefore keeps its `.git`, git is on the server, and
`git describe --tags` in a live release prints its tag.

Two slices read the version and neither owns it. [ADR 0016][0016] sends such a value to the kernel in `lib/blog`,
and keeps `Blog::Constants` for values written in the source.

## Decision

The app reads its version once, at boot, from `git describe --tags`, and keeps the string for the life of the
process.

- A deployed release reads its tag, such as `1.0.2`.
- A checkout ahead of a tag reads something like `1.0.2-9-gc58904a`.
- When git is missing, `.git` is missing, or `git describe` finds no tag, it reads `unknown`, and the app still
  boots.

The value lives in its own kernel file in `lib/blog`, not in `Blog::Constants`. It passes ADR 0016's test, since
the admin and mcp slices both read it, but it comes from running git rather than from the source. The admin footer
and `MCP::Protocol::Handler` both read it, and no code writes a version anywhere else.

## Alternatives

**A `Blog::VERSION` constant bumped by hand.** No subprocess and no git at run time. It lost because it drifts from
the tag the moment somebody forgets to bump it, as the MCP server's `1.0.0` already has.

**The newest release heading in `CHANGELOG.md`.** The file ships with every release and needs no git. It lost
because it drifts too: a tag can land before `[Unreleased]` moves under a version, and the app then reports the
release before it.

**A `VERSION` file the deploy writes.** The server knows the tag it builds and could write it down. It lost because
it changes the deploy script, which lives outside the repo, and development would still need a fallback of its own.

## Consequences

The version the app shows is the tag that deployed it, with nothing to bump or forget.

Production needs git installed and `.git` kept in each release. A deploy that switches to `git archive`, deletes
`.git` after the build, or runs the units as a user who does not own the release, so git refuses it, makes every
page read `unknown` with no error.

CI checks out one commit and no tags, so the version reads `unknown` there. A spec can compare what the footer and
the MCP server report, but must not expect a tag.

Boot runs one more subprocess. A version shown mid-session is the one the process started with, which is the
release it serves, since each deploy restarts both units.

[0006]: 0006-run-the-site-on-a-raspberry-pi-behind-a-cloudflare-tunnel-with-its-data-on-the-nas.md
[0016]: 0016-keep-only-dry-types-in-blog-types-and-only-unowned-values-in-blog-constants.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
