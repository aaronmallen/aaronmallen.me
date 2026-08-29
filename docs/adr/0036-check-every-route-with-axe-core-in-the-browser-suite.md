---
id: "0036"
title: Check every route with axe-core in the browser suite
status: active
created: 2026-09-28
area: [public, admin, mcp]
issue: AA-836
tags: [accessibility, wcag, axe-core, testing, capybara, cuprite, browser]
---

# ADR 0036: Check every route with axe-core in the browser suite

![Active][status]

## Context

AA-835 holds every page in public, admin and MCP to WCAG 2.2 AA, and asks the browser suite to keep it there.

The one check we have is the script `spec/slices/admin/browser/phone_spec.rb` injects into each admin screen at
390x844. It measures text size, tap targets and sideways scroll, the three rules ADR 0054 set. Nothing checks that
a control has a name, that ARIA is sound, that landmarks and headings make sense, or that text meets AA contrast.
A new faint color or an unnamed button would ship without a failing spec.

## Decision

The browser suite runs axe-core against every route in public, admin and MCP, once in light mode and once in dark
mode, and fails on any WCAG 2.2 AA breach. It runs as part of `mise run test:browser`.

The `axe-core-api` gem supplies the axe script, pinned to its version. Its runner drives Selenium and breaks under
Cuprite, the driver the suite already uses, so the suite injects the script through Cuprite and calls `axe.run`
itself.

axe has no rule for a font-size floor, so the size, tap and overflow check from `phone_spec.rb` stays ours. It
becomes shared, runs beside axe on every route, and takes over the one thing axe does not measure.

## Alternatives

**Grow the homegrown script to cover the rest.** It needs no new dependency and already runs in the suite. It lost
because we would write the contrast math, the name and ARIA rules and the landmark rules by hand, and keep them
current as WCAG moves. axe already knows the AA rules.

**Audit once and fix what it finds.** It costs nothing after the fixes land. It lost because nothing would stop the
next faint color or unnamed control.

## Consequences

The suite takes a new gem, `axe-core-api`, and it reaches every browser spec.

The browser suite runs slower. Each route loads twice, once per theme, and axe walks the whole page each time.

The accessibility checks live in two places: axe for the WCAG rules, and our own script for text size. A reader
who wants to know why a page failed has to know which of the two raised it.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
