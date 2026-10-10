---
id: "0054"
title: Run every admin screen on a phone
status: active
created: 2026-09-28
area: [assets, admin, public, mcp]
issue: AA-346
amended: [AA-539, AA-765, AA-835, "#17", "#745", "#923"]
tags: [admin, layout, responsive, accessibility, design]
---

# ADR 0054: Run every admin screen on a phone

![Active][status]

## Context

The design handoff drew the admin for a desk. `tmp/design/assets/admin.css` folds its grids at 1000px, 940px,
900px and 860px, and below that it changes one thing: at 700px the palette button shrinks to 34px and the page
keeps a 46px rail for it. Everything between 390px and 860px was never drawn, and the app inherited the gap.

A pass at 390x844, driven through Capybara so the numbers came off the page rather than off a guess, found three
kinds of failure:

- **The page scrolled sideways.** The top pages table on analytics pushed it to 441px, and the add form on task
  types to 428px.
- **Most controls sat under a thumb.** Buttons stood 26 to 31px tall, range and filter options 24px, editor
  tools 21px wide, colour swatches 20px square and reorder carets 18px tall.
- **Two faces read at 10px and 10.5px**: the card labels, field captions, pills and table headers.

The one thing the handoff says about narrow screens is that its tab strip scrolls sideways with the scrollbar
hidden.

Nothing in the admin needs a desk. It is one operator's own tooling, and the moments it is wanted most, filing a
task or a journal entry, are the moments a phone is the only screen to hand.

## Decision

Every admin screen works at 390x844, and no screen says it is desktop only. Each slice lists its screens in a
`screens` table in its own `browser/readable_spec.rb`, and a new screen joins the table of the slice that draws
it. The shared example in `spec/support/shared_examples/readable_screens.rb` measures every screen in public, admin
and MCP at 390x844 and at 1280x800.

Three rules hold:

- **Nothing scrolls the page sideways.** A box wider than a phone scrolls inside itself, the way the handoff's
  tab strip does, with `scrollbar-width: none`. The top pages table and the context bar both work this way.
- **Every control keeps a 44px square.** `--spacing-tap` in `config/tailwind.css` holds that number and every
  phone rule reads it from there. A control and the label around it count as one target, so a switch stays 34x19
  inside a label that is 44 tall.
- **No text drops under 12px,** on any slice at any width. Every type token for words in `config/tailwind.css` is
  12px or more, so no rule has to step a face up. Since #923 icon glyphs sit outside this rule: `--text-pu-icon`
  and the rules that size Font Awesome icons may go under 12px, as an icon holds no words.

The width and tap rules turn on below 700px (`43.75rem`), the width of the handoff's own phone rule. The tap
square holds in admin and on the MCP consent page, which borrows admin's controls. Public answers to the width
and text rules, and ADR 0036's axe check holds its controls to WCAG's 24px. Below 700px, rows that pack controls
beside a title fold to one column and give the controls their own line, the reorder carets sit side by side, and
the page ends far enough above the palette button that no row sits under it.

The layouts below 860px are derived, not ported. They come from the tokens and rules the stylesheet already
carries, and they add no second visual language.

Since #745 the admin folds at 700px and 860px alone, as [ADR 0128][0128] records. Two-column layouts start at
860px, and the pill nav drops onto its own row below it.

## Alternatives

**Name the screens a phone is for and let the rest say they are desktop only.** The editors and the tables are the
work a desk suits, and drawing them twice is the cost of this record. It loses on what the admin is: a task gets
filed from a queue, a draft gets fixed on a train, and a screen that turns you away is a screen you stop reaching
for. Half an admin also needs a rule for which half, and nobody would keep that rule current.

**Step the smallest faces up on the admin body below 700px.** This record first raised `--text-label` and
`--text-badge` from 10px and 10.5px to 11px, and only on `.adm`, since on `:root` the step-up also grew the public
contact form's captions (AA-539). It lost because it fixed one slice at one width: public pages, admin on a
desk and the consent page kept 10px labels, and five other tokens still sat at 11px and 11.5px. AA-835 moved the
tokens themselves to 12px instead.

**Hold the tap target to WCAG 2.2's 24px minimum.** It passes, and it asks less of the layout. It is also below
what a thumb hits, and the admin is touched more than it is pointed at.

## Consequences

**Rows are taller on a phone.** A task row carries its title, its meta line and a row of 44px controls, so fewer
rows fit a screen. That is the price of every one of them being tappable.

**The colour swatches are large.** Six 44px squares are the loudest thing in a tag's open editor. They are
controls, and they take the same square as every other control.

**The palette button floats over the column.** The handoff's 46px rail spends an eighth of a 390px screen, so the
button keeps its corner and the page pads itself to clear it. Anything mid-page scrolls under it. #745 replaces the
button with a search button in the top bar, so the page no longer pads itself to clear one.

**The analytics chart loses its tooltip on a phone.** Laid out all the time, it pushed the page sideways, so it
draws only while its bar is hovered, and a phone does not hover. The chart keeps its peak and its dates.

**A scrolled box hides that it scrolls.** The hidden scrollbar is the handoff's rule, and the last column of the
top pages table sits off the edge with nothing saying so.

**The phone rules live beside what they change.** Each sits in the `@utility` block it answers, 27 of them, rather
than in one section at the end. Finding every phone rule means searching for the breakpoint.

**Small print is larger on every screen.** Badges, pills, card labels and table headers read at 12px on a desk
too, so dense tables and cards run a little wider than the handoff drew them.

**Some controls sit outside the tap count.** The shared site header measures 32px and 40px and belongs to the
public pages as much as the admin, so the spec leaves it out of the tap count, though its text and width still
count. Public controls answer to axe's 24px rule rather than to the 44px square.

[0128]: 0128-lay-out-the-admin-as-a-full-width-pill-nav-shell-with-right-side-drawers.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
