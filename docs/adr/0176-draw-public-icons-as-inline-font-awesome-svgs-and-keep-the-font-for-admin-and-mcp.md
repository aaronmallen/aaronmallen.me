---
id: "0176"
title: Draw public icons as inline Font Awesome SVGs and keep the font for admin and MCP
status: active
created: 2026-10-14
area: [assets, config, lib, public, admin, mcp]
supersedes: ["0033"]
issue: "#1305"
amended: ["#1282", "#1215"]
tags: [icons, font-awesome, svg, css, tailwind, accessibility, performance]
---

# ADR 0176: Draw public icons as inline Font Awesome SVGs and keep the font for admin and MCP

![Active][status]

## Context

ADR 0033 drew every icon as an `<i>` with a Font Awesome Free class. #1304 split the stylesheet in two, but both
sheets still pulled Font Awesome in through `app/assets/css/base.css`: about 69 KB of CSS for some 2,668 class names.
The public footer's brand icons made every public page fetch `fa-brands-400.woff2` (115 KB) and
`fa-solid-900.woff2` (119 KB), both with `font-display: block`, so icons stayed blank until the fonts came in.

Public pages draw 22 icons: 17 solid, 4 brands and `fa-regular fa-file-code` in code captions.

## Decision

Public pages draw each icon as an inline SVG from Font Awesome Free. Admin and MCP pages keep the font.

- **The SVGs.** `lib/blog/ui/icons/<style>/<name>.svg` holds a copy of each public icon from the package's `svgs`
  folder. `Blog::UI::Components::Icon` reads them once, at load.
- **The switch.** `Public::UI::View` sets `Icon::INLINE` on the render context. When it is set, `Icon` puts the
  SVG inside its `<i>`; when it is not, it renders the empty `<i>` the font fills. A public icon with no file raises,
  so the page's spec fails.
- **The markup.** The `<i>` keeps its Font Awesome class names, which now only name the icon. Rules in
  `config/tailwind/shared.css` such as `i.fa-retweet` keep matching.
- **Action names.** Since #1215, `Icon` also takes a common action's name, such as `:trash`, and swaps in its class
  names from `Icon::ACTIONS`, so delete, edit, ban, close, copy and outbound links each show one icon. Any other name
  passes through as class names, and a public page finds the SVG through the swapped names.
- **The sheets.** `app/assets/css/admin.css` imports Font Awesome. `base.css` holds only the site's fonts, so
  `public/app.css` carries no Font Awesome CSS and links no Font Awesome font.
- **Code captions.** `Markdown::Document` draws `file-code` as an SVG in an `<i>` with no class, on public pages and
  in the admin preview alike, so the admin's font draws no second glyph over it.
- **Sizing and hiding.** One rule in `config/tailwind/shared.css`, outside Tailwind's layers as Font Awesome's CSS is,
  gives an `<i>` that holds an SVG Font Awesome's box: `display: var(--fa-display, inline-block)`, a `1.25em` width and
  a `1em` glyph. Hiding still goes through `--fa-display`.

ADR 0033's other rules stand: an icon beside text is `aria-hidden`, one that stands alone takes `role: "img"` and an
`aria-label`, no icon comes from stored data, and the date field's calendar stays a mask.

A brand mark that Font Awesome Free lacks is a second mask, since #1282. Linear is the one case.
`config/tailwind/shared.css` holds Linear's own SVG in the `linear-mark` utility and paints `bg-current` through it, so
the mark takes the text colour in both themes. The utility gives the `<i>` Font Awesome's box, `1.25em` by `1em`, and
its display goes through `--fa-display`. `Icon` draws it from the class name like any other icon, so the label rules
hold. Every other brand keeps its Font Awesome class.

## Alternatives

**Pick the SVG whenever a file exists for the icon.** It lost because the admin would then draw both the font's
glyph and the SVG for every icon public pages share with it.

**A new class for SVG icons in place of the Font Awesome names.** It lost because every `--fa-display` rule and every
selector that names an icon class would change, and the components `lib/blog/ui` shares with the admin would need
two names for one icon.

**SVGs in the admin too.** #1305 covers public pages. The admin names about 150 icons, and its JavaScript builds
some of them by class.

## Consequences

Public pages load no Font Awesome CSS or font, and icons draw with the page instead of after a font fetch.

Each icon's markup, license comment and all, ships in the HTML every time a page uses it: about 560 bytes for the
heart. The 22 copies come to 16 KB on disk.

A new public icon costs a copy from `node_modules/@fortawesome/fontawesome-free/svgs`. Upgrading the package leaves
the copies as they were, so a public icon can drift from the admin's font, as the calendar mask can.

One component renders different markup by slice: an SVG on public pages, an empty `<i>` in the admin and MCP. A
public view that does not inherit `Public::UI::View` draws blank icons.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
