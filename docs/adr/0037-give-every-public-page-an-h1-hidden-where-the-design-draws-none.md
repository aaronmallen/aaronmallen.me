---
id: "0037"
title: Give every public page an h1, hidden where the design draws none
status: active
created: 2026-09-28
area: [assets, public]
issue: AA-538
tags: [accessibility, headings, design, public, screen-reader]
---

# ADR 0037: Give every public page an `h1`, hidden where the design draws none

![Active][status]

## Context

Five public pages open with a drawn `h1`: projects, about, contact, a tag page and a post. The home page and
`/writing` did not. Their outline started at the `h2` post titles the archive list emits.

Neither page chose this. AA-412 built the writing list with a kicker over it, because that is what the design
draws, and AA-423 copied the home page from it. Both then wrote the absence into the specs and the stylesheet, so a
deferral came to read as a rule. AA-538 asked for the call to be made on purpose.

The design draws no title on the home page. It heads each section with a kicker, "Writing" and "Projects", each a
`span` that labels a list rather than names the page. The handoff ships no writing page, so `/writing` has no
drawing to follow; the app gave it a kicker of its own, "Writing · newest first".

A screen reader user moves through a page by its headings. With no `h1`, the outline opens partway down a list
with nothing above it saying what the list is. A sighted reader gets the page's subject from the nav, the brand and
the layout at a glance. Heading navigation gives none of that.

## Decision

Every public page carries exactly one `h1`. The home page and `/writing` hide theirs with `sr-only`: a screen
reader reads the heading and the page draws nothing.

`Public::UI::Views::Pages::Index` renders "Writing and projects" and `Public::UI::Views::Posts::Index` renders
"Writing", each as the first child of the page's section. The kickers stay as they are. They label their lists,
and the pages look as the design draws them.

## Alternatives

**Leave both pages without an `h1` and write down why.** WCAG does not require an `h1`, and the design plainly
means a page with no title. It loses because the cost lands on the readers with the least to fall back on, and the
fix costs two hidden elements and no pixels.

**Draw a visible `h1` on both pages.** It puts the heading where everyone can see it. It adds furniture the design
does not have, on the two pages the design is clearest about, and the home page has no single title to draw.

**Make a kicker the `h1`.** No hidden text, and the visible words become the heading. On `/writing` the kicker
reads "Writing · newest first", which captions a list rather than naming a page. The home page has two kickers and
neither is the page, so picking one is arbitrary.

## Consequences

`/writing` says "Writing" twice. A screen reader reads the hidden `h1`, then the kicker. The repeat is the price
of naming the page without drawing over it.

The outline stays flat. Under the `h1` sit the post titles at `h2` with nothing grouping them, because the section
kickers are still spans. Making the home page's two sections headings is a separate change, and this record does
not make it.

The two `h1` elements are the only `sr-only` markup in the public views. The admin uses the class throughout, and
the shared nav composes it into `skip-link`, so the pattern is not new to the app.

The request and browser specs for home and writing pin one hidden `h1` on each page, and the comments on the
`home` and `writing` utilities in `config/tailwind.css` note it. No guard checks every page. Each page's request
spec pins its own `h1`, so a new page follows the rule only if its spec does.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
