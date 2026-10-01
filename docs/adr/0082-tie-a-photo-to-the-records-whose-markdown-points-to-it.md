---
id: "0082"
title: Tie a photo to the records whose Markdown points to it
status: active
created: 2026-09-30
area: [media, posts, record, tasks]
issue: "#134"
amended: ["#140"]
tags: [media, photos, uploads, claims, references, deletion, sweep, sidekiq, feeds, webmentions]
---

# ADR 0082: Tie a photo to the records whose Markdown points to it

![Active][status]

## Context

Spec #128 lets the writer drop a photo into any Markdown editor in the admin: a post, a journal entry, a task note
or a task comment. The upload lands in the S3 store ([ADR 0080][0080]) the moment it is dropped, before the record
it goes in is saved. A new post has no id yet, so the upload cannot name its owner.

Nothing ties a photo to a record after that. Delete a post and its photos stay in the store, and nobody can tell
which ones are left over. One photo can also sit in two records, so deleting one of them cannot simply take
every photo it shows.

## Decision

A photo belongs to the records whose Markdown points to it, and to nothing else.

- **An upload starts with no owner.** The endpoint stores the photo and hands back its URL, and nothing more.
- **Saving claims by reference.** Saving a post, journal entry, task or task comment reads the `/media/<key>` URLs
  in its Markdown and makes the record's claims match them: a photo the text now points to gains a claim, and one it
  no longer points to loses one. A photo can carry claims from many records. #140 added a post's Open Graph image
  field, so a `/media/<key>` URL there claims too, and a card image can be an upload.
- **Deleting releases, and the last release deletes.** Deleting a record drops its claims, and deletes from the
  store and the table each photo left with no claim. Deleting a task does the same for its comments.
- **A sweep takes the rest.** A scheduled job deletes every photo that has no claim and was uploaded over 24 hours
  ago. That covers a draft abandoned before its first save and a photo an edit took out of the text. It never
  retries, and its next run catches up ([ADR 0012][0012]).

The media slice owns the claims, next to the photos. Posts, record and tasks each call its exported operations from
their save and delete operations ([ADR 0003][0003]).

## Alternatives

**Photos that outlive everything.** No claims and no sweep: once stored, a photo stays. It is the simplest, and
nothing can delete a photo a page still shows. It lost because the store only grows, with every abandoned draft and
deleted post still in it, and nobody can tell which photos anything still uses.

**An owner passed at upload time.** The editor sends the record's kind and id with the photo, and the photo belongs
to that record alone. It lost because a new post has no id until it is saved, so a drop into an unsaved post has no
owner to name. It also cannot share one photo between two records.

## Consequences

The store holds only photos some record still uses, plus about a day of uploads nobody has claimed.

Deleting a post takes its photos with it. The post's URL is gone, but copies of its HTML are not: a feed reader that
cached the entry and a site that shows a webmention excerpt both still point to `/media/<key>`, and each of those
photos now answers with the empty 404 from [ADR 0080][0080].

Only Markdown and a post's Open Graph field claim. A photo URL pasted into a social post holds no claim, and the
sweep deletes the photo within a day unless some record also points to it.

An edit that drops a photo from the text leaves it unclaimed, so putting the URL back more than a day later finds
the photo gone.

Every new kind of record that takes Markdown with photos has to claim and release through the media slice. One that
does not will see its photos swept a day after upload.

[0003]: 0003-reach-another-slice-only-through-its-exports.md
[0012]: 0012-never-retry-a-scheduled-job-and-make-its-next-run-catch-up.md
[0080]: 0080-store-photos-in-an-s3-store-and-serve-them-through-the-site.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
