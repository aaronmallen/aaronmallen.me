---
id: "0038"
title: Keep the schedule and the live time in one published_at, and never unpublish
status: active
created: 2026-09-28
area: [db, posts, public, social]
issue: AA-651
amended: ["#941"]
tags: [posts, social-posts, publishing, scheduling, published_at, posted_at, delete, webmentions]
---

# ADR 0038: Keep the schedule and the live time in one published_at, and never unpublish

![Active][status]

## Context

A post is a draft, scheduled or published (AA-205). The editor offers Save draft and Publish, and Publish becomes
Schedule when the publish time lies in the future (AA-228). A job goes over the posts each minute and publishes
the ones due, through the same path the editor's button uses, so that the cross-post and the webmentions hang off
one place and running the job twice publishes nothing twice (AA-225).

Publishing sends things other people keep. `PublishPost` queues the cross-post to Mastodon and Bluesky and the
webmentions to every page the post links, and the Atom feeds carry the post from then on.

## Decision

**One column, `posts.published_at`, and `status` says what it means.** On a scheduled post it is when the post
goes live, and on a published one it is when it went live. A draft may hold one or none, and
`posts_published_at_check` allows a null only on a draft. `Posts::Relations::Posts#due_at` reads it as the
schedule. The public list, the article, the `(published_at, id)` pager, the Atom feeds and the `activities` view
read it as the live time, and only for published rows.

**The earlier time wins.** `Posts::Relations::Posts#publish` writes `least(coalesce(published_at, at), at)`. A post
the job publishes late keeps the time it was due, and a publish time in the past backdates the post.

**Published is the last state.** `PostMutations#publish` touches only unpublished rows, and `PostMutations#publish_due`
only rows still scheduled and due (AA-618; #941 corrected the names from `PostRepo`). `SavePost#update_published` saves
a published post without its date, whatever the intent, and the `posts_lock_published_slug` trigger refuses to change
its slug. No operation moves a post back.

**Deleting is the only way to retract a post** (AA-290). `DeletePost` removes the row. Its webmentions, webmention
receipts, suggestions and tag links go with it by cascade, and its social post stays, with `post_id` set to null.

**`social_posts.posted_at` takes the same shape.** `status` says whether it is the schedule or the time the post
went out, `social_posts_posted_at_check` allows a null only on a draft, and `SocialPosts#mark_posted` touches only
unposted rows. Two things differ from posts. `DeleteSocialPost` removes only a social post no network has claimed,
so one that went out cannot even be deleted. And `mark_posted` writes the time the last network finished, not the
earlier of the two.

## Alternatives

**Soft deletion, a trash bin or undo.** AA-290 left all three out. The design asks projects to archive rather than
delete, and asks nothing of the kind for posts.

**A published post going back to draft.** No operation or screen offers it. It would take the page and the feed
entry down but not what publishing sent: the cross-post, which AA-290 notes cannot be unsent, and the webmentions.

## Consequences

The schedule costs no column, and every reader of the live time filters on `status` first. A reader that forgets
treats a schedule as a date the post went out. AA-501 had to keep scheduled posts out of the `activities` view for
that reason.

A post can carry any date from the past, so its date is the one the author gave, not the day it reached the site.
The feeds and the pager order it by that date too.

Retracting a post means deleting it, and a delete takes what cannot come back. The webmentions it received came
from other sites and have no copy here. What it sent stays out: the cross-post on each network, now detached, and
every webmention it sent. The editor names how many webmentions a delete destroys before it asks to confirm.

A social post's `posted_at` moves from the time it was due to the time its last network took it, so a send that
retries shows the later time.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
