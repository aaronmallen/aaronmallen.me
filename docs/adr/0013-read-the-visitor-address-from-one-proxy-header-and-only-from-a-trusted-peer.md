---
id: "0013"
title: Read the visitor address from one proxy header, and only from a trusted peer
status: active
created: 2026-09-28
area: [config, public, mcp]
issue: AA-638
tags: [privacy, analytics, throttles, proxy, cloudflare, security]
---

# ADR 0013: Read the visitor address from one proxy header, and only from a trusted peer

![Active][status]

## Context

One address stands for a visitor everywhere the site guards or counts one. It feeds the visitor hash and the
country lookup (`slices/analytics/operations/record_visit.rb`), and through the hash the contact, beacon, webmention
and MCP client registration throttles.

The site runs behind a Cloudflare Tunnel, so `cloudflared` connects from the loopback and `REMOTE_ADDR` is the same
for every request. The real address has to come from a header, and a header is something a client can write.

AA-464 found the first way in. `request.ip` reads `X-Forwarded-For` whenever `REMOTE_ADDR` is a proxy Rack trusts,
which covers the loopback. Eight contact sends with a new `X-Forwarded-For` each stored eight messages against a
limit of three, and each one could mint a new visitor hash and pick its country.

AA-526 found the second. Once the app read a named header, nothing checked who sent it, so a client that reached the
app's port directly chose its own address. That holds only while `cloudflared` is the one thing that can reach the
port.

## Decision

`Public::Operations::FindVisitorAddress` is the one place that reads the visitor address. `public` exports it and
`mcp` imports it.

- It reads one header, the one `settings.proxy[:address_header]` names. `config/settings/production.yml` names
  `CF-Connecting-IP`. Development and test name none.
- It reads that header only when `REMOTE_ADDR` falls inside `settings.proxy[:trusted_proxies]`. Production takes
  them from `PROXY_TRUSTED_PROXIES` and trusts the loopback, `127.0.0.0/8` and `::1/128`, when it is unset. An empty
  list trusts no one.
- When the header holds a list, it takes the last entry, the one the nearest proxy wrote.
- In every other case, it answers with `REMOTE_ADDR`: no header named, a peer outside the list, or a blank header.
- It never reads `X-Forwarded-For`, `Forwarded` or any other header.

## Alternatives

**`request.ip`, with `Rack::Request.ip_filter` naming the trusted proxies.** Rack builds the address from
`X-Forwarded-For`, which a client can seed (AA-464). `ip_filter` narrows which peers Rack trusts, but it cannot
point Rack at a header of another name, so it cannot read `CF-Connecting-IP`.

**Trust the named header from any peer.** What the code did between AA-464 and AA-526. It is right only while
nothing but the tunnel reaches the port, and it turns wrong on the day the app listens on a LAN port, which nobody
would link back to this (AA-526).

## Consequences

A client cannot choose its address by setting a header, from behind the tunnel or around it. Puma listens on the
loopback by default (`HANAMI_HOST` in `config/puma.rb`), so a host on the LAN cannot get around the tunnel either.

The site is tied to Cloudflare. The header name is theirs, so a move to another proxy means a new `address_header`.
We turned down `CF-IPCountry` for the country because it works only behind that provider. This record takes on that
tie for the address, though the country still comes from MaxMind.

Both settings fail without a sound. If `cloudflared` connects from an address `PROXY_TRUSTED_PROXIES` does not
name, or the header name is wrong, every request counts under the tunnel's address. Every visitor then shares one
address, one country and one throttle bucket, so three contact sends in an hour shut the form for everyone. Nothing
logs it. A range wider than the proxy fails the other way: every host inside it can choose its address.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
