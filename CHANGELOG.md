# Changelog

This file records each notable change to the site. It follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [BreakVer](https://www.taoensso.com/break-versioning).

## [Unreleased]

### Added

- Cancel a task from its row, its page or the new `cancel_task` MCP tool. A canceled task leaves the open lists,
  shows on the finished list with its own mark, and no longer blocks the tasks it blocked.
- A Create Task dialog holds every field a task has. The tasks page and the command palette both open it, and with
  scripts off it opens as its own page at `/admin/tasks/new`.
- Issues assigned to me on GitHub and Linear become tasks on a new External list. They sync every 15 minutes, or
  from the Sync issues button on the External tab. Each task links back to its issue and follows it: it closes,
  reopens or starts when the issue does, and cancels when the issue closes as not planned, moves or goes away.
- Each task has a page at `/admin/tasks/:id` and an edit page at `/admin/tasks/:id/edit`. A task's title opens the
  first in a side panel, and Edit opens the form in a dialog that shows a failed save's errors in place.
- Task notes render as Markdown, raw HTML included, with scripts, styles and unsafe links taken out.
- A Unique visitors tile on Today counts today's visitors.
- Every public page links the writing feed from its head.

### Changed

- Task types are now tags. A migration turns each type into a tag and gives that tag to every task that held the
  type.
- Capture no longer turns a `#word` into a tag. Tags come from the tags field, and the MCP `capture_task` tool takes
  a list of tags.
- Journal entries render as Markdown on the journal page, the Today card and the activity feed.
- The In the queue tile on Today counts what waits by kind, such as "2 posts · 1 social post", in place of the next
  title.
- `mise run test` creates or migrates the test database before the suite runs, and stops at once when another run
  holds the database.

### Removed

- The Task Types screen, the type filter, the `type:` search term and the four MCP task type tools.
- The editor that opened inside a task's row. The task's edit page replaces it.
- The Journaled tile on Today.

## [1.0.2] - 2026-09-27

### Fixed

- The writing and tag feeds answer browsers and readers that ask for any type, not only `application/atom+xml`.
  They used to get a 406.
- CI runs again: it sets `GEM_HOME` in the install step, compiles Ruby the way `mise.lock` expects, and resolves the
  link-local test address on Linux.

## [1.0.1] - 2026-09-27

### Fixed

- Social posts reach Bluesky. Each part now sends a TID as its record key, where Bluesky refused the old key with a
  400, and a failed send names Bluesky's reason.
- MCP clients such as Claude Code ask for every scope, not read alone. The protected resource document now lists
  `scopes_supported`, where they look for the scopes to ask for.

## [1.0.0] - 2026-09-27

### Added

- The public site: home, about, projects and contact pages, the writing index, posts and tag pages, Atom feeds for
  all writing and for each tag, webmentions and cookie-free visitor counts.
- An admin behind GitHub sign-in for posts, social posts, the journal, tasks and sprints, projects and work history,
  tags, messages, webmentions, analytics and the activity feed, reached through a command palette and usable on a
  phone.
- Scheduled posts, and social posts sent to Mastodon and Bluesky.
- An MCP server with its own OAuth 2.1 sign-in, to read the site, suggest edits to drafts and make any change the
  admin makes.
- Background jobs that import commits from GitHub, refresh projects and social engagement, roll the sprint over each
  night and roll up analytics.

[Unreleased]: https://github.com/aaronmallen/aaronmallen.me/compare/1.0.2...HEAD
[1.0.2]: https://github.com/aaronmallen/aaronmallen.me/compare/1.0.1...1.0.2
[1.0.1]: https://github.com/aaronmallen/aaronmallen.me/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/aaronmallen/aaronmallen.me/releases/tag/1.0.0
