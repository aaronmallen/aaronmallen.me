---
id: "0132"
title: Send a social post to each connected account the owner ticks
status: active
created: 2026-10-08
area: [social, admin, db]
issue: "#793"
amended: ["#805", "#899"]
tags: [social, mastodon, bluesky, connections, delivery, composer]
---

# ADR 0132: Send a social post to each connected account the owner ticks

![Active][status]

## Context

Under [ADR 0040][0040] a social post targets networks, `social_posts.targets` holds a list of `network` values, and
each network gets one delivery row, unique on `(social_post_id, network)`. That works while each network has one
account, read from the environment.

Spec #790 moves the Mastodon and Bluesky credentials into the database and lets each network hold several accounts.
A network no longer names one account, so it can no longer say where a post goes or key the row that tracks it.

## Decision

A social post targets connected accounts, not networks. The composer lists each connected Mastodon and Bluesky
account, and the post goes to each one the owner leaves ticked. Since #805, a new post starts with the accounts the
browser remembers from the last post sent or scheduled, or with the first account when none of those is still
connected. A post being edited, or one shown again after an error, keeps its own picks.

Each picked account gets one delivery row, unique on the post and the connection. Everything [ADR 0040][0040] says of
a network's row now holds for an account's row: the claim, one job per row, the five retries, the resume from the
first part not sent, and the settle once each row has sent or failed. The job and the operation take a connection,
build the client from its credentials, and check each part against the limit of that account's network. The key on
each part names the connection in place of the network, so two accounts on one network never share a key.

The row keeps its network, so rows sent before this change, which have no connection to name, stay as history.

## Alternatives

**Send to every connected account, always.** It lost because the owner could not keep a post off an account, and a
second account is only of use when a post can go to it alone.

**One default account per network.** It lost because the composer would still pick networks, and posting from the
other account would mean changing the default first.

## Consequences

A new account shows in the composer the moment it connects. Since #805 it starts unticked once the browser
remembers other accounts, so a post goes to it only after the owner ticks it.

Delivery history has to outlive the account. Disconnecting deletes the connection, so it cannot take the account's
delivery rows with it.

A post due while none of its accounts is connected has nowhere to go. Since #899 it settles at once with a failed
row per target network and no connection, so it shows among the failed social posts.

[0040]: 0040-send-a-social-post-to-each-network-on-its-own-from-that-networks-delivery-row.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
