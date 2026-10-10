---
id: "0052"
title: Read activity through one view across every content kind
status: active
created: 2026-09-28
area: [activity, admin, mcp, db]
issue: AA-617
amended: [AA-792, AA-824, AA-826, "#17", "#75", "#279", "#263", "#623", "#1013", "#929"]
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
- The reads cross as one exported read repo, `repos.activity_queries` ([ADR 0123][0123], #929). `admin` imports it
  for the Activity screen and `api` for its activity and saved view reads. `mcp` imports nothing from `activity`,
  since it calls `api` in process ([ADR 0088][0088]), and `public` imports none.
- The Activity screen shows the six kinds its Context names, listed in `Admin::Structs::ActivityEvent::KINDS`.
  Projects, sprints and suggestions reach the MCP alone, since the screen has no icon, link or sub-line for them.
- Each read narrows by kind, by repo for commits, by text over the name and sub-line columns, and by tag. The view
  carries no tags, so `Activity::Relations::Activities#tagged` reaches `journal_entry_tags` and `task_tags` by
  source id through its private `tag_owners`, and a row of any other kind never matches a tag.
- Task comments, local and synced, join as the `comment` kind (#75), through
  `config/db/migrate/20260929000051_add_task_comments_to_activities.rb`. The view gains a `task_id` column, set on
  task and comment rows, so a comment matches its task's tags, links to its task and names the task's title in its
  excerpt. A comment lands on the day of its `created_at`, whether or not its task is done. The Activity screen
  shows comments with the six kinds above.
- Decision events join as the `decision` kind and decision comments as `decision_comment` (#279), through
  `config/db/migrate/20261003000156_add_decisions_to_activities.rb`. The view gains a `decision_id` column, set on
  both, so they match the decision's tags and link to its page. An event's name is the decision's title, its status
  the event's kind, and its excerpt the reason, the edit note or else the option's title. A comment's excerpt is the
  decision's title. The Activity screen shows both.
- Closed work sessions join as the `session` kind (#263), through
  `config/db/migrate/20261003000335_add_work_sessions_to_activities.rb`. A session lands on the site day it started,
  even when it runs past midnight, and a running session stays out until it closes. Its name is its task's title and
  its `task_id` its task's, so it matches the task's tags and links to the task. The view gains a `worked_seconds`
  column, set on sessions alone, for the session's length. Moves, tag changes and status changes stay on the task's
  timeline and out of this view. The Activity screen shows sessions.
- Task rows carry their contributors (#623), through
  `config/db/migrate/20261006000623_add_contributors_to_activity_views.rb`. The view gains a `contributors` jsonb
  column: each contributor of a done task as `{kind, agent, model}`, or the owner alone when the task lists none
  ([ADR 0115][0115]). Every other kind holds `NULL`. `contributor:`, `agent:` and `model:` terms narrow the feed to
  the tasks that match, as they narrow the task list, and so drop every other kind. Each term must match some
  contributor on its own, so `agent:claude-code model:claude-opus-5-5` can match two rows of one task.

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
`Social::Operations::ReceiveWebmention` build the path from `Blog::Constants::WRITING_PATH` (#1013), and the feed and
outbound webmentions call `routes.url(:post, ...)`. A new post path means replacing the view as well, and nothing
fails if we forget: the Activity screen matches view counts by that link, so a stale one shows zero views.

The tag filter reads the join tables `record` and `tasks` own, and the `tags` table, in SQL below their exports.

The feed has a slice of its own, so a reader finds it under the name of the thing it answers. That slice costs a
container and a `db` provider to hold one relation, and every slice that reads the feed imports its repo (#929).

[0088]: 0088-hold-the-layer-the-api-and-mcp-share-in-the-api-slice-and-call-it-in-process.md
[0115]: 0115-keep-task-contributors-in-their-own-table-and-list-the-owner-when-a-task-has-none.md
[0123]: 0123-export-only-read-repos-and-operations-and-keep-write-repos-in-their-slice.md
[status]: https://img.shields.io/badge/Active-green?style=for-the-badge
