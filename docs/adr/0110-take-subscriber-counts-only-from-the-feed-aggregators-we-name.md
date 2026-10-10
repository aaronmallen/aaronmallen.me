---
id: "0110"
title: Take subscriber counts only from the feed aggregators we name
status: active
created: 2026-10-04
area: [analytics, lib]
supersedes: ["0106"]
issue: "#470"
amended: ["#911"]
tags: [analytics, feed, atom, subscribers, user-agent, aggregators]
---

# ADR 0110: Take subscriber counts only from the feed aggregators we name

![Active][status]

## Context

[ADR 0106][0106] stores a subscriber count for any user agent that says "N subscribers". The parser knows Feedly,
Inoreader and NewsBlur, and makes a name from the start of any other user agent. Every new name adds its own row
for each day and feed. Every feed fetch reaches the Pi, so any client can add rows without end by sending a made up
name and a count. ADR 0106 weighed forged counts, not the rows that made up names add.

## Decision

Only the aggregators in `Analytics::Operations::ParseAggregator::KNOWN` (the name #911 corrected) store a subscriber
count: Feedly, Inoreader and NewsBlur. Any other user agent counts once a day as a reader by its daily hash, whatever
count it names. The rest of ADR 0106 stands: the feed fetch count, the readers' daily hashes, the feed skipping the
cache, and outbound clicks.

Counting a new aggregator means adding it to `KNOWN`.

## Consequences

Subscriber rows grow with the days, the feeds and the three names, not with whatever clients send.

An aggregator we do not name, such as Feedbin, counts as one reader a day however many people follow the feed
through it, so feed subscribers run low by an amount we cannot know until somebody adds it to `KNOWN`.

A named aggregator's count is still whatever its user agent says, and anyone can still forge it.

[0106]: 0106-count-feed-fetches-on-the-server-and-capture-outbound-clicks-from-the-beacon.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
