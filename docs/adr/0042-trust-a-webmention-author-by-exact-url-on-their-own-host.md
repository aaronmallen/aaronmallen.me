---
id: "0042"
title: Trust a webmention author by exact URL, on their own host
status: superseded
created: 2026-09-28
area: [social]
superseded-by: "0107"
issue: AA-598
amended: ["#461"]
tags: [webmentions, moderation, trust, spam, bridgy, security]
---

# ADR 0042: Trust a webmention author by exact URL, on their own host

![Superseded][status]

## Context

An approved webmention shows under the public post at once, with the name and text the sender's page holds. The
operator approves or marks spam from the admin. With `auto_approve_known_authors` on, which is the default, a mention
from an author the site already trusts skips that wait.

Who the author is comes from the page the sender chose. `Social::Webmentions::Source#author` reads the h-card link,
and takes the page's site root when there is none.

Two versions of the rule failed. AA-463 found that approval read the domain of the author URL the page claimed, so
a page on `evil.example` naming `https://ada.example/about` went live with no review. AA-520 found that once trust
moved to the host, one approved mention on a shared host made every author on that host known.

## Decision

`Social::Operations::VerifyWebmention#approved?` approves a mention only when all three hold:

- `auto_approve_known_authors` is on.
- The source URL and the author URL share a host, read through `Blog::Types::Normalized::Host`.
- `Social::Repos::WebmentionRepo#known_author?` finds at least one approved mention and no spam under the same
  author URL (`Social::Relations::Webmentions::APPROVED_NOT_SPAM`).

Anything else waits as pending.

The repo writes and looks up author URLs in one form. `WebmentionRepo#normalized_author_url` lowers the scheme and
host, drops the fragment and a trailing slash, and writes a bare host as `host/`.

A resend that changes `author_name`, `author_url`, `excerpt` or `type` sends an approved mention back to pending,
since the approval the old text earned does not cover new text (`Social::Relations::Webmentions#store`, AA-465). A
resend leaves a spam mark alone.

## Alternatives

**Trust the host.** One approval vouched for everyone on that host: a relay, a group blog, a community instance
(AA-520).

**Trust the author URL the page claims.** Any page on any host could name a known author and publish under their
name (AA-463).

## Consequences

A Bridgy mention never approves itself. Its source sits on `brid.gy` and its author on `mastodon.social` or
`bsky.app`, so the host check fails however well the operator knows the author. Every Bridgy mention waits, which
AA-293 will meet. The spec "leaves a mention waiting when the site of a Bridgy author is unknown" reads as if a
known one would pass. It would not.

Trust sits on one URL, path and all. `/about` and `/me` are two authors, the path keeps its case, and an author who
moves their profile starts over.

One spam mark under an author URL ends that author's trust, whatever they had approved before. From the admin,
approving that mention is the only way back. A spam mark on a neighbour on the same host leaves the author trusted.

The site root fallback leaves a gap in what AA-520 fixed. Every page on a host that carries no author link reads as
the same author, the site root, so on a shared host one approval of such a page trusts every other page there
without one.

[status]: https://img.shields.io/badge/0107-black?style=for-the-badge&label=Superseded&labelColor=orange
