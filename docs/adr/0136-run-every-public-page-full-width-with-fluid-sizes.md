---
id: "0136"
title: Run every public page full width with fluid sizes
status: active
created: 2026-10-09
area: [assets, config, public]
supersedes: ["0034"]
issue: "#842"
tags: [layout, design, css, tailwind, public, responsive]
---

# ADR 0136: Run every public page full width with fluid sizes

![Active][status]

## Context

[ADR 0034][0034] holds every public page to a 1040px column through `page-column` and caps each run of prose at
`--container-measure`. Type and spacing take fixed sizes. On a wide screen the site is a narrow strip with empty
space on both sides, the fault [ADR 0128][0128] fixed in the admin.

Spec #834 rebuilds the public shell from the designer's handoff in `tmp/design/`. Its `public.css` sets no page
width. `.pm` pads the page with `--gut`, `clamp(20px, 2.2vw, 56px)`, the admin's gutter. Pages split into two
columns at 900px through a shared grid, and type, gaps and padding size with `clamp()` rather than at breakpoints.
The design drops its site-wide 90ch cap on `p` and gives each block of prose its own: 68ch for a post body and an
entry blurb, 56ch for a lede, 60ch for the contact details.

## Decision

**No public page has a max-width container.** `page-column` and `--container-page` go. `main` fills the window
inside the fluid gutter, and a page that wants two columns uses the shared grid rather than a narrower column.

**Sizes are fluid.** Type, gaps and padding read `clamp()` tokens, and reuse the admin's tokens where the values
match.

**Prose keeps a measure, and each block opts in.** A post body, a lede, an entry blurb and any other run of reading
text caps itself at the width the design gives it. The page sets how wide the layout is. The measure sets how wide a
line reads. The admin's prose keeps its own cap as ADR 0128 left it.

## Alternatives

**Keep the 1040px column.** It costs nothing and holds every line near the measure. It lost because the design
draws the public site full width and fluid, and the admin already runs that way under ADR 0128. Keeping it would
leave the two slices on different layouts and waste most of a wide screen.

## Consequences

The public site and the admin share one gutter and one way of sizing, so a token or component built for one fits
the other.

Anything that does not opt into a measure runs as wide as the window. A title, a meta row or a new block of prose
that forgets its cap stretches across a 4K screen.

Each page's layout has to change, since every page leaned on `page-column`. The page specs under #834 rebuild them
one at a time, and pages look mixed until the last one lands.

The design's measures live in `tmp/design/`, which the repository does not keep. Once the pages land, the widths
survive only as tokens in `config/tailwind.css`.

[0034]: 0034-hold-every-page-to-a-1040px-column-and-prose-to-its-own-measure.md
[0128]: 0128-lay-out-the-admin-as-a-full-width-pill-nav-shell-with-right-side-drawers.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
