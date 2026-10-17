---
id: "0187"
title: Fold the admin pill nav into a popover switcher below 860px
status: active
created: 2026-10-17
area: [admin, assets]
issue: "#1742"
tags: [admin, layout, navigation, top-bar, popover, responsive, mobile, design]
---

# ADR 0187: Fold the admin pill nav into a popover switcher below 860px

![Active][status]

## Context

[ADR 0128][0128] fixes the pill order as Today, Tasks, Journal, Publish, Inbox and Insights, and drops the pill nav
onto a row of its own below 860px. That row grows the sticky bar from 4.5rem to 7.25rem, and to 8.25rem below 700px,
which takes a lot of a small screen. The row also scrolls sideways with its scrollbar hidden, so pills past the edge
are easy to miss. Inbox sits fifth, behind screens the owner opens less often.

Spec #1740 takes the designer's switcher from `tmp/design/`, which collapses the pills into one button whenever they
do not fit, and the order the design gives the menu.

## Decision

**Inbox comes second.** The pills, the palette groups and the switcher list Today, Inbox, Tasks, Journal, Publish and
Insights, in that order.

**Below 860px one switcher button takes the pills' place, and the bar keeps to one row.** The button names the
current group and screen and wears the Inbox dot. It opens a panel under the bar that lists every screen but
Settings, grouped as the palette groups them, with the current one marked. Settings stays in the avatar menu.

**The panel is a native popover**, as the avatar menu is. The browser opens and closes it, and closes it on Escape
and on a click outside, with scripts off. Its rows are links, as the pills are, so every screen they name opens
without scripts.

The 700px and 860px breakpoints stay the only two. Every other part of ADR 0128 stands.

## Alternatives

**Collapse at a measured width, as the design does.** A script measures the bar and swaps in the switcher whenever
the pills do not fit, at any width. It lost because it adds a third breakpoint that moves with the bar's contents,
and the switcher would need a script to appear at all.

## Consequences

A phone gets back the row the pills took, and every screen shows in the panel, none hidden past an edge.

Above 860px a cramped window still squeezes the pills with `clamp` and does not collapse them. A bar that gains an
item, such as a new pill, has to fit at 860px or move the breakpoint.

[0128]: 0128-lay-out-the-admin-as-a-full-width-pill-nav-shell-with-right-side-drawers.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
