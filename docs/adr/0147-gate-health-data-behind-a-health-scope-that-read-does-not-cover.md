---
id: "0147"
title: Gate health data behind a health scope that read does not cover
status: active
created: 2026-10-11
area: [lib, admin, api, mcp]
issue: "#1112"
amended: ["#1118", "#1123"]
tags: [health, oauth, scopes, consent, api-tokens, mcp, privacy]
---

# ADR 0147: Gate health data behind a health scope that read does not cover

![Active][status]

## Context

Spec #1110 brings in my sleep, heart rate and workouts from Google Health, kept in the `health` slice ADR 0146
records. Agents should read them beside the day's work, but this is the most private data the site holds.

`read` reaches every record today (ADR 0061), and every client and API token holds it. A health tool on `read`
would reach every client already connected, none of which asked for it.

The design put a "What agents see" card on Insights > Health: site-wide toggles for sleep, recovery, workouts and
movement, and a list of clients to tick for health access. ADR 0114 split `publish` and `delete` out of `write` for
the same kind of reason, and ADR 0074 split private tags from public ones.

## Decision

`Blog::Types::OAuthScope` gains `health`. No other scope covers it, and it covers no other scope. A client asks for
it at consent, and the owner ticks it on an API token in the admin, as with every other name in `OAuthScope`. It
takes a consent line, as ADR 0061 asks of every scope.

- **The health days endpoint and its MCP tool** name `health`. In the API slice, `API::Actions::Forward::SCOPES`
  maps the endpoint to it, since a `GET` would otherwise need only `read`. `MCP::Protocol::ScopedServer` withholds
  the tool from a token without it, as ADR 0061 says.
- **The `read_activity` endpoint and tool stay on `read`**, and the endpoint leaves out workout rows unless the
  token also holds `health`. The rest of the feed reads as it does now. As #1118 records, `summarize_activity`
  and an activity saved view read through `read_saved_view` leave workouts out the same way.
- **Nothing public** reads health data, whatever scope a request carries.

The Insights > Health card lists the clients and tokens whose scopes hold `health`. It shows the grant; it does not
change it.

## Alternatives

**The design's toggles.** Site-wide switches per kind of data, and a client list ticked on the health screen. That
is a second place deciding what a client reads, beside the scopes on its token, and the two could disagree. A
site-wide switch also cannot tell one client from another. Spec #1110 dropped them for the scope.

**Leave health on `read`.** Every connected client would start reading health data the day it shipped, with no
consent screen in between.

## Consequences

A client holds all of `health` or none of it. Sleep, heart rate and workouts come as one grant; a client fit to see
workouts but not sleep has no way to ask for less.

A client connected before this change cannot reach health data until it connects again asking for `health`, since
a refresh never widens a grant (ADR 0061). The refusal names the scope.

The `read_activity` endpoint checks a scope itself, where every other check sits in `ScopedServer` or
`API::Action#require_scope`. A later endpoint on `read` that joins health rows has to make the same check or name
`health`, and nothing but its specs will catch one that forgets.

Since #1123, ADR 0151 gates mail the same way, behind a `mail` scope, and `read` endpoints drop mail threads as
they drop workouts.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
