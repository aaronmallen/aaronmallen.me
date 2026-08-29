---
id: "0032"
title: Keep the theme in a site_theme cookie the browser sets, and draw it with light-dark()
status: active
created: 2026-09-28
area: [admin, assets, config, lib, mcp, public]
issue: AA-678
tags: [theme, dark-mode, cookie, privacy, css, tailwind, cache]
---

# ADR 0032: Keep the theme in a `site_theme` cookie the browser sets, and draw it with `light-dark()`

![Active][status]

## Context

The site draws light or dark from the system setting, and the settings menu lets a visitor pick one to override
it. The pick has to survive to the next page, and that page's first paint has to use it: a page that paints the
system theme and then flips once a script runs flashes the wrong colours on every load.

The public site promises no analytics cookie, no consent banner and no third party, and the public slice sets no
cookie. A saved theme needs some state in the browser, so this record says where the promise stops.

## Decision

A click on the theme picker sets `data-site-theme` on `<html>` and a `site_theme` cookie with one year to live,
both in the browser (`app/assets/js/theme.js`). The script sets the cookie through `cookieStore.set`, on `/` with
SameSite `lax`, and never writes `document.cookie`. The server never sets the cookie. On the next request
`Blog::UI::Layouts::Application#saved_theme` reads it, keeps it only if it is `light` or `dark`, and writes it into
`<meta name="color-scheme">` and the `data-site-theme` attribute. The public, admin and mcp layouts all do this,
so the first paint on any page uses the saved theme.

The no-cookie rule covers what the server sets and anything that could tell one visitor from another. A cookie
the visitor's own click sets in their browser, holding one of a fixed set of values and no identifier, is not
tracking and falls outside it. A new preference cookie may join it on the same terms: set by the browser, a
closed set of values the server checks, and nothing unique to the visitor.

`config/tailwind.css` writes each colour once, as a `light-dark()` pair on a token. The base layer sets
`color-scheme` from the system setting, or from `data-site-theme` when a visitor picked one, and the browser picks
a side of every pair from it. The file redefines the `light:` and `dark:` variants so that a forced theme beats the
system one wherever a token cannot cover a rule.

## Alternatives

**`localStorage`.** The browser never sends it, so the server cannot read it. The first paint would follow the
system theme until the script ran, and a visitor who picked the other theme would see the page flip on every
load.

**Tailwind's stock `dark:` variant and two sets of tokens.** The stock variant reads only the system setting, so
a saved pick could not beat it, and the variants would need redefining anyway. Two sets write every colour twice,
once per theme, where `light-dark()` keeps both sides of a colour on one line.

## Consequences

**Public pages vary on the whole `Cookie` header.** `slices/public/config/slice.rb` sends `Vary: Cookie` on every
public response, since a page differs by the theme cookie and by the operator's session. A shared cache keeps one
copy per distinct cookie header, so it stores a page once for each theme a visitor picked, and more if the browser
sends other cookies.

**`light-dark()` sets a floor on browsers.** Chrome and Edge 123, Firefox 120 and Safari 17.5, all from 2024,
are the first to read it. An older browser draws the page without the theme's colours.

**Saving the pick needs the Cookie Store API.** Chrome 87, Safari 18.4 and Firefox 140 are the first to have it,
and only on HTTPS or localhost. Without it, a click still switches the page, but the next page follows the system
setting. A `document.cookie` fallback would cover those browsers at the cost of turning off Biome's
`noDocumentCookie`.

**The picker needs the script.** With it blocked, the page still follows the system setting, but a visitor
cannot pick.

**Any new colour is one `light-dark()` token.** A colour written as two tokens, or a rule that reads
`prefers-color-scheme` on its own, would ignore a visitor's pick.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
