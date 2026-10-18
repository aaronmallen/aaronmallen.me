---
id: "0143"
title: Send outside links in social posts through aa.cool short links
status: active
created: 2026-10-10
area: [social, admin, db]
issue: "#1066"
tags: [social, links, short-links, redirect, aa.cool, clicks, webmentions, bluesky, delivery]
---

# ADR 0143: Send outside links in social posts through aa.cool short links

![Active][status]

## Context

Spec #1064 has `aa.cool` shorten links as well as share files. Links in my social posts point at other people's
sites, and I cannot tell whether anyone follows them. Long links eat Bluesky's character limit. When I want to hand
someone a link I can say out loud, I use a third party shortener.

[ADR 0106][0106] turned down sending outbound links through a redirect on the site: readers see our address where
they expect the link's own, each click takes an extra hop, and a redirect anyone can point anywhere needs signed
links. That record weighed links in blog posts. It still holds there, since shortening a post's links would break
the webmentions it sends.

## Decision

We send each outside link in a social post through its `aa.cool` short link. This sets aside, for social posts,
the part of ADR 0106 that turned down a redirect through the site.

**At delivery.** `Social::Operations::ExpandForNetwork` swaps each link for its short link when a post sends, with
the other tokens [ADR 0079][0079] expands there. The stored parts keep the long links I typed. A link whose host
the site owns ([ADR 0014][0014]) stays long, so webmentions keep working, and a link already on `aa.cool` sends as
typed. A link I shortened before reuses its code. Any other link gets a new random code and shows in the admin
Links tab. The counter and preview count a short link's length without making one. Posts sent through MCP take the
same path.

**Only I make links.** Short links come from the admin and from my own posts at delivery, never from a visitor, so
no code sends anyone to a place I did not pick. That answers the open redirect without signing links.

**A `302`.** `aa.cool/<code>` answers `302` to the link's destination, so I can point a code somewhere new later.
Cloudflare caches neither the redirect nor its 404, as for shares (ADR [0142][0142]). Each click from a browser counts,
and a known bot does not, by the check [ADR 0045][0045] uses for page views.

**One set of codes.** A `short_codes` table holds every code on `aa.cool`. Shares and short links each point at
one, so `aa.cool/talk` names one thing, and Postgres keeps codes unique across both ([ADR 0017][0017]). Short
links live in the shares slice (ADR [0141][0141]), in a `short_links` table, since `slices/links` already holds record
links.

## Alternatives

**Keep ADR 0106 for social posts too.** The beacon sees no click made on Mastodon or Bluesky, so I would never know
whether anyone follows a link, and long links would keep eating Bluesky's limit.

**A third party shortener.** It is what I use today, and its links name somebody else's host, not mine.

**A `301`.** Browsers keep a `301`, so a code I point somewhere new would still send some readers to the old place.

**A code column on each table.** Postgres cannot keep a value unique across two tables with a plain index, so a
file and a link could both claim `talk`.

## Consequences

I can see how many people follow each link I post, and Bluesky posts keep the room the long links took.

Readers see `aa.cool` where they expect the link's own host, and each click takes a hop through the Pi. That is the
cost ADR 0106 named, and we take it for social posts.

Every sent post now leans on `aa.cool`. Deleting a link, or `aa.cool` going down, breaks every sent post that used
it, and the delete confirm does not say so.

Mastodon builds a card from a post's first link, and that link now redirects. It should follow the `302` to the
real page, but nobody has checked.

Each new outside link a post sends adds a row to the Links tab, whether I meant to keep it or not.

[0014]: 0014-build-every-absolute-url-from-the-site-setting.md
[0017]: 0017-enforce-rules-over-stored-state-in-postgres-not-in-contracts.md
[0045]: 0045-count-visitors-with-a-daily-hash-and-no-cookies.md
[0079]: 0079-store-a-mention-as-a-token-expanded-at-delivery.md
[0106]: 0106-count-feed-fetches-on-the-server-and-capture-outbound-clicks-from-the-beacon.md
[0141]: 0141-keep-file-shares-in-a-shares-slice-with-their-own-bucket.md
[0142]: 0142-serve-shares-on-their-own-host-picked-in-config-ru-and-let-no-cache-keep-them.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
