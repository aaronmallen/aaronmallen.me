---
id: "0102"
title: Count each post's unique readers with an undated hash kept for 12 months
status: active
created: 2026-10-03
area: [analytics, public, admin, config, db]
supersedes: ["0045"]
issue: "#371"
amended: ["#463"]
tags: [analytics, privacy, gdpr, legitimate-interest, unique-readers, retention, salt]
---

# ADR 0102: Count each post's unique readers with an undated hash kept for 12 months

![Active][status]

## Context

Spec #364 asks how many people have read a post since it went up. Nothing can say. [ADR 0045][0045] names a visitor
for a day and [ADR 0087][0087] for a calendar month, so a reader in March and the same reader in April count as two
people. Both records rule out any visitor identity that lasts longer.

A hash that never changes and stays tied to one reader is likely personal data under GDPR, even with no address
stored. Keeping it needs a lawful basis, a time limit and a notice that tells readers it exists.

## Decision

We count each post's unique readers for the 12 months after it goes up, with a hash that carries no date. The rest
of [ADR 0045][0045] and [ADR 0087][0087] stands: the beacon, the daily and monthly hashes, the throttle, bot and
sign-in skips, and 90 days of raw events. Since #463 the throttle hashes `Blog::ThrottleKey` of the address, which
cuts an IPv6 address to its /64, so one host cannot spread its hits over a network.

**The hash.** When a view of a published post arrives within 12 months of its publish date, the analytics slice
hashes a salt, the address, the user agent and the post's path. The path in the hash means one reader's hashes on
two posts do not match, so nobody can follow a reader from post to post.

**Its own table.** The hash lands in a table holding only the path and the hash, unique on the pair. It holds no
time and no link to an event, so a row cannot be tied to a view, a day or a raw event. A reader counts once per
post.

**Its own salt.** The hash takes a new salt setting of 64 characters or more, and the app refuses to boot when it
repeats `analytics_salt` or `app_secret`, as `config/settings.rb` checks those two today. A salt rotation splits
every reader in two, so this salt must be free to stay put when `analytics_salt` rotates. A leak of one secret
still reads back neither of the others.

**The 12 month limit.** A view after a post turns 12 months old stores nothing. The nightly job then saves the
post's final count in a table keyed by path and deletes its hashes in the same transaction. The count stays
forever. The hashes never outlive the window, except while a failing nightly run holds them.

**The legitimate interest test.** GDPR Article 6(1)(f) is the basis, and the three parts of the test read:

- *Purpose.* The owner wants to know how many people read each post, to decide what to write next. That is a
  real and lawful interest of anyone who publishes.
- *Need.* No milder means gives the number. Monthly reach summed across months counts a returning reader again
  each month, and a cookie stores something on the reader's device. The hash keeps the least that answers the
  question: no address, no time, no trail through the site, and one post per hash.
- *Balance.* A reader expects a blog to count its readers. The hash cannot be turned back into an address without
  the salt, cannot match a reader across posts, and goes after 12 months. Nothing lands on the device. A public
  privacy page says what we keep, why and for how long, and how to ask about it.

## Alternatives

**A cookie.** It counts a reader exactly across any span, but analytics sets no cookie, it puts something on the
device, and it likely needs a consent banner.

**An estimate from summed monthly reach.** It needs no new data and no GDPR work, but it counts a reader once for
every month they come back, so it overstates the people a post reached by an amount we cannot know.

## Consequences

A post gets a true count of the people who read it in its first year. After that the count is final.

The hash names a reader of one post for up to a year, far longer than the month [ADR 0087][0087] allowed. Anyone
holding the salt can walk the address space against it for any post, as they could the daily hash.

A post already up when this ships counts from ship day only, and a post past 12 months gets no count.

The deploy carries a third secret, and the app does not boot without it. Rotating it splits every open window's
readers in two.

A reader who changes address or browser counts again, and readers behind one address with one browser count once.

The site owes its readers a privacy page and an answer to requests about their data. Widening this hash, keeping
it past 12 months or adding a cookie needs a new record and a new legitimate interest test.

[0045]: 0045-count-visitors-with-a-daily-hash-and-no-cookies.md
[0087]: 0087-widen-what-analytics-keeps-with-a-monthly-hash-and-roll-up-each-pages-breakdowns.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
