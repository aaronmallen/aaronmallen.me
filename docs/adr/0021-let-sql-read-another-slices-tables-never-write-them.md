---
id: "0021"
title: Let SQL read another slice's tables, never write them
status: active
created: 2026-09-28
area: [activity, analytics, db, lib, links, posts, search, social, tags]
issue: AA-686
amended: [AA-792, AA-809, AA-824, "#17", "#351", "#302", "#342", "#319", "#305", "#353", "#394"]
tags: [slices, sql, postgres, views, triggers, tags, exports, guards]
---

# ADR 0021: Let SQL read another slice's tables, never write them

![Active][status]

## Context

The record on exports says a slice reaches another only through them: a query for a read, an operation for a
write, and no repo across a line. The former ADR 0003, which held that rule before, noted one exception in passing:
the `activities` view unions tables other slices own and imports nothing.

All the slices share one Postgres database, so any SQL can name any table. The export rule binds Ruby constants and
container keys, and SQL names neither. Four more reads now cross a slice line in SQL, and nothing says when that is
allowed.

## Decision

A slice's SQL may read a table another slice owns. It never writes one. We take the SQL path when the export path
would cost one import per owning slice, or would close a cycle the record on exports refuses. These reads
cross today:

- **The `activities` view**, built in `config/db/migrate/20260928000035_create_activities_view.rb` and read by
  `slices/activity/relations/activities.rb`, unions `commits`, `journal_entries`, `posts`, `social_posts`,
  `social_post_parts`, `webmentions`, `tasks`, `sprints`, `projects` and `suggestions`, which
  `record`, `posts`, `social`, `tasks`, `projects` and `suggestions` own. AA-824 added the last three tables. The
  record on the activities view holds why one view beats merging rows in Ruby.
- **The `attention` view**, built in `config/db/migrate/20261003000075_create_attention_view.rb` and read by
  `slices/activity/relations/attention.rb`, unions `tasks`, `posts` and `journal_entries`, which `tasks`, `posts`
  and `record` own. The record on the stalled list holds why it lives in `activity`.
- **The `review_tasks` and `work_session_days` views**, built in
  `config/db/migrate/20261003000082_create_review_views.rb` and read by `slices/activity/relations/review_tasks.rb`
  and `slices/activity/relations/work_session_days.rb`, read `tasks`, `sprints` and `work_sessions`, which `tasks`
  owns. The record on building the review in one activity query holds why they live in `activity`.
- **The `search_documents` view**, built in `config/db/migrate/20261003000076_create_search_documents.rb` and
  read by `slices/search/relations/search_documents.rb`, unions `tasks`, `posts`, `social_posts`,
  `social_post_parts`, `journal_entries`, `commits`, `projects`, `work_entries`, `people`, `messages` and
  `webmentions`, which `tasks`, `posts`, `social`, `record`, `projects` and `contact` own. The record on searching
  every kind holds why one view serves every search.
- **`Tags::Relations::Tags#counts_by_kind`** counts rows in `post_tags`, `project_tags`, `journal_entry_tags` and
  `task_tags`. The tags screen is the one place that answers for all four kinds at once, and the SQL spares it
  four imports.
- **`Activity::Relations::Activities#tag_owners`**, a private method `#tagged` calls, joins
  `journal_entry_tags` and `task_tags` to `tags` to find the entries and tasks that carry every named tag.
- **`Analytics::Relations::AnalyticsRollupPaths#views_by_post`** joins `posts` on
  `'/writing/' || posts.slug`, built from `Blog::Site::WRITING`, so the admin posts list gets views keyed by post
  id in one query.
- **The `posts_default_webmentions_enabled` trigger**, in `config/db/migrate/20260928000005_create_posts.rb`,
  fills `webmentions_enabled` on insert from social's `webmention_settings`. Reading the setting in `SavePost`
  would make posts import a query from social, which already imports from posts, and ADR 0003 allows no such
  cycle.

- **`Media::Relations::Photos#published`** reads `posts`, which `posts` owns, to find the photos a published post
  claims, so `/media/<key>` serves a visitor those alone. `posts` imports `operations.claim_photos` from `media`, so
  an import the other way would close a cycle.
- **`Tasks::Relations::RecordLinks#project_ids_by_task`** reads `record_links`, which `links` owns, to find the
  projects each task links to for the time report. `links` imports `queries.linkable_tasks` from `tasks`, so an
  import the other way would close a cycle.
- **The `record_links_find_records` trigger**, in `config/db/migrate/20261003000094_create_record_links.rb`, finds
  and locks the row each side of a new link names in `tasks`, `posts`, `social_posts`, `journal_entries`, `commits`,
  `projects`, `work_entries` or `decisions`, which `tasks`, `posts`, `social`, `record`, `projects` and `decisions`
  own. The same migration hangs a `<table>_drop_record_links` trigger on each of those eight tables, which deletes
  the links of a deleted row from `record_links`, a table `links` owns. A migration that drops and rebuilds one of
  the eight tables loses its trigger. The record on linking any two records (ADR 0093) holds why Postgres keeps
  these rules.
- **The `attention_snoozes_drop_record` trigger**, in
  `config/db/migrate/20261003000196_create_attention_snoozes.rb`, hangs on `tasks` and `posts`, which `tasks` and
  `posts` own, and deletes a deleted row's snoozes from `attention_snoozes`, a table `activity` owns. The record on
  the stalled list (ADR 0095) holds why snoozes live there.

The one table several slices write is `tags`, and the record on declaring the tags relation in every slice that
tags holds that choice.

A new read across a slice line in SQL joins the list above, in the change that adds it.

## Alternatives

**A query export for each read.** It keeps every crossing in `config/slice.rb`, where the slice graph and its
guards can see it. The tag counts alone would take four imports, and the trigger's read would close the
posts and social cycle.

**A view for every read that spans slices**, the way activity reads. Each one is a migration, and Postgres will
not change a column a view reads, so every migration that touches such a column has to drop and rebuild the view.
One view that serves a whole feature earns that cost. One for a single count does not.

## Consequences

A read that spans slices costs one query rather than one per slice, and posts and social stay out of a cycle.

No spec sees any of these reads, and we write no guard for them. One on `dataset.db[` would catch the tag counts
and `tag_owners` alone. It would miss the view, the posts join and the trigger and flag reads inside one slice such
as `SocialPosts#unclaimed`. The list in this record is the only check, and it holds only if each change keeps it up
to date.

A reach ties the owner to a column it cannot see is read. Renaming a column in `post_tags` or `webmention_settings`
breaks the tags screen or the trigger when it runs, and only the reader's specs notice.

`views_by_post` meets neither test. It reads one slice's table, and an import from posts would close no cycle, so
no record or issue says why it joins in SQL rather than taking an export.

It also matches paths as text. The route and the join both build on `Blog::Site::WRITING`, and
`posts_lock_published_slug` refuses a new slug once a post is published. A new prefix still leaves every rollup
row under the old path unmatched, so each post's past views drop to zero with no error.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
