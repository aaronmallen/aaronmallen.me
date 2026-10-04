---
id: "0045"
title: Count visitors with a daily hash and no cookies
status: superseded
created: 2026-09-28
area: [analytics, public, admin, assets, db]
superseded-by: "0102"
issue: AA-613
amended: [AA-470, AA-472, AA-485, AA-492, AA-527, AA-537, AA-552, AA-714, "#210", "#183", "#371"]
tags: [analytics, privacy, beacon, retention, geoip, throttle]
---

# ADR 0045: Count visitors with a daily hash and no cookies

![Superseded][status]

## Context

The analytics spec (AA-210) wants to know which pages people read, for how long, and where they come from. The usual
answer is a third-party script that follows visitors across the web, and the site will not carry one. The dashboard
promises "self-hosted rollups, no third-party scripts". It shows views, visitors, read time, bounce, referrers and
countries over at most 30 days. A bounce is a visitor with one view that day.

Whatever we store now fixes what we can learn later. Old events cannot be hashed again or tied to a visitor again.

The beacon takes posts from anyone. Left open, fifty anonymous posts wrote fifty rows with paths and titles the
sender chose (AA-470), and a sender who changed the user agent on each post escaped a throttle keyed on the visitor
(AA-714).

## Decision

We count visits with a first-party beacon and a visitor hash that changes every day. We never store an address, and
analytics sets no cookie.

**What the beacon sends.** Public pages load `app/assets/js/public/beacon.js`, and admin pages never do. It posts
through `navigator.sendBeacon` to `/pulse`, a neutral path. Each page load mints a random view token, kept nowhere.
The view carries the path, the title and the referrer's origin. Each time the page hides, the beacon sends a read
with the whole time the page has been on screen, under the same token (AA-492, AA-552).

**What the site takes.** `Public::Actions::Visits::Create` reads at most 8 KB, refuses a beacon from another site,
and turns away a path the public router does not answer (AA-470). `Analytics::Operations::RecordVisit` skips a hit
while the operator is signed in, and from a known bot or a client with no user agent. It keeps only the referrer's
host, and none when it is our own. A read lands on the newest view with its token and today's or yesterday's visitor
hash, so a tab left open past midnight still counts (#183). It is capped at 20 minutes (AA-527), and the store keeps
the greater of the old and new time, so a late or repeated read never lowers it.

**Who a visitor is.** `Analytics::Operations::HashVisitor` hashes `analytics_salt`, the site day, the address and the
user agent. The salt is its own setting of 64 characters or more, and the app refuses to boot if it repeats
`app_secret` (AA-472). The address space is small enough to walk against stored hashes, so a salt shared with the
secret that signs the session would let one leak read every visitor back and open the admin with it.

**The throttle.** A second hash leaves out the user agent, and at most `analytics.throttle_limit` events a window
may come from one such address hash, counted under an advisory lock (AA-714).

**Country and retention.** A local copy of the MaxMind GeoLite2 Country database gives each visitor's country, and a
weekly job refreshes it with a license key from settings. We keep raw events for 90 days and daily rollups forever.
The nightly rollup builds every day that has none, rebuilding each day whole (AA-485), and the prune stops at the
first day with no rollup. The dashboard reads today from raw events.

**What #210 added.** [ADR 0087][0087] widens what we keep: a second visitor hash salted by the calendar month, a
`ref` source, the referring path from our own site, scroll milestones and a device class in place of the user
agent. Each page's breakdowns roll up and stay forever.

## Alternatives

**Server-side only.** Rack middleware records every request with the same daily hash. It counts visitors without
JavaScript, but it cannot measure read time or bounce, and it has to filter every bot by user agent.

**Both the beacon and the middleware.** The most complete count, but two write paths to keep in step, and beacon
events to match against logged views.

**Throttle on the visitor hash**, as AA-470 first did. A sender who changes the user agent each time counts zero.

**Keep raw events 30 days**, the dashboard's longest range. No new report could reach back past a month.

**Keep raw events forever.** The table keeps growing and holds visitor hashes with no end date.

**Country from a host or CDN header** such as `CF-IPCountry`. It works only behind that provider, and gives nothing
in development.

**No geography at all.** The Geography card would have nothing to show.

**Skip bots only, or skip nothing.** The operator's own proofreading would then count as reads.

## Consequences

No consent banner, no analytics cookie and no third-party script. The count works on any host.

Visitors without JavaScript, or with strict blockers, are not counted. The numbers run low, and we cannot tell by how
much. A person who comes back tomorrow is a new visitor, so counts across days are sums of daily counts.

A read sent after a second midnight matches no view, since the hash has turned twice. The view stays with no read
time. A read that lands on yesterday's view after the nightly rollup reaches the raw event but not that day's rollup.

Readers behind one shared address share one throttle, and past it their views are dropped.

A failing rollup holds raw events, and their hashes, past 90 days until it succeeds.

Country depends on a MaxMind key and a weekly job. Without the key, views still count and countries show as unknown.
The file sits under `tmp/maxmind`, so the web process and the worker must share a disk.

Honeybadger sees a failing beacon request. `Blog::Providers::HoneybadgerProvider::FILTER_KEYS` strips the address
headers, the cookie, the salt and the visitor hash first.

The deploy carries a second secret, and the app does not boot without it. Rotating it signs nobody out, and costs one
day's count, where a visitor counts twice.

Adding an analytics cookie or storing addresses breaks this record and needs a new one.

[0087]: 0087-widen-what-analytics-keeps-with-a-monthly-hash-and-roll-up-each-pages-breakdowns.md
[status]: https://img.shields.io/badge/0102-black?style=for-the-badge&label=Superseded&labelColor=orange
