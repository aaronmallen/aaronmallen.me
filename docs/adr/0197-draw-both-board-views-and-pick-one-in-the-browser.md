---
id: "0197"
title: Draw both board views and pick one in the browser
status: active
created: 2026-10-20
area:
  - admin
  - public
  - assets
issue: "#1883"
tags:
  - projects
  - boards
  - list-view
  - cache
  - cloudflare
  - cookies
  - localstorage
  - preferences
---

# ADR 0197: Draw both board views and pick one in the browser

![Active][status]

## Context

Each project board, in the admin and on the public site, shows its tasks as five columns of cards. Spec #1882 adds
a list view beside each board, with a toggle between the two. A reader should land on the view they last picked,
and on a phone, where the board scrolls sideways, on the list.

Cloudflare keeps one copy of each anonymous public page and hands it to every reader ([ADR 0090][0090]), so the
server cannot send one reader a page that differs from another's.

## Decision

The project board views in `slices/admin` and `slices/public` draw both the board and the list into every board
page, and the browser shows one. A script in `app/assets/js` picks, in this order:

1. the `?view=board` or `?view=list` param;
2. the last choice, kept in `localStorage`;
3. the list on screens 700px wide or less, the board on wider ones.

A click on the toggle shows the other view, saves the choice and writes `?view=` into the URL without a reload.
With script off, CSS picks by screen width. The page is the same for every reader, so the shared public copy still
works.

The choice lives in `localStorage`, where the admin already keeps social picks. The server never reads it, so the
shared Cloudflare copy stays whole. It sits beside the theme cookie of [ADR 0032][0032] as a second preference
only the browser reads.

## Alternatives

**Draw one view on the server, picked by `?view=` alone.** It cannot remember a reader's choice, and it cannot
default to the list on a phone.

**A cookie the server reads to pick the view.** A page drawn from the cookie differs by reader, so the shared
Cloudflare copy would either split by cookie or hand one reader's view to the next ([ADR 0090][0090]). It would
also add a cookie the server reads to a public site whose analytics set none ([ADR 0102][0102]).

**A cookie the browser sets, on [ADR 0032][0032]'s terms.** It would work too, since the server would never read
it. The owner left the choice open, and we took `localStorage`.

## Consequences

Each board page carries every task twice, once as a card and once as a row, so the HTML grows and the server draws
each task twice.

The site now keeps two preferences in the browser, in two places: the theme in a cookie and the view in
`localStorage`. A reader who clears one keeps the other.

A reader with script off cannot keep a choice.

[0032]: 0032-keep-the-theme-in-a-site-theme-cookie-the-browser-sets-and-draw-it-with-light-dark.md
[0090]: 0090-let-cloudflare-keep-anonymous-public-pages-for-five-minutes.md
[0102]: 0102-count-each-posts-unique-readers-with-an-undated-hash-kept-for-12-months.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
