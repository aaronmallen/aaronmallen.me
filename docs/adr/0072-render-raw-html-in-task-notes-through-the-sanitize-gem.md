---
id: "0072"
title: Render raw HTML in task notes through the sanitize gem
status: active
created: 2026-09-29
area: [admin, lib, tasks]
issue: "#38"
amended: ["#52"]
tags: [tasks, markdown, html, sanitize, security, commonmarker]
---

# ADR 0072: Render raw HTML in task notes through the sanitize gem

![Active][status]

## Context

Spec #36 renders a task's note as markdown in the panel and on the read page from [ADR 0071][0071], raw HTML
included, minus anything that runs script. Notes come from the admin, from the MCP tools, and from GitHub and Linear
issues through `Tasks::Operations::SyncIssues`, which copies an issue's body into the note as written. An issue
body often carries HTML, such as `<details>`, `<img>` and `<br>`, and its author need not be the owner.

`Posts::Markdown` in `lib/posts/markdown.rb` runs Commonmarker 2 with its default, which drops raw HTML and leaves
`<!-- raw HTML omitted -->` in its place. Posts, commit bodies and the webmentions we send all render through it,
and #21 keeps that rule for journal entries. Nothing in the bundle cleans HTML. Nokogiri is there, and the social
slice parses HTML with it to send webmentions.

A note renders inside the admin, where the owner is signed in and every write is a form away. A script that gets
through runs with the owner's session.

## Decision

Task notes render through `Tasks::Markdown` in `lib/tasks/markdown.rb`, which `slices/tasks/config/slice.rb` loads
with `autoloader.push_dir`, as the posts slice loads `lib/posts`. The admin calls `::Tasks::Markdown.to_html(note)`
the way it calls `::Posts::Markdown` today.

`Tasks::Markdown` runs Commonmarker with `render: { unsafe: true }`, so raw HTML passes through, with no syntax
highlighter, and with the `tagfilter` extension off. Commonmarker turns `tagfilter` on by default, and it would show
a `<script>` as text rather than drop it. It then cleans the whole result with the [sanitize][sanitize] gem, so
nothing the renderer emits skips the cleaning. The config starts from `Sanitize::Config::RELAXED`, adds `details`,
removes the `style` element and the `class`, `id`, `style` and `tabindex` attributes, and keeps `input` only as the
disabled checkbox a task list writes. The result:

- **Keeps** the elements markdown writes, plus `details`, `summary`, `img`, `br`, `sub`, `sup`, `kbd` and tables.
- **Strips** `script`, `style`, `iframe`, `object`, `embed`, `form`, `svg` and every other element off the list,
  and the content of the ones that hold code.
- **Strips** every `on*` event handler, and every attribute off the list.
- **Strips** a URL whose scheme is off the list. A link keeps `http`, `https`, `mailto`, `ftp` or a relative path,
  and an image `http`, `https` or a relative path, so a `javascript:` or `data:` URL loses its `href` or `src`.

Dropping `class`, `id` and `style` keeps a note out of the admin's CSS and ids: a note cannot pin itself over the
page with a utility class or claim the id a `dialog` or `label` looks up.

Once the note is clean, `Tasks::Markdown` gives each task-list checkbox an `aria-label` of its item's text,
leaving out any list nested under it, so a screen reader and axe can name the box (#52). The label comes from the
cleaned HTML, so it holds only text that survived the cleaning, and a note cannot set one of its own.

The stored note does not change. We clean it each time it renders.

Posts and journal entries keep dropping raw HTML. The owner writes both, and neither needs it. Posts go out to the
public site, the feeds and other sites through webmentions, so a gap in a sanitizer there would reach every reader.
Dropping raw HTML needs no allowlist to keep up.

## Alternatives

**Drop raw HTML, as posts do.** No new dependency and nothing to keep up. It lost because imported issues lean on
HTML, and each `<details>` or `<img>` would leave a hole in the note.

**Commonmarker's `tagfilter` extension with `unsafe`.** It ships with the gem we have. It lost because it escapes
only nine tags, such as `script` and `iframe`, and leaves `onclick` and `javascript:` links alone.

**Loofah, or `rails-html-sanitizer` on top of it.** Loofah also sits on Nokogiri. It lost because changing its
fixed allowlist means writing a scrubber class, where sanitize takes the change as a hash. `rails-html-sanitizer`
adds a Rails wrapper to a Hanami app for no gain.

**Our own Nokogiri walk, or a regex.** A walk needs no new gem, since Nokogiri is in the bundle. It lost because we
would own the allowlist and every trick for getting past it. A regex cannot parse HTML at all.

**Clean the note on write.** Each writer cleans before it saves, and render trusts the store. It lost because there
are three writers, a sync overwrites the note from the issue, and notes already stored would stay uncleaned. It
would also change what MCP reads back and what the edit form shows.

## Consequences

The admin shows an imported issue as its author laid it out, and a note typed in the admin can use the same HTML.

The bundle gains sanitize and Crass, its CSS parser. Both are plain Ruby, and sanitize sits on the Nokogiri we
already ship.

Each render parses the HTML a second time. A note is short and the panel shows one, so the cost stays small.

The allowlist is ours to keep. A sanitize release that closes a hole reaches us only when we update the gem, and
widening the list needs the same care as a change to sign-in.

An image in a note loads from wherever its `src` points, so opening a task can tell a third party the owner's
address and the time.

Two renderers now sit side by side with different rules. Code that renders a note through `Posts::Markdown` loses
its HTML, and code that renders a post through `Tasks::Markdown` lets HTML onto the public site. Pick by what is
being rendered, never by what is closer to hand.

[0071]: 0071-load-a-tasks-read-and-edit-pages-into-dialogs-with-fetch.md
[sanitize]: https://github.com/rgrove/sanitize
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
