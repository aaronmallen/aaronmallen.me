---
id: "0052"
title: Read activity through one view across every content kind
status: active
created: 2026-09-28
area: [activity, admin, mcp, db]
issue: AA-617
amended: [AA-792, AA-824, AA-826, "#17"]
tags: [activity, view, postgres, timeline, search, tags]
---

# ADR 0052: Read activity through one view across every content kind

![Active][status]

## Context

The Activity screen (AA-211) answers "what did I do between these two dates". It lists commits, blog posts, journal
entries, social posts, tasks and webmentions in one timeline, newest first, with a count for each kind. A 90-day
range with every kind has to load in under a second. The MCP server reads the same feed (AA-432, AA-434), and
AA-824 added projects, sprints and suggestions to it so an agent reads every kind.

Those kinds live in nine tables that six slices own. The design handoff built the timeline by pulling every kind
into memory, mapping each to one shape and filtering there. Its README called that a stand-in: in production it
wanted one query with an index on the date and kind.

Journal entries are private, and commits include private and org repos.

## Decision

We read activity from one Postgres view, `activities`, that unions the nine tables into one shape.

- `config/db/migrate/20260928000035_create_activities_view.rb` builds it. Each row carries its kind, its source id,
  the site day and time it happened, a name, a link, and the parts of its sub-line: repo, sha, line counts, status,
  networks and excerpt. The view returns values, and Ruby composes the line through i18n (AA-333).
- Commits, journal entries and sprints store a day. The other tables store an instant, and each has an index on
  its site day, so a date range narrows every branch of the union (AA-260). A project and a suggestion land on the
  day of their `created_at`, and a sprint at midnight on its `sprint_date`, since it holds no time.
- `slices/activity` owns the relation and its repo. The view spans tables six other slices own, so no one of them
  owns it, and a presentation slice owns no feature's records (ADR 0001).
- The reads cross as four exported queries: `queries.activity_between`, `queries.activity_counts`,
  `queries.activity_commit_totals` and `queries.activity_counts_by_month`. `mcp` imports all four for its activity
  tools, `admin` imports the first two for the Activity screen, and `public` imports none.
- The Activity screen shows the six kinds its Context names, listed in `Admin::Structs::ActivityEvent::KINDS`.
  Projects, sprints and suggestions reach the MCP alone, since the screen has no icon, link or sub-line for them.
- Each read narrows by kind, by repo for commits, by text over the name and sub-line columns, and by tag. The view
  carries no tags, so `Activity::Relations::Activities#tagged` reaches `journal_entry_tags` and `task_tags` by
  source id through its private `tag_owners`, and a row of any other kind never matches a tag.

A new content kind joins by giving its table an index on its day, adding a branch to the view's migration, and
adding its name to `Blog::Types::ActivityKind`. It shows on the Activity screen only once it joins
`Admin::Structs::ActivityEvent::KINDS`.

## Alternatives

**Merge in Ruby.** Query the tables and combine the rows in Ruby, as the handoff's prototype did. The handoff itself
turned this down for production. Filters, counts and sorting would all run on rows pulled into memory.

**Let kinds join the view as they ship**, or build it after posts, journal and commits only. Activity could come out
sooner, but every later feature would then have to extend the view.

**Keep the view in `record`**, which owns two of the nine tables and already exports to `admin`. It costs no new
container and no new `db` provider. It puts reads over five other slices' tables in a slice named for something
else, so a reader looking for the feed would have no reason to open it.

## Consequences

A date range, its filters and its counts are one query against one relation.

The view reads columns in nine tables and the ones it joins. Postgres will not drop or change a column a view reads, so
a migration that touches one has to replace the view too.

The text filter matches columns no index covers. It stays fast only while the date range keeps the rows few.

The view and its indexes hold `Blog::TimeZone::NAME` as a literal, since Postgres builds an index only from an
immutable expression. A new zone means a rebuilt database.

The post and webmention branches write `'/writing/' || posts.slug`, since SQL cannot call the router. The routes and
`Social::Operations::ReceiveWebmention` build the path from `Blog::Site::WRITING`, and the feed and outbound
webmentions call `routes.url(:post, ...)`. A new post path means replacing the view as well, and nothing fails if we
forget: the Activity screen matches view counts by that link, so a stale one shows zero views.

The tag filter reads the join tables `record` and `tasks` own, and the `tags` table, in SQL below their exports.

The feed has a slice of its own, so a reader finds it under the name of the thing it answers. That slice costs a
container and a `db` provider to hold one relation, and every reader of the feed costs an exported query.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
