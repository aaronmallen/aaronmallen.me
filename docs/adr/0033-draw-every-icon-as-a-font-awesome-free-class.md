---
id: "0033"
title: Draw every icon as a Font Awesome Free class
status: active
created: 2026-09-28
area: [assets, config, db, lib, admin, public, tasks]
issue: AA-685
amended: [AA-801, "#17"]
tags: [icons, font-awesome, svg, css, tailwind, accessibility, enums]
---

# ADR 0033: Draw every icon as a Font Awesome Free class

![Active][status]

## Context

The design handoff names every icon as a Font Awesome class. Its task types, for one, pick from
`fa-solid fa-hammer`, `fa-solid fa-feather` and six more (AA-394). The handoff loads Font Awesome 6 from a CDN.
AA-203 kept the npm 7.x package instead and added its regular set.

`package.json` pulls in `@fortawesome/fontawesome-free`, and `app/assets/css/app.css` imports four of its sheets:
the base, brands, regular and solid. esbuild finds them in `node_modules` and copies the webfonts into
`public/assets`.

The eight task type icons first lived in a `task_type_icon` enum and a `<select>`. AA-801 opened them up: every
solid icon already ships with the app, and only the enum and the form kept a type from using one.

## Decision

Every icon is an `<i>` with a Font Awesome Free class from the solid, regular or brands set. Fifty-two files under
`lib` and `slices` name one, and no view draws an icon as an SVG.

- **Labels.** An icon beside text, or inside a control that carries its own `aria-label`, is `aria-hidden`, as in
  `Admin::UI::Components::StatusPill` and the caret buttons in `Tasks::Order`. An icon that stands alone takes
  `role: "img"` and an `aria-label` from its slice's `config/i18n`, as the heart in
  `Public::UI::Components::Footer` does.
- **Task types store an optional solid name.** `task_types.icon` is nullable text holding a Font Awesome Free
  solid name without its prefix, and `TypeTag` draws `fa-solid fa-#{@type.icon}`, or no icon when it is nil.
  `Blog::Types::TaskTypeIcon` checks the name against a checked-in list of every Free solid name, which
  `mise run assets:icons` builds from the installed package's metadata. After upgrading Font Awesome, run the task
  again and commit the list.

  ADR 0065 retires task types, and `task_types.icon` and `TypeTag` go with them. `Blog::Types::TaskTypeIcon`, the
  list and `mise run assets:icons` then serve nothing. #17 added this note.
- **Hiding goes through `--fa-display`.** Font Awesome's CSS sits outside Tailwind's layers, so its
  `display: var(--fa-display, inline-block)` beats any utility. A utility that hides an icon sets
  `--fa-display: none`, as the main nav's toggle icons and `settings-menu-check` do in `config/tailwind.css`.

An inline SVG is allowed only where the browser gives us no element to hold an `<i>`. The date field's calendar
button is the one case today. WebKit and Blink draw it as `::-webkit-calendar-picker-indicator`, a part of the
native date input, so `config/tailwind.css` holds Font Awesome's regular calendar as `--glyph-calendar` and paints
the button through it as a mask, which lets it take a theme colour.

## Alternatives

**An inline SVG for each icon.** It lost because the handoff names every icon as a Font Awesome class. One class
per icon matches the design as written, with no SVG to copy for each icon.

**A `task_type_icon` enum of eight names.** What task types had until AA-801. It lost because it held a type to eight
icons when the app already ships every solid one.

**A text field with no name check.** It lost because it lets a typo through, and the type then draws no icon.

**A modal icon picker.** It lost because it is much more work for the same result. It could read the same list
later.

## Consequences

A new icon costs one class name from the handoff.

Swapping the set touches every view that names a class.

The icon list is a copy. Upgrading the package leaves it as it was until someone reruns `mise run assets:icons`,
so a new icon fails the check and a dropped one still passes it.

Pages load more than they draw. All of `fontawesome.css`, 105 KB before esbuild minifies it, ships in `app.css` on
every page. A page that shows one solid icon fetches the whole of `fa-solid-900.woff2`, 119 KB. The public
footer's profile links draw brands icons, so each public page that shows one also fetches the 115 KB brands font.

Font Awesome ignores Tailwind's layers, so a `hidden` utility on an icon does nothing. Every rule that shows or
hides one has to go through `--fa-display`.

The calendar mask is a copy. Upgrading the package leaves `--glyph-calendar` as it was, while the task rows and the
Upcoming tab draw `fa-regular fa-calendar` from the package, so the two calendars can drift apart.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
