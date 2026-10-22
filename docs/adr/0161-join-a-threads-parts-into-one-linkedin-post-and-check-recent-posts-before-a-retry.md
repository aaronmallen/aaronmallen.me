---
id: "0161"
title: Join a thread's parts into one LinkedIn post, and check recent posts before a retry
status: active
created: 2026-10-14
area:
  - social
  - lib
issue: "#1243"
tags:
  - social
  - linkedin
  - delivery
  - retry
  - idempotency
  - threads
---

# ADR 0161: Join a thread's parts into one LinkedIn post, and check recent posts before a retry

![Active][status]

## Context

Spec #1239 adds LinkedIn as a third social network. Delivery follows [ADR 0040][0040] as [ADR 0132][0132] carries it
over to each account's row, and two of its rules lean on things LinkedIn lacks.

A thread sends each part as a reply to the part before it, through `reply_to`. LinkedIn has no replies.

A retry resumes at the first part not sent and passes each part a key, so the network can refuse a repeat. LinkedIn
takes no such key. A timeout leaves us not knowing whether the post went out, and a plain retry could post it twice.

## Decision

A LinkedIn delivery sends one post. Its text joins the parts in order, with a blank line between each, and the
composer and the delivery check the joined text against LinkedIn's limit in place of each part's. The row's
`remote_ids` holds the one post's id, and that id stands for every part.

Before a retry, the LinkedIn client reads the account's recent posts. If one holds the joined text, the delivery
records it as sent with that post's id and sends nothing. Where the client cannot read recent posts, a timeout fails
the delivery for good in place of retrying. Other errors retry as they do on the other networks.

Mastodon and Bluesky keep replies and part keys.

## Alternatives

**Send later parts as comments on the first.** It lost because a comment is not part of the post: readers see the
later parts only when they open the comments.

**Send part 1 only.** It lost because the rest of the thread never reaches LinkedIn.

**Refuse threads for LinkedIn accounts.** It lost because the owner would have to write a second, shorter post to
reach LinkedIn at all.

**Retry as the other networks do and accept the risk of a double post.** It lost because a double post sits on a
public profile until the owner finds and deletes it by hand.

## Consequences

A thread reads on LinkedIn as one post, and the breaks between parts show only as blank lines. A thread whose parts
each fit can still run over once joined, and the composer has to say so.

The resume from [ADR 0040][0040] means nothing for LinkedIn, since its post is sent whole or not at all. Code that
counts `remote_ids` against the parts, such as the check that a row is done, has to count one id as every part.

The check before a retry matches on text. An older post with the same text reads as this one, so a repeat of an
earlier post on purpose is recorded as sent and never goes out. Each retry also costs a read against LinkedIn.

Without the check, a timeout ends the delivery even when the post never went out, and the owner has to send it
again by hand.

[0040]: 0040-send-a-social-post-to-each-network-on-its-own-from-that-networks-delivery-row.md
[0132]: 0132-send-a-social-post-to-each-connected-account-the-owner-ticks.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
