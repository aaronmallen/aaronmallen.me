---
id: "0182"
title: Approve likes and reposts on receipt, and keep trusted webmention authors in a stored list
status: active
created: 2026-10-16
area: [admin, api, db, mcp, social]
issue: "#1570"
tags: [webmentions, moderation, trust, spam, bridgy, likes, reposts, settings]
---

# ADR 0182: Approve likes and reposts on receipt, and keep trusted webmention authors in a stored list

![Active][status]

## Context

Every webmention lands as pending unless [ADR 0107][0107] trusts its author. Likes and reposts carry no text, yet
they wait like replies. A Bridgy like or repost never passes the author check, since its source sits on `brid.gy`
and its author elsewhere, so every one of them waits.

Trust comes from history: `Social::Relations::Webmentions#known_author?` trusts an author URL with at least one
approved mention and no spam. Nothing lists who the site trusts, and the only way to stop trusting someone is to
mark one of their mentions as spam. Spec #1569 asks for both to change.

## Decision

**Likes and reposts approve on receipt.** Two settings, `auto_approve_likes` and `auto_approve_reposts`, both on by
default, sit beside `auto_approve_known_authors` in `webmention_settings`, and the admin, MCP and API show and save
them. With its toggle on, a like or repost approves with no author check, Bridgy included. This amends ADR 0107 for
those two types. With its toggle off, that type follows the rule for replies and mentions below.

**Trust lives in a stored list.** A table of trusted authors, keyed on the author URL normalized as ADR 0107 has it,
replaces trust worked out from history. An author joins only when the owner approves one of their replies or
mentions by hand, from any surface, single or bulk. Joining approves their other pending replies and mentions in the
same transaction. An auto-approved like or repost never adds anyone.

A reply or mention approves itself only when `auto_approve_known_authors` is on, its author is on the list, and its
page passes the ADR 0107 author check. An author leaves the list when the owner marks any of their webmentions as
spam, or removes them in the admin, MCP or API. Their approved mentions stay up, and a later manual approval puts
them back. Ignoring a mention neither adds nor removes trust, as [ADR 0078][0078] has it.

A changed resend of an approved like or repost stays approved. A changed reply or mention still goes back to pending,
as [ADR 0042][0042] set. The list starts empty, and likes and reposts pending before this lands stay pending.

## Alternatives

**Keep trust in history.** No migration, but no list to read, and no way to stop trusting an author short of a spam
mark.

**Check the author on likes and reposts too.** Bridgy likes and reposts would still never approve.

## Consequences

Anyone can forge a like or repost. A page that links to a post and marks itself a like goes live at once under
whatever name and avatar it claims, and the owner finds it only after the fact. Turning the toggle off for that
type brings back review.

Every author trusted under the old rule starts over: their next reply or mention waits until the owner approves one.

[0042]: 0042-trust-a-webmention-author-by-exact-url-on-their-own-host.md
[0078]: 0078-ignore-a-webmention-through-a-new-status-that-is-neutral-for-trust.md
[0107]: 0107-trust-a-webmention-author-only-under-their-url-and-a-whole-host-only-when-marked.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
