---
id: "0124"
title: Keep the operator's raw IP and user agent for 90 days in a security slice
status: active
created: 2026-10-07
area: [admin, api, mcp, config, db]
issue: "#701"
tags: [security, privacy, ip, user-agent, retention, geoip, slices, sign-in, api-tokens, mcp]
---

# ADR 0124: Keep the operator's raw IP and user agent for 90 days in a security slice

![Active][status]

## Context

Spec #700 wants a security page that shows each device and place that has reached the admin. Today a GitHub
sign-in, a wrong account, an API token call and an MCP client call leave nothing but a `last_used_at` time. If
someone stole a token, nothing would say where they used it from.

The site has never kept an address. [ADR 0045][0045] and [ADR 0102][0102] count visitors by hashes and never store
the address, and [ADR 0010][0010] keeps the address out of logs and Honeybadger. Those records are about visitors,
but they name no exception, so a reader would take them as a rule for every request.

The rows come through three doors: `admin` for sign-ins, `api` for tokens and `mcp` for MCP clients. [ADR
0001][0001] lets a presentation slice own only the rows its own door needs.

## Decision

We keep the raw IP and user agent of the operator's own access, and nothing else. The exception covers:

- each GitHub sign-in, sign-in with the wrong account and failed OAuth callback in the admin, and
- each call made with an API token or an MCP client.

It never covers a visitor, an admin page load once signed in, or any other request. Logs and Honeybadger stay as
ADR 0010 has them. The address comes from `Public::Operations::FindVisitorAddress`, as [ADR 0013][0013] says.

**Raw rows last 90 days.** A scheduled job deletes every sign-in and every sighting older than that. What outlives
it is the list of known devices and cities, so an old device does not alert as new. That list holds the browser, OS,
city and country, and no IP or raw user agent.

**A new `security` slice owns the tables.** It is a feature slice in the sense of ADR 0001: it owns the tables and the
writes, and answers no route. `admin`, `api` and `mcp` record an access by calling an operation
it exports, as [ADR 0123][0123] allows, and `admin` reads the page through its read repos. [ADR 0021][0021] holds
for its tables as for any other.

## Alternatives

**A hashed IP**, as analytics keeps. It tells two addresses apart and nothing more. A hash cannot be checked against
my own address, looked up, or blocked, so it cannot answer where a stolen token was used.

**Location only**, the city and country with no address. Two devices in one city look the same, and my home and a
stranger down the street read as one place.

**The tables in `admin`.** `api` and `mcp` would then write rows that `admin` owns, which ADR 0001 rules out for a
presentation slice.

## Consequences

The visitor rules stand as they were. A later feature that wants a visitor's address cannot point here. It needs
its own record.

Anyone who reads the database reads up to 90 days of where I have been. The nightly dumps of [ADR 0105][0105] carry
those rows for up to 7 days past the prune.

The known list grows with every new device and city and is never pruned. It holds no address, but it still says
which cities I have been in, for good.

[0001]: 0001-split-the-app-into-slices-by-feature.md
[0010]: 0010-configure-honeybadger-from-settings-in-a-provider-not-from-honeybadger-yml.md
[0013]: 0013-read-the-visitor-address-from-one-proxy-header-and-only-from-a-trusted-peer.md
[0021]: 0021-let-sql-read-another-slices-tables-never-write-them.md
[0045]: 0045-count-visitors-with-a-daily-hash-and-no-cookies.md
[0102]: 0102-count-each-posts-unique-readers-with-an-undated-hash-kept-for-12-months.md
[0105]: 0105-dump-the-database-nightly-to-a-private-backups-bucket-and-keep-the-newest-7.md
[0123]: 0123-export-only-read-repos-and-operations-and-keep-write-repos-in-their-slice.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
