---
id: "0039"
title: Keep the announcement on the post and send it once
status: active
created: 2026-09-28
area: [posts, social, admin, db]
issue: AA-646
tags: [posts, social, syndication, announcement, limits, mastodon, bluesky]
---

# ADR 0039: Keep the announcement on the post and send it once

![Active][status]

## Context

The post editor has a syndication card (AA-250): a switch, a pick of networks and a short text. When the post goes
live, now or on schedule, that text goes out as a social post to the networks picked, and a post never cross-posts
twice.

Two slices want the text. Posts saves it with the post and has to check it fits each network. Social sends it. Social
already imports from posts, so posts reaching into social for the text would close a cycle (AA-437).

The text that goes out is not always the text in the box. A blank box sends the title and the post's URL. AA-376
found the editor checking the box while delivery sent the fallback, so a long title passed on save and failed later as
a Sidekiq error rather than a message in the editor.

## Decision

**The card lives on the post.** `posts` holds three columns: `syndication_enabled`, `syndication_body` and
`syndication_targets` (`config/db/migrate/20260928000005_create_posts.rb`).

**Posts composes the text.** `Posts::Operations::ComposeAnnouncement` returns the box when it holds text, and the
title, a blank line and the post's URL when it does not. Posts exports it and social imports it, which follows the
import direction that already stood.

**The editor checks what will send, when the post is published.** `Posts::Contracts::PostContract` composes the text
and asks each picked network's client `within_limit?` through `social.networks.all`. It runs only when the intent is
publish and the switch is on. The editor, the counters and the preview measure the same composed text (AA-376).

**A post cross-posts once.** `Posts::Operations::PublishPost` enqueues `Social::Jobs::SyndicatePost` after commit.
`Social::Operations::QueueSyndication` refuses with `already_queued` when any social post already names the post, so
a retry of the job sends nothing more.

## Alternatives

**The kernel.** A `Blog::Announcement` both slices call. Every input it reads is the post's: its title, its slug, its
card and its route. A rule about a post held outside the slice that owns posts is the shape AA-421 moved code away
from.

**A social operation, with posts calling it.** Social sends the text, so it could compose it. Posts would then import
social for an operation while social imports posts, the cycle AA-437 refused.

**Check the length in social when it sends.** One check beside the send, and posts needs no network limits. A
failure then lands in a Sidekiq retry rather than in front of the author, which is what AA-376 fixed.
`Social::Operations::DeliverSocialPost` still refuses a part over the limit, as the last guard, not the one the author
sees.

## Consequences

The card is one-shot. Once a cross-post exists for a post, editing the card sends nothing. Turning the card on after
publish sends nothing either, since only `PublishPost` enqueues the job. A second announcement is a social post
written by hand in the admin.

A draft can hold text over a limit. The editor refuses it only when the author publishes or schedules.

Posts imports `networks.all` from social to read the limits. That key is a provider's, and the record on how slices
reach each other covers why it does not count as a cycle (AA-571).

A new network needs a client that answers `within_limit?` and `configured?`, registered in `networks.all`. Without the
first, the editor cannot check the card for it.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
