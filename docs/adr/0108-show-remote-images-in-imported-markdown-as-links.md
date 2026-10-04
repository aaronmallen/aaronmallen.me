---
id: "0108"
title: Show remote images in imported markdown as links
status: active
created: 2026-10-04
area: [admin, lib, tasks]
issue: "#466"
tags: [tasks, commits, markdown, images, privacy, csp]
---

# ADR 0108: Show remote images in imported markdown as links

![Active][status]

## Context

[ADR 0072][0072] keeps `img` in task notes with an `http`, `https` or relative `src`, and names the cost: an image
loads from wherever its `src` points, so opening a task can tell a third party the owner's address and the time.
Notes and synced comments come from GitHub and Linear issues, and their authors need not be the owner. Commit
bodies come from GitHub too, and the admin renders them through `Posts::Markdown`, which emits an `img` for every
markdown image.

Hanami's default content security policy lets an image load from any `https` host, and the admin keeps it. The
people search draws avatars from Bluesky and Mastodon hosts nobody can list ahead of time, so a tighter admin
`img-src` would break it.

Images the owner uploads live at `/media/<key>` on the site, and a note may cite one by path or by the site's full
URL.

## Decision

We turn remote images into links in the renderers, not in the CSP. `Blog::RemoteImages` in
`lib/blog/remote_images.rb` walks rendered HTML and keeps an `img` only when its `src` is a single file under
`/media/`, either as a path or on the site's own origin, with no query or fragment. It swaps every other `img`
for:

- a link to its `src`, worded with its alt text or, with none, the URL, when the `src` is an `http` or `https` URL
  with a host;
- the same words as plain text, when the `img` already sits inside a link, since a link cannot hold another;
- its alt text alone, when the `src` is not such a URL.

`Tasks::Markdown` runs the swap after sanitize cleans the HTML, in the pass that labels task-list checkboxes, so
notes, comments, decisions and the markdown preview all get it. The admin commit page runs `Posts::Markdown` and
then `Blog::RemoteImages.to_links`. `Posts::Markdown` itself does not change, so posts, journal entries and the feeds
keep their images.

We check against an allowlist of one path, not a list of remote hosts, so no spelling of a host gets past it.

## Alternatives

**A tighter admin `img-src`.** One line of config, and it covers every renderer at once, current and future. It lost
because it blocks the people search avatars.

## Consequences

Opening a task, a decision or a commit loads no image from a third party. Reading one takes a click, and the
owner chooses when to make it.

An issue that relied on screenshots reads as a list of links. A relative image an issue points at, such as
`docs/shot.png`, shows its alt text, since it never loaded here anyway.

Code that renders text someone else wrote through `Posts::Markdown` still shows remote images. Wrap it in
`Blog::RemoteImages.to_links`, as the commit page does.

[0072]: 0072-render-raw-html-in-task-notes-through-the-sanitize-gem.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
