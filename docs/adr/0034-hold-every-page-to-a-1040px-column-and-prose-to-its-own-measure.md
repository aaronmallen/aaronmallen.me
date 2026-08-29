---
id: "0034"
title: Hold every page to a 1040px column and prose to its own measure
status: active
created: 2026-09-28
area: [assets, public, admin]
issue: AA-538
amended: [AA-539]
tags: [layout, design, css, tailwind, public]
---

# ADR 0034: Hold every page to a 1040px column and prose to its own measure

![Active][status]

## Context

Every public page centred itself in a 720px column. Seven utilities in `config/tailwind.css` carried it: `home`,
`writing`, `tagged`, `projects`, `about`, `contact` and `post`. The 720px sat in `--container-page`.

The design names one column width, and it is 1040px. Its `site.css` caps the kicker, the archive list, the
eyebrow and the call to action at 1040px on an archive page. The handoff states three widths in all: 1040px,
760px and 560px. The app already carries the last two to the pixel, as the breakpoints where an entry folds its
meta over the title and a work row lifts its years above the role. 720px was the one width in the stylesheet the
design never names.

AA-423 built the home page and kept 720px rather than bring a second width in for one page. That was the right
call for one issue, and it never settled which width the site has.

Two facts decide it.

The first is that the design is the handoff and the app is what moves. We cannot edit the design to agree with
the app, so one width across both means the app takes the design's number.

The second is that the column should never set the reading line. The design holds every paragraph to 90ch and
gives its article no width of its own, so its 1040px reaches the furniture and stops at the prose. The app had
half of that: `post-body` capped at `--container-measure`, 44em against its own 16px, so 704px. The ledes, the
call to action copy, the project and work blurbs and the archive teaser carried no cap and took whatever the
column gave them. At 720px that went unnoticed. At 1040px it would not.

The design is not tidy about this. Its pages leave `.wrap` open and none carries the `archive-page` class, so
they draw edge to edge and the 1040px rule reaches nothing. The handoff ships no writing page at all, which is why
the class is orphaned. A full-bleed archive is a draft rather than a decision, and 1040px is still the only width
the design states.

## Decision

`--container-page` is 1040px. Every page reads it through the shared `page-column` utility, so home, writing, a
tag page, projects, about, contact and a post all share one width. `spec/slices/public/browser/home_spec.rb` and
`writing_spec.rb` pin it.

Every run of prose caps itself at `--container-measure`, the way the design holds each paragraph to 90ch. On the
public pages that is `post-body`, `lede`, the `cta`, `proj` and `row` paragraphs, `entry-blurb`, the contact
`form` and its `f-ok` notice, and `post-response-text`. The admin's `task-planner-note` takes it too. The column
sets how wide a page is. The measure sets how wide a line reads.

## Alternatives

**Keep 720px and treat the design's 1040px as stale.** It is the smaller change and 720px is a comfortable
measure. It loses on the two facts above: the design cannot be edited to match, and 720px reads as a prose width
applied to a page that mostly holds lists. It also leaves `--container-measure` doing nothing on the pages where
prose and column sit 16px apart.

**Give the archive pages 1040px and leave the prose pages at 720px.** This copies the design's own scoping most
closely. It brings back the second width AA-423 refused, and it needs a rule for which pages are which that nobody
would keep current. The measure token already draws the line that matters, inside the page rather than between
pages.

**Bound the archive list instead of the page.** The list is what the design caps, so capping `entries` would hit
the same pixels on home and writing. It leaves the titles, kickers and calls to action unbounded, and those are
half of what the column is for.

## Consequences

**Archive rows get wider.** The entry grid is a 170px meta column, a 24px gap, then the title and blurb. The blurb
had 526px and now has 846px. That is the proportion the design draws.

**Some lines of prose still widen, and none follows the column.** The post body holds at 704px. The ledes go from
720px to 845px, since 44em against 1.2rem is wider than the old column, and the call to action copy goes from
664px to 704px, the work blurb from 596px and the project blurb from 720px to the same. Each lands on the measure
rather than on the column, but the measure is not always narrower than 720px.

**A post's furniture runs wider than its body.** The title, the meta row, the back link, the syndication row and
the responses heading span 1040px over a 704px article. The design draws the same overhang, and the response text
has its own measure, so only short rows sit out there.

**The page needs more room before it stops growing.** With a 5rem gutter on each side the layout settles at 1200px
rather than 880px. Below that the column shrinks as it always did.

**Each run of prose opts in.** Ten utilities spell out `max-w-measure`. The design does it with one rule over every
`p`. We cannot, because one stylesheet serves the admin too and most of its paragraphs sit in cards, not reading
lines. A new block of prose that forgets the cap takes the full 1040px.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
