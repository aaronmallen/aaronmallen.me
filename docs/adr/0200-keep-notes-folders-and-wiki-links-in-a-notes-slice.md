---
id: "0200"
title: Keep notes, folders and wiki links in a notes slice
status: active
created: 2026-10-22
area:
  - db
  - admin
  - api
  - mcp
  - links
issue: "#1924"
amended:
  - "#1947"
tags:
  - notes
  - folders
  - wiki-links
  - slices
  - privacy
---

# ADR 0200: Keep notes, folders and wiki links in a notes slice

![Active][status]

## Context

The admin has no home for private documents that last. Journal entries carry a date and stay short. Artifacts are
numbered plans and specs written for agents ([ADR 0186][0186]). Task notes belong to one task.

Spec #1923 adds a Notes tab: private Markdown notes in a tree of folders, linked to each other with `[[Title]]` and
`[[Title|text]]`. A folder can sit empty, has a page and a description, and passes its record links down to every
note inside it. A note lists its backlinks and its links out, the home pane lists titles linked but not written, and
a rename rewrites every `[[old title]]` in other notes. Agents reach all of it over MCP.

## Decision

A new feature slice, `notes`, owns notes, folders and the links between notes ([ADR 0001][0001]), as `decisions`
([ADR 0099][0099]) and `agents` ([ADR 0186][0186]) own theirs. Other slices read it through its exports and never
write its tables ([ADR 0123][0123]). No public page reads it.

- **Folders are rows of their own**, with a parent folder, a name, a description and an id that stays put when the
  folder moves or takes a new name. A note points at its folder's id, or at none for the root. A folder with no
  notes is still a row, so it stays in the tree, and `record_links` can hold a folder by its id
  ([ADR 0093][0093]).
- **Wiki links are stored.** Each save reads the `[[...]]` links out of the body and replaces the note's stored
  links with one row per title it names. A row keeps the title as written, so a link to a note not written yet
  still counts. Backlinks, links out, the titles not written and the rename rewrite read these rows, not every body.
- **Notes take private tags** through the shared tags table ([ADR 0022][0022], [ADR 0074][0074]). Since #1947 a
  note linked to a project takes that project's tags instead ([ADR 0205][0205]).

## Alternatives

**Keep notes as artifacts.** Artifacts are numbered, versioned documents for agents, with their own type and tags
kept out of the tag screens. A note has no number, version history or agent author, sits in a folder and takes
private tags that belong on the tag screens.

**Keep notes in the journal.** A journal entry hangs off a day. A note has no date and lives for good.

**Store a path string on each note**, such as `work/clients`, as the design's mock does. A folder then exists only
while a note sits in it, so an empty folder vanishes, and a folder has no row to hold a description or a record link.
Renaming a folder rewrites the path on every note under it.

**Read links from the body each time a page draws**, as the design's mock does. Every backlink list, every count of
notes that link to one being deleted and every rename would scan every note's body.

## Consequences

Notes sit in one slice, so one scope can guard them.

The stored links can drift from the body if a write skips the save path, so every write to a body goes through the
operation that reads its links.

Removing a folder has to move its notes and subfolders up to its parent before the row goes, and moving a folder has
to refuse a move inside itself, since a parent column alone allows a loop.

A rename rewrites the body of every note that links to the old title, so one rename can touch many rows.

[0001]: 0001-split-the-app-into-slices-by-feature.md
[0022]: 0022-declare-the-tags-relation-in-every-slice-that-tags.md
[0074]: 0074-split-tags-into-a-public-and-a-private-scope.md
[0093]: 0093-link-any-two-records-through-one-record-links-table-in-a-links-slice.md
[0099]: 0099-keep-decision-logs-in-a-decisions-slice-with-decision-events-and-a-decision-timeline-view.md
[0123]: 0123-export-only-read-repos-and-operations-and-keep-write-repos-in-their-slice.md
[0186]: 0186-keep-agent-memory-artifacts-and-sessions-in-an-agents-slice.md
[0205]: 0205-give-each-project-its-own-tags-through-a-project-scope-on-tags.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
