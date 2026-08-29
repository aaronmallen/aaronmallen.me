---
id: "0040"
title: Send a social post to each network on its own, from that network's delivery row
status: active
created: 2026-09-28
area: [db, lib, social, admin]
issue: AA-577
amended: [AA-814]
tags: [social, sidekiq, jobs, retry, mastodon, bluesky, idempotency]
---

# ADR 0040: Send a social post to each network on its own, from that network's delivery row

![Active][status]

## Context

A social post is a list of parts in order, sent as a thread to each network it targets: Mastodon, Bluesky or both.
AA-246 asked that one network failing never hold up the other. A failed network retries five times with growing
delays, a thread that fails partway resumes at the failed part without posting the earlier ones again, and a post
counts as posted once every network it targets has succeeded or failed for good.

## Decision

A social post holds ordered `social_post_parts` and one `social_post_deliveries` row per network, unique on
`(social_post_id, network)`. The delivery row is the claim, the progress and the result: `remote_ids` holds what
went out, `error` the last failure, and `failed` a network that gave up.

`Social::Jobs::SendDueSocialPosts` runs every minute. For each due post it claims each network's delivery and
queues one `Social::Jobs::DeliverSocialPost` per claim. That job retries five times and then gives up, which marks
the delivery failed. `Social::Operations::DeliverSocialPost` sends `parts.drop(delivery.remote_ids.size)`, so a
retry starts at the first part that has not gone out, and passes each part a key built from the post, the network
and the position, so the network can refuse a repeat.

A claim takes a delivery again once no job has touched it for 15 minutes, as long as it holds no error and has not
failed (AA-621). A post with any delivery row refuses edits and removal (AA-606).

A post settles once each target's delivery has sent every part or has failed. `settle` then sets it `posted` and
writes the time it settled into `posted_at`, over the time it was due.

A network is a client in `networks.all` (`Social::Providers::NetworksProvider`) and a value of the `network` enum.
Its client answers `post`, `within_limit?`, `engagement` and `configured?`.

## Alternatives

**One job that sends every network.** It lost because a failure on one network would retry the whole job, and so
repeat or hold up the network that worked. The spec "posts nothing to the other network from the failing
network's job" in `spec/slices/social/jobs/deliver_social_post_spec.rb` checks it.

## Consequences

One network going down costs the other nothing, and a retry never posts a part twice.

`posted` means settled, not sent. A post whose only network failed for good still reads posted, and its
`posted_at` is when it settled, not when it was due or when its first part went out.

The claim lands in Postgres and the job in Redis, in two steps. A job lost between them waits 15 minutes for the
next claim. A job still waiting in the queue after 15 minutes gets a twin, and only the resume and the key per part
keep the twin from posting a part again.

A network that finished while the other still retries holds a delivery with no error, so every 15 minutes the
claim takes it again and queues a job that sends nothing.

Once the send job claims a network, the operator can no longer edit or remove the post, not even to fix a typo
before a retry goes out.

A new network needs a client that answers the four methods, an entry in `networks.all`, and a value added to the
`network` enum and to `Blog::Types::NetworkName`.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
