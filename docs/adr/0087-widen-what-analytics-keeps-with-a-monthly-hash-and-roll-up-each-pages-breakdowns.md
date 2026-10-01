---
id: "0087"
title: Widen what analytics keeps with a monthly hash, and roll up each page's breakdowns
status: active
created: 2026-10-01
area: [analytics, public, mcp, assets, db]
issue: "#210"
tags: [analytics, privacy, beacon, retention, reach, ref, scroll, device-class, rollups]
---

# ADR 0087: Widen what analytics keeps with a monthly hash, and roll up each page's breakdowns

![Active][status]

## Context

[ADR 0045][0045] lists what analytics keeps and says that adding to it needs a new record. Spec #208 asks the
numbers to answer more. Visitors sum day by day, so a range has no true reach. Referrers and countries cover the
whole site, so with two posts drawing traffic nobody can say which one Reddit sent people to. 82% of visits arrive
with no referrer, and nothing says how far anyone reads, how they move between pages, or on what device.

Raw events go after 90 days and rollups stay forever, so whatever only raw events hold is gone after 90 days. An
old event cannot be hashed again or split by a field it never stored.

## Decision

We keep five more things about a view, and none of them names a visitor for longer than a calendar month.

**A monthly visitor hash.** Each view stores a second hash beside the daily one, salted by the Chicago calendar
month ([ADR 0018][0018]) where the daily hash takes the site day. It hashes the same salt, address and user agent.
Daily visitors count as they do now. Reach counts each reader once a month, exact within a month and summed across
months, so a reader on Sep 30 and Oct 1 counts twice.

**A `ref` source.** The beacon reads `ref` from the page's query string and sends it apart from the path, so the
stored path never carries it. Any short, plain token counts, hand-typed ones too, and the site drops anything else.
Crossposts and the Atom feed tag their links this way, so a tap inside an app still credits where it came from.

**The referring path on our own site.** When the referrer is our own site, the beacon sends its path and the view
stores it. An outside referrer stays host only.

**Scroll milestones.** The beacon reports the deepest of 25, 50, 75 and 100% a view reached, under the view's
token the way a read goes, and the store keeps the greater value.

**A device class.** `Analytics::Operations::RecordVisit` sorts the user agent into desktop, mobile, tablet or
in-app with our own list of patterns, and stores only the class. The raw user agent is never stored.

**Hybrid storage.** Per-page sources, countries, referrer hosts, device classes, scroll milestones and monthly
reach roll up and stay forever. Hourly counts, `since:`, the read-time spread and navigation (internal referrers,
entry and exit pages) read raw events, so they reach back 90 days and no further.

## Alternatives

**A cookie.** It would count a reader across days and months exactly, but analytics sets no cookie, and a cookie
breaks [ADR 0045][0045] outright.

**A weekly or yearly hash.** A weekly reach would still sum across weeks inside a month. A year links a reader's
views across twelve months, and #208 rules out any visitor identity longer than a month.

**Roll up every dimension.** Hours, read times and paths through the site would keep forever too. Read-time spread
needs each view's time, and entry and exit pages need each visitor's views in order, so a rollup would have to fix
its buckets and questions in advance. Rollup tables would grow by every pair of dimensions we cross.

**Keep raw events longer.** Every reply could reach back further, but raw events hold both hashes and the paths a
reader took, and [ADR 0045][0045] keeps visitor hashes for 90 days and no longer.

**A device detection gem.** It knows more devices than our list, but it is a dependency for four classes. We match
with our own patterns and take on no new gem.

## Consequences

Reach is real within a month. Across months it is a sum, and a reader who stays from one month into the next counts
twice. We give up exact reach across more than one month.

The monthly hash ties a reader's views together for up to a month, where the daily one stops at midnight. It sits
in raw events for 90 days, and anyone holding the salt can walk the address space against it as they could the
daily one.

Hourly counts, `since:`, read-time spread and navigation stop at 90 days. A question about last spring's peak hour
has no answer.

New columns start empty and new rollups reach back only as far as raw events when they first run. Nothing is filled
in for older days.

Our device patterns miss what they do not name. A new in-app browser counts as mobile until we add it.

A `ref` anyone can type means anyone can invent a source. We count what arrives and do not check it.

Rotating the salt now costs a month's reach as well as a day's visitors, since the reader counts twice in each.

[0018]: 0018-run-the-site-on-one-time-zone-written-into-the-schema-as-a-literal.md
[0045]: 0045-count-visitors-with-a-daily-hash-and-no-cookies.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
