---
id: "0129"
title: Store MaxMind's country name beside each country code
status: active
created: 2026-10-08
area: [analytics, security, admin, mcp, db, lib]
issue: "#765"
tags: [analytics, security, geoip, maxmind, country, schema]
---

# ADR 0129: Store MaxMind's country name beside each country code

![Active][status]

## Context

Every place we keep a country holds a two-letter code: `analytics_events` and the two country rollups under
[ADR 0045][0045] and [ADR 0102][0102], and `sign_ins`, `sightings` and `known_devices` under [ADR 0124][0124].
Nothing maps a code to a name, so the geography cards, the Security rows and the MCP `read_analytics` tool show `US`
where a reader wants United States.

Spec #764 asks for the name. The GeoLite2 record we already read in `Analytics::GeoLite2::Countries#place` carries
it as `country.names.en`, and we throw it away.

## Decision

We keep the country's name from MaxMind beside each stored code, in a column of its own on each table that holds a
code. The lookup reads `country.names.en` along with `iso_code`, and the row saves both. A rollup keeps the name its
day's events carry. Readers show the name, and the code when a row has none.

We do not fill in names for rows saved before the change.

## Alternatives

**A locale file** mapping codes to names. A list kept by hand, beside a source that already names every country.

**A gem** that maps codes to names. A new dependency for one lookup MaxMind already does.

**`Intl.DisplayNames` in the browser.** It names the country only where a browser draws the page, so `read_analytics`
would still return a bare code.

**A `countries` table** with one row per code. Each lookup would upsert into it, and every query that shows a country
would join it.

## Consequences

The admin and MCP read a name with no lookup and no join, and the name tracks the database the weekly job refreshes.

The name repeats on every row that holds its code, most of all in `analytics_events`, which gains a row per view.

Rows from before the change show codes beside rows that show names, in the same card, until they age out. Raw events
and sign-ins go after 90 days, but rollups and known devices stay forever, so their old rows show codes for good.

Names come in English alone. If MaxMind renames a country, rows from before and after carry different names for one
code, and a card that groups by code has to pick one.

[0045]: 0045-count-visitors-with-a-daily-hash-and-no-cookies.md
[0102]: 0102-count-each-posts-unique-readers-with-an-undated-hash-kept-for-12-months.md
[0124]: 0124-keep-the-operators-raw-ip-and-user-agent-for-90-days-in-a-security-slice.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
