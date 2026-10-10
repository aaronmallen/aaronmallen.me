---
id: "0107"
title: Trust a webmention author only under their URL, and a whole host only when marked
status: active
created: 2026-10-04
area: [social, admin, mcp, lib, db]
supersedes: ["0042"]
issue: "#461"
amended: ["#946"]
tags: [webmentions, moderation, trust, spam, bridgy, security]
---

# ADR 0107: Trust a webmention author only under their URL, and a whole host only when marked

![Active][status]

## Context

An approved webmention shows under the public post at once, with the name and text the sender's page holds. With
`auto_approve_known_authors` on, which is the default, a mention from an author the site already trusts skips the
owner's review.

[ADR 0042][0042] approved a mention when its source and its author URL shared a host and that author URL was known.
The page the sender chose names the author, and a page with no author link reads as the site root. So any page on a
host where a known author lives could name that author and go live under their name (#461). ADR 0042 named the site
root half of this gap.

## Decision

`Social::Operations::VerifyWebmention#approved?` approves a mention only when all of these hold:

- `auto_approve_known_authors` is on.
- The page links its author: `Social::Webmentions::Source#author_link` reads the h-card URL or a `rel=author` link.
  A page without one still stores the site root as its author, for show, but never approves by itself.
- `Social::Operations::CheckAuthorScope` covers both the source URL sent and the URL the fetch landed on after
  redirects. #946 moved it from `lib/social/webmentions` into the slice's operations, as ADR 0126 asks. A URL is
  covered when it shares the author URL's scheme, host and port, and its path segments begin with the author
  URL's. A path holding a `.` or `..` segment, escaped or not, is never covered.
- An author URL at a host's root covers that host only when the owner has listed the host in
  `webmention_settings.single_author_hosts`, as one person's site. The owner keeps that list from the webmention
  settings in the admin and through `update_webmention_settings`. `Blog::Types::Normalized::Hosts` reads each entry
  down to a bare host and drops what does not parse.
- `Social::Repos::WebmentionRepo#known_author?` finds at least one approved mention and no spam under the same
  author URL.

Anything else waits as pending. Author URL normalization and the rule that a changed resend goes back to pending
stay as ADR 0042 set them.

## Alternatives

**Trust the host.** ADR 0042's rule. One known author made every page on a shared host able to post as them.

**Match the path as a string.** `/~ada` would cover `/~adam`. Matching whole segments closes that.

## Consequences

Trust follows the author URL a page names. An author whose card points at `/about` approves pages under `/about`
alone, so notes at `/notes/1` wait, even on a host the owner has listed. Listing helps an author whose card points
at the site root.

Listing a host trusts every page there under its root author. The owner has to know one person writes the whole
host; a list entry on a shared host brings back the gap this record closes.

A redirect out of the author's path leaves the mention waiting, even when the page it sent starts inside it.

A Bridgy mention still never approves itself: its source sits on `brid.gy` and its author elsewhere.

Mentions approved under ADR 0042 keep their status. The new rule applies when a mention arrives or a source sends
again.

[0042]: 0042-trust-a-webmention-author-by-exact-url-on-their-own-host.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
