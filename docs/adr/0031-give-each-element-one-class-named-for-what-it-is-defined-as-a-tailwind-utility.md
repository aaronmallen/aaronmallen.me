---
id: "0031"
title: Give each element one class named for what it is, defined as a Tailwind utility
status: active
created: 2026-09-28
area: [config, lib, public, admin, mcp]
issue: AA-667
tags: [css, tailwind, design, phlex, ui]
---

# ADR 0031: Give each element one class named for what it is, defined as a Tailwind utility

![Active][status]

## Context

Tailwind expects a view to spell out its look in the markup: `flex gap-4 font-mono text-sm`. The design handoff
does the reverse. Its `site.css` and `admin.css` give each element one class named for what it is, `.kicker`,
`.eyebrow`, `.btn` with `.pri`, and style the class.

AA-342 counted what spelling out a look costs, even inside the stylesheet. The triple `font-mono text-meta
text-ink-muted` sat in 37 rules, one idea written 37 times: "Change the muted colour and you edit 37 rules, or more
likely you edit 35 and leave two behind." It drew the line this record keeps. A pure look, with no shape of its own,
becomes one utility the others compose. A repeated piece of markup becomes a Phlex component, "so a view says what
the thing is rather than how it looks".

## Decision

Every class a view writes names a thing, and `config/tailwind.css` defines it once as an `@utility`, 350 of them. A
utility builds on the theme tokens in the one `@theme` block and on other utilities through `@apply`: `page-column`
is `mx-auto max-w-page pt-12`, and `form` is `form-stack max-w-measure`.

- A class takes its name from the handoff where the handoff has one, and a variant is a second class the utility
  styles: `Admin::UI::Components::Button` writes `["btn", @variant&.to_s, ("sm" if @small)]`.
- A view writes no layout or type utility of Tailwind's own. `sr-only` is the one exception, since it already names
  what it does. Font Awesome classes and microformat names such as `h-entry` are not styling and fall outside the
  rule.
- A shape that repeats in markup becomes a component, not a longer class list.

The rule holds in `lib/blog/ui` and under every `slices/*/ui`.

## Alternatives

**Tailwind utilities in the markup**, the way Tailwind's own guides write it. It lost for the reasons AA-342 gave:
one look written in many places drifts when only some of them change, and the view ends up saying how a thing looks
rather than what it is.

## Consequences

A change to a look is one edit, in one place, and a view reads as a list of things. Keeping the handoff's names
lets a class be checked against its source: AA-343 audited the type by laying each design class beside its
counterpart, and its notes are how AA-407 found the eyebrow missing.

One sheet serves the public, admin and MCP slices, since `Blog::UI::Layouts::Application` links the same `app.css`
for all three. A rule no class guards reaches every slice, so the site cannot do what the design does and cap every
`p` at a measure. Each run of prose names its own cap instead, and a rule meant for one side has to hang off a
class that side owns, as the admin's phone type steps hang off `.adm`.

Most phone rules live inside the utility they change, each in its own `@media (width < 43.75rem)` block, and the
rest sit in the base layer. Finding all of them takes a search for the breakpoint.

Nothing checks a class name. Tailwind emits a utility only when it finds the name in the source, and a misspelt
class matches nothing and renders unstyled with every request spec passing. Only a browser spec that reads the
computed style, such as `spec/slices/public/browser/home_spec.rb`, would notice.

The stylesheet grows with every element. At 350 utilities it is the longest file in the tree.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
