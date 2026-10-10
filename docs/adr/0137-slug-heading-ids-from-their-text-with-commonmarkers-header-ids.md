---
id: "0137"
title: Slug heading ids from their text with commonmarker's header ids
status: active
created: 2026-10-09
area: [lib]
issue: "#848"
amended: ["#910"]
tags: [posts, markdown, commonmarker, anchors, headings]
---

# ADR 0137: Slug heading ids from their text with commonmarker's header ids

![Active][status]

## Context

Spec #835 wants a link to each section of a post, and a table of contents built from a post's h2s. Post headings
have no ids today: `Posts::Markdown` turns commonmarker's `header_ids` extension off. Once readers and other sites
link to a section, its id is part of a public URL. The renderer also writes the feed, the API and the admin preview,
so the ids reach all three.

## Decision

`Posts::Markdown` turns on commonmarker's `header_ids` extension. Every heading, h1 to h6, gets an id slugged from its
text, and a heading whose slug repeats an earlier one gets a numbered suffix. We write no slug code of our own.

It renders a level one heading as an `h2`. Every page that shows rendered markdown draws its own `h1`, and
[ADR 0037][0037] allows a page only one.

## Alternatives

**Ids written by hand in the markdown.** An id would survive a change to the heading's text, but every heading would
need markup the writer has to remember, and a heading without it would have no anchor at all.

## Consequences

Every heading gets an anchor without the writer doing anything, and the post page, feed, API and preview agree on
the ids because one renderer writes them all.

An id follows the text. Rewording a heading in a published post breaks every link to it, and so does adding a heading
with the same text above it, which shifts the suffixes below.

The slug rules belong to commonmarker. A commonmarker upgrade that changes them changes the ids of published posts,
so an upgrade has to check them.

`Posts::Markdown` also renders journal entries, edit notes and commit and pull request bodies, so their headings
take ids too. The post page renders edit notes apart from the body, so a heading in a note can repeat an id the body
already holds.

A `#` line in a post joins the table of contents with the `h2`s, and a writer who wants a heading above the `h2`s
cannot have one.

[0037]: 0037-give-every-public-page-an-h1-hidden-where-the-design-draws-none.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
