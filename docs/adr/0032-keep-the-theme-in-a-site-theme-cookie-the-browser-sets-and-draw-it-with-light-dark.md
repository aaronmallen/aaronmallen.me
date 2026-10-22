---
id: "0032"
title: Keep the theme in a site_theme cookie the browser sets, and draw it with light-dark()
status: active
created: 2026-09-28
area:
  - admin
  - assets
  - config
  - lib
  - mcp
  - public
issue: AA-678
amended:
  - "#1308"
tags:
  - theme
  - dark-mode
  - cookie
  - privacy
  - css
  - tailwind
  - cache
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
SameSite `lax`, and never writes `document.cookie`. The server never sets or reads the cookie. As #1308 records, a
script inline at the top of `<head>` (`Blog::ThemeScript`) reads it on each page, keeps it only if it is `light`
or `dark`, and sets the `data-site-theme` attribute. It runs before the stylesheet paints, so the first paint on
any page uses the saved theme, and the server sends the same HTML to every reader. The public, admin and mcp
layouts all carry it. The content security policy allows the script by its SHA-256 hash, which `config/app.rb`
adds to `script-src`. A nonce would change the page on every request.

The no-cookie rule covers what the server sets and anything that could tell one visitor from another. A cookie
the visitor's own click sets in their browser, holding one of a fixed set of values and no identifier, is not
tracking and falls outside it. A new preference cookie may join it on the same terms: set by the browser, a
closed set of values the server checks, and nothing unique to the visitor.

`config/tailwind/shared.css` writes each colour once, as a `light-dark()` pair on a token. The base layer sets
`color-scheme` from the system setting, or from `data-site-theme` when a visitor picked one, and the browser picks
a side of every pair from it. The file redefines the `light:` and `dark:` variants so that a forced theme beats the
system one wherever a token cannot cover a rule.

## Alternatives

**`localStorage`.** The inline script could read it as well as a cookie. The cookie stays so that a change needs
no move of saved picks.

**Write the theme into the page on the server.** This record first had the layout read the cookie and write it
into the page. Every reader with the cookie then needed a page of their own, so Cloudflare could not keep it for
them ([ADR 0090][0090]).

**Tailwind's stock `dark:` variant and two sets of tokens.** The stock variant reads only the system setting, so
a saved pick could not beat it, and the variants would need redefining anyway. Two sets write every colour twice,
once per theme, where `light-dark()` keeps both sides of a colour on one line.

## Consequences

**Public pages vary on the whole `Cookie` header.** `slices/public/config/slice.rb` sends `Vary: Cookie` on every
public response, since a page differs by the operator's session. The theme no longer changes the page.

**The script's text and its hash move together.** Any edit to `Blog::ThemeScript::SOURCE` changes its hash, which
the policy reads from the same constant. A script written into the page any other way is blocked.

**The saved theme needs the script.** With scripts blocked, the page follows the system setting even for a visitor
who picked a theme.

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

[0090]: 0090-let-cloudflare-keep-anonymous-public-pages-for-five-minutes.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
