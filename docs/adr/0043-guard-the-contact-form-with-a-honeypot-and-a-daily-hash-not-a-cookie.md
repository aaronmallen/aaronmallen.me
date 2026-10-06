---
id: "0043"
title: Guard the contact form with a honeypot and a daily hash, not a cookie
status: active
created: 2026-09-28
area: [config, analytics, contact, public, social]
issue: AA-601
amended: [AA-490, AA-505, AA-561, AA-708, AA-717, AA-749, "#200", "#204", "#463", "#504", "#532"]
tags: [concurrency, contact, csrf, honeypot, privacy, retention, spam, throttle, timer]
---

# ADR 0043: Guard the contact form with a honeypot and a daily hash, not a cookie

![Active][status]

## Context

AA-323 puts a form on `/contact`. It is a public write endpoint beside `/webmention` and `/pulse`, and the first one
a person types into. AA-323 asks for a honeypot, a limit per address, and enough to spot a flood later, without
keeping more about a visitor than analytics does.

A form usually wants a CSRF token, a token wants a session, and `Blog::SessionCookie.store` is a cookie on every page
that mounts it. The public site promises no consent banner, no analytics cookie and no third-party script. Only
`slices/admin` and `slices/mcp` mount a session. `Public::Action` injects `admin.auth.session_reader` to read the
operator's cookie, never writes one, and marks a page it draws for the signed-in operator `private, no-store`, while
the public slice sends `Vary: Cookie` on every response. AA-664 records that split.

The site never keeps a raw address. `Analytics::Operations::HashVisitor` turns an address into a daily salted SHA256,
and `analytics` exports it.

## Decision

The public slice gains no session and sets no cookie. `/contact` takes a form guarded by a same-site check, a
honeypot, a signed timer (#504) and a throttle counted on a daily hash of the sender's address.

**No CSRF token, and a header check in its place.** A token stops another site spending a signed-in visitor's
privilege, and `POST /contact` has no privilege to spend. What a forged post can still do is multiply the throttle:
a page elsewhere that posts from each reader's browser brings a fresh address, and a fresh allowance, per reader.
So `Public::Action#refuse_cross_site` answers 403 when `Sec-Fetch-Site` is present and is not `same-origin` or
`none`, or, without it, when `Origin` is present and is not the site's. `Messages::Create` and `Visits::Create` run
it. GET pages and `/webmention`, which other sites are meant to call, do not. AA-749 added this.

**The honeypot is a text field a person never sees.** The page styles the `reference` field out rather than typing
it `hidden`, and keeps it off the tab order, out of the accessibility tree and away from autocomplete. Filled, the post
stores nothing, and the sender reads the same confirmation a real one reads. Telling a bot why it failed teaches the
next request how to pass. The `spam` status is what the operator marks after reading, so a catch is dropped rather
than filed.

**A signed stamp times the form.** The honeypot let 14 spam messages through in the first week, so #504 added a timer
beside it. The contact page draws a hidden `stamp` field: the time it rendered, in milliseconds, and an HMAC of that
time keyed by `app_secret`. `Public::Operations::IssueContactStamp` signs it and `Public::Operations::CheckContactStamp`
checks it (#532). `Messages::Create` checks it beside the honeypot, and a post sent sooner than `minimum_submit_seconds`
(3 unless set), later than `stamp_expiry_hours` (24 unless set), or with no stamp or a forged one, stores nothing and
reads as sent, for the same reason a filled honeypot does. A form sent back with errors carries a new stamp. The stamp
needs no cookie, no session and no script, and the page already sends `no-store`, so no cache hands one stamp to many
readers.

**The throttle counts stored messages by hash over a window.** `messages.visitor_hash` holds `HashVisitor` of the
address alone, since a sender writes the user agent and a new one each post would make a new sender (AA-708). There
is no counter table and no Redis key: the rows are the count and the flood record. The limit and the window are
settings with defaults in `config/settings.rb`, so a file that lost the line throttles on the shipped number rather
than raising (AA-505). `ThrottleWindow` refuses a window of a day or more. The salt turns at midnight, so a longer
window would expire without saying so.

**An IPv6 sender is its /64.** One home or phone holds a whole /64, so a hash of the full address hands a script
2^64 senders. `Blog::ThrottleKey` masks an IPv6 address to its /64 and reads a mapped IPv4 address as IPv4 before
`Messages::Create` hashes it (#200). Since #463 client registration, `/webmention` and the beacon's throttle hash
the same key, so every public throttle counts a /64 as one sender.

**A total cap covers every sender together.** `total_throttle_limit`, 20 an hour unless set, stops a script spread
over many addresses or networks, as `/webmention` already does. Messages filed as spam count toward it: they are
rows in the inbox like any other, and leaving them out would let a flagged sender flood unchecked (#200).

**A throttle that counts its own rows counts and writes under one advisory lock.** `Contact::Relations::Messages#claim`
opens a transaction, takes `pg_advisory_xact_lock` on the whole table, since the total cap counts every sender, then
counts and inserts (AA-490, #200). A row lock would hold nothing, since a sender's first message has no row yet. The
beacon and `/webmention` take the same shape (AA-717): `AnalyticsEvents#claim` locks on the address hash, and
`WebmentionReceipts#claim` locks the whole table, since it also caps every sender together. Inside that lock the
receipt's conditional upsert decides only the dedupe.

**A webmention sent again inside the window gets 429.** A receipt keys on the post and the source, and the upsert
stamps it again only once it falls outside the window. So the same pair sent again inside the window writes nothing
and queues no verify fetch, and `WebmentionRepo#claim_receipt` reads the empty upsert as `Failure(:throttled)`. The
sender gets 429, not 202, so it knows to try later instead of thinking its edit or delete went through. After the
window the pair counts as a first send: 202 and a verify job (#204).

**A throttled person and a caught bot see different pages.** The bot is told it worked. The person gets 429, the
contact page, and a line saying they have sent enough for now. It never names the limit.

**What each table keeps about a visitor.** A message keeps its `reply_to`, subject, body and hash, and nothing
deletes one: `contact` exports no delete, and the admin can only list and mark. A webmention receipt keeps a hash
until `ReapWebmentionReceipts` drops it once it falls outside the throttle window. An analytics event keeps its
hashes for 90 days.

## Alternatives

**Turn on sessions and ship a CSRF token.** The Hanami answer, three lines, and every form the public site grows
inherits it. It puts a cookie on every public page to guard an endpoint with no privilege behind it.

**Rack::Attack.** A gem built for this, counting outside the app and refusing before it runs. It keys on the raw
address, which the site refuses to hold. Handing it the hash means hashing in middleware, above the slice that owns
the operation, for a throttle still set by hand: a dependency for one endpoint and a second place the count lives.

**A hosted captcha**, reCAPTCHA or Turnstile. It stops far more than a honeypot and costs almost nothing to write. It
is a third-party script on a public page and shows every visitor's request to somebody else.

**A counter table keyed by hash.** It keeps the bookkeeping off the message and counts refused attempts too. It is a
second table to write and prune on a site whose inbox already says who sent too much.

**Key the throttle on the address and the user agent**, as the analytics visitor count does. The sender picks the
header, so a new value each post always counts zero.

**Count, then write in a second statement.** What `/webmention` and the beacon did before AA-717. Requests that read
the count before any of them writes all pass, one extra row for each request in flight.

## Consequences

No cookie, no banner and no third party on the public site.

A message's hash stops meaning anything at midnight: nothing matches it after the salt turns, and nothing turns it
back into an address. What an old hash still says is that two rows came from one address on one day.

Nothing ends a message. AA-323 asked whether read and spam messages stay for ever or go after 90 days the way
analytics events do, and left it open. Until someone decides, a stranger's address and hash stay until someone
deletes the row by hand.

Analytics shares `hash_visitor`, so the daily hash is not its own. `public` and `mcp` both import it, and no check
asks whether the next caller should.

Everyone behind one address shares one allowance, whatever browser they use: an office, a campus, a VPN, a carrier
NAT. Whoever writes first spends the others' share, and they can only wait.

Everyone in one IPv6 /64 shares one allowance too, which on a shared network can take in strangers.

The honeypot catches a bot that fills every field. One that renders the page skips it, and the timer is next: it catches
a bot that posts the moment it loads the form or never loads it, and passes one that fetches the page and waits. One
stamp serves any number of posts until it expires (#504). Past both, the throttle is all that is left. The throttle
stops a repeat, not an attacker: a sender with many addresses passes until the total cap refuses everyone, real senders
included, and midnight is a fresh count whatever the window says. The header check stops a browser on another site's
page, not a script, since a post with neither header goes through.

Only stored rows count, so a bot that fills the honeypot or fails the timer leaves no trace at all. A person who
sends within the minimum time, or from a page left open past the expiry, loses the message and is told it went
through (#504).

The lock holds the whole table, so a flood makes every sender wait its turn.

A site that edits or deletes a post soon after it sent the first webmention has to send again once the window
closes. Until then the stored mention shows the first version.

The day the public slice grows an action that acts for a signed-in visitor, this record breaks and needs a new one.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
