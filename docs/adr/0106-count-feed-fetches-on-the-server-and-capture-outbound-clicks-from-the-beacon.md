---
id: "0106"
title: Count feed fetches on the server, and capture outbound clicks from the beacon
status: active
created: 2026-10-03
area: [analytics, public, admin, assets, db]
issue: "#376"
tags: [analytics, privacy, feed, atom, subscribers, user-agent, clicks, beacon, cache, cloudflare]
---

# ADR 0106: Count feed fetches on the server, and capture outbound clicks from the beacon

![Active][status]

## Context

Spec #365 names two kinds of reader analytics never sees. Feed readers fetch the Atom feeds but run no JavaScript,
so they never post to `/pulse`, and the bot filter in `Analytics::Operations::RecordVisit` drops `feedly` and
`feedfetcher` anyway. Readers who follow a link out of a post leave no trace.

[ADR 0045][0045] turned down counting on the server for page views, since it cannot measure read time and has to
sort bots by user agent. [ADR 0102][0102] covers only the per post hash. For a feed the beacon is not an option, and
the user agent is the data: Feedly, Inoreader and NewsBlur name their subscriber count in it.

[ADR 0090][0090] lets Cloudflare keep public pages for five minutes. The feeds send no `Cache-Control`, so its first
rule passes them through today, but only because nothing marks them. A feed fetch Cloudflare answers from its cache
never reaches the server to be counted.

## Decision

We count feed fetches on the server, and outbound clicks through the beacon. Neither adds a cookie or stores an
address.

**Feed fetches.** The writing feed and each tag feed count, each under its own path, through code of their own outside
`RecordVisit`. The count runs before the `304` halt in `halt_if_feed_unchanged`, since a feed reader that
already holds the feed polls with `If-None-Match` and gets `304`. A signed in fetch adds nothing.

**Aggregators.** A user agent that names a subscriber count stores that count for its aggregator, its feed and the
day. The parser knows Feedly, Inoreader and NewsBlur, and takes any other user agent that says "N subscribers".
A later fetch on the same day replaces the count, so each aggregator keeps its latest number.

**Other feed readers.** A fetch with no subscriber count counts once a day per reader, by the daily hash from
`Analytics::Operations::HashVisitor`. Those hashes follow [ADR 0045][0045]: kept 90 days at most, while the daily
count stays forever. Feed subscribers for a day are the aggregators' counts plus these readers.

**The feed skips the cache.** This amends [ADR 0090][0090]. The feeds send `Cache-Control: private, no-cache`, set
before the `304` halt so a `304` carries it too. Cloudflare keeps no answer, and every fetch reaches the server. A
feed reader still holds its copy and asks again with its `ETag`, so a fetch that finds nothing new costs a `304`.

**Outbound clicks.** On a post page the beacon listens for clicks on links whose host is not our own, and sends a
`click` event under the view's token, as a read and a scroll go. It carries the link's host and path. The query
string and fragment never leave the page, since a query can carry a token or a name. A link within the site sends
nothing: the referring path covers it. `visit_contract.rb` checks the event. Clicks roll up per day, post and link,
and stay forever like the other rollups.

## Alternatives

**Cloudflare logs.** They see every request, feed fetches included, with no change to the cache. Raw request logs
need Logpush, an Enterprise feature, and the count would work only behind that one provider and never in
development, the cost [ADR 0045][0045] weighed against a country header.

**A redirect through the site for each outbound link.** The server would count every click, script or no script.
It rewrites every link in every post, shows our address where a reader expects the link's own, adds a hop to each
click, and opens a redirect anyone can point anywhere unless we sign each link.

**Keep the feed in the cache for a shorter time.** It spares the Pi some fetches, but every fetch Cloudflare
answers is a feed reader we do not count.

## Consequences

The owner can see how many people follow the feeds and which links readers use, with no new cookie and no stored
address.

Every feed fetch now reaches the Pi. Aggregators poll often, so the feeds draw more requests than any page Cloudflare
keeps.

A subscriber count is whatever the user agent says. Anyone can send "Feedly ... 1000000 subscribers", and a forged
fetch late in the day replaces the real count. We take what arrives and do not check it.

A reader on two feeds, or on an aggregator and a desktop reader, counts once in each. Feed subscribers run high by
an amount we cannot know. A desktop reader on a new address or user agent counts again, as a visitor does.

Clicks share the beacon's limits. Readers without JavaScript, a link opened from the context menu and a click the
browser drops on leaving all go uncounted.

A cache rule that starts keeping the feeds breaks the count, and the code cannot tell. Storing more of a click than
its host and path needs a new record.

[0045]: 0045-count-visitors-with-a-daily-hash-and-no-cookies.md
[0090]: 0090-let-cloudflare-keep-anonymous-public-pages-for-five-minutes.md
[0102]: 0102-count-each-posts-unique-readers-with-an-undated-hash-kept-for-12-months.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
