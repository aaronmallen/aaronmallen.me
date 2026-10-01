---
id: "0079"
title: Store a mention as a token expanded at delivery
status: active
created: 2026-09-30
area: [admin, social]
issue: "#120"
amended: ["#225", "#226"]
tags: [social, mentions, mastodon, bluesky, delivery, directory, did]
---

# ADR 0079: Store a mention as a token expanded at delivery

![Active][status]

## Context

Spec #6 adds mentions to social posts. The same person is `@alice@mastodon.social` on Mastodon and
`@alice.bsky.social` on Bluesky, but the composer writes one body for both, and `social_post_parts.body` is one
`non_blank_text` column that both networks read. A mention has to be stored once and come out as a different handle
on each network.

Bluesky does not read `@handle` from the text. A mention links only when an `app.bsky.richtext.facet#mention` facet
names the account's DID, so something has to know each person's DID.

Nothing in the app knows about other people yet.

## Decision

A mention lives in the part's body as a token, such as `@{alice}`, that names a person in the directory. The body
stays one column and one text for both networks.

The token expands when a network reads the post. `Social::Operations::DeliverSocialPost` expands it for the network
it sends to (ADR 0040): the person's handle where they have one, their plain name where they do not. The Bluesky
client adds a mention facet naming the DID. The counter in `Admin::Operations::CountNetworkLengths`, the limit
check before delivery and the preview measure and show the expanded text for each network, not the token.

A token that names nobody in the directory is refused when the post is saved.

The directory is a table in the social slice. The operator fills it in from the admin, with whichever handles a
person has, through one people form that the people page and the composer's `@` list both show. Each handle field
can search its network for accounts, and picking one fills the handle, and the name when the operator has not typed
one. A pick only fills the form, and nothing joins the directory until the operator saves. We store each person's
Bluesky DID, resolved from their handle when the person is saved, and never look it up at send time.

## Alternatives

**A stored body per network.** Each part keeps one body for Mastodon and one for Bluesky, written out in full. It
lost because it needs a migration and doubles what the composer, the preview, the queue and suggestion review
read. It also cuts against ADR 0063: a suggested edit names text in one body, so a fix to words both bodies share
takes two edits.

**Resolve the DID at send time.** Delivery looks up the Bluesky handle each time it sends. It lost because a
handle can change, and a stored DID keeps the mention pointing at the same account when it does. Looking it up at
send time also adds a network call that can fail to every delivery.

## Consequences

The token is plain text, so the operator can type a mention by hand with scripts off (ADR 0055), and a suggested
edit still names text in one body (ADR 0063). The `@` dropdown inserts the token, and since #225 it ends with an
**Add New** row. The row opens the people form in a dialog over the composer, with the name taken from what follows
the `@`. A good save adds the person to the dropdown and puts their token in place of what the operator typed, and
the post stays as it was whether the operator saves or cancels. With scripts off a plain **Add New** link under the
post leads to the people page, and the post is lost on the way there.

Since #226, search asks Bluesky's public actor search and the Mastodon instance the site posts from, which resolves
accounts on other instances. A network with no credentials shows no search box, and one that fails or rate limits
shows an error in the results and leaves the field as it was. Search needs scripts, so with scripts off the operator
types each handle. Avatars load straight from each network over HTTPS, which the admin's content security policy
already allows.

What the operator types is no longer what a network receives. Everything that measures or shows a post has to
expand the token first, and anything new that reads `body` for a network has to do the same.

A suggested edit or a raw read through the MCP server sees the token, not the handles.

A stored DID keeps a Bluesky mention linked through a handle change, but the handle text comes from the directory, so
a post shows the old handle until the operator edits the person.

Removing a person from the directory leaves their token in every post already saved. Saving refuses such a token,
but delivery of a queued post still has to handle it.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
