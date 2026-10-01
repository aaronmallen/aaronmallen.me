# Changelog

This file records each notable change to the site. It follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [BreakVer](https://www.taoensso.com/break-versioning).

## [Unreleased]

## [1.3.0] - 2026-09-30

### Added

- Photos. The Markdown editor takes a photo by drop, paste or its photo button, and puts the link at the cursor once
  it uploads. The site turns each photo upright, shrinks its long edge to 2560px, strips its metadata, saves HEIC as
  JPEG and serves it at `/media/<key>`. It refuses a file over 20 MB or 100 megapixels, and any type but JPEG, PNG,
  WebP, GIF and HEIC. Uploads need scripts on and an S3 store in settings; with no store the editor shows no photo
  button.
- A photo lives while a post, its Open Graph image, a journal entry, a task or a task comment points to it. Deleting
  the last record that points to it deletes the photo, and a sweep at 05:30 each day deletes any photo nothing points
  to that was uploaded over a day ago.
- Every Markdown box in the admin, from the journal and the Today journal card to task notes and comments, has the
  toolbar and preview the post editor has.
- A change to the body of a published post needs an edit note saying what changed and why. The post page lists the
  notes by day above the "Found a typo" line, the Atom feed adds them to the foot of each entry, and an Edit notes
  card in the post editor rewords one. The MCP `update_post` tool takes an `edit_note`. Drafts, scheduled posts and
  saves that leave the body alone need no note.
- A People screen holds the people social posts can mention, with their Mastodon and Bluesky handles. Typing @ in
  the social composer opens a list of them and puts in a `@{key}` token. Each network gets the person's handle there,
  or their name when they have none, and a preview under each part shows the text each network gets. The counters
  measure that text, and a token that names nobody fails the save.
- Webmentions take a third verdict, Ignore, which hides a mention without marking its author as spam. The
  webmentions page gains an Ignored filter, and the MCP `moderate_webmention` tool takes `ignored`.
- `mise run setup:dependencies` installs libvips with HEIC support through brew, apt-get, dnf or pacman when Ruby
  cannot load it, and `mise run test` points to that task when libvips is missing. `mise run dev` starts a RustFS
  store with its bucket.

### Changed

- Every link chip on a task row shows only the linked task's number, as the blocked-by chip already did. The title
  shows on hover and to screen readers.

### Fixed

- Hashtags in a post sent to Bluesky work as tags. Before, they went out as plain text.

## [1.2.0] - 2026-09-29

### Added

- Tasks take comments. The task page lists them oldest first as Markdown, and a form under them adds one. A comment
  written here can be edited or deleted. GitHub and Linear issue comments sync onto their tasks, show their author
  and a link back, and cannot be changed here. The new `add_task_comment` MCP tool adds one, and `read_task` and every
  tool that changes a task answer with the task's comments. Comments show in the activity feed.
- An imported issue's labels tag its task once, when the sync creates it. A label adds only a private tag that
  already exists, and a later sync never adds a tag back or reads a new label.
- Tags come in two kinds: public for posts and projects, private for tasks and the journal. The same name can live
  in each with its own color, and the tags page has a tab for each. Tags a task or journal entry used turn private,
  and a tag both sides used splits into a public and a private copy.
- Search the journal by tag with `tag:name`. An entry must carry every tag named.
- The Today journal card takes tags beside the body.
- The command palette has a Create journal entry row, which opens the journal with the cursor in the entry field.
- Each task row ends with a pen that opens the task's edit dialog in one click.
- Honeybadger names the release behind each error.

### Changed

- Long lists page. `/writing` and tag pages show 25 posts a page, and the Atom feeds carry the newest 25 with next
  and previous links. The admin posts, messages, webmentions, tags, social and task lists show 100 a page, and the
  finished tasks list no longer loads every task. The journal and the activity feed page by whole days, and an event
  in the activity feed opens the journal page that holds its day. Task search now finds matches on every page, and
  tab counts cover the whole list.
- The MCP list tools (`list_posts`, `list_social_posts`, `list_tasks`, `list_messages`, `list_webmentions`,
  `list_suggestions`, `list_sprints` and `list_tags`) answer 100 rows at a time and take a `page`. A partial answer
  names the `next_page` to ask for. `read_activity`, `list_commits` and `list_journal_entries` stop near 100 rows, down
  from 200.
- The `list_tags`, `save_tag` and `remove_tag` MCP tools need a `scope` of `public` or `private`. A call without one
  fails.
- Moving an in-progress task out of Today, by hand, by unscheduling it, by dropping its sprint or through the MCP
  `move_task` tool, sets it back to open. The move arrow on a running task asks first.
- Canceling a task asks first, in a dialog.
- Tags in the admin read as `#name` in their color. A task tag opens the task list searched by that tag, a journal
  tag the journal, and a tag on the posts list its public tag page. The journal no longer shows a Private pill.
- The referrer and country cards rank by visitors and show them. Days rolled up before this release have no visitor
  count, and those rows show none. The paths, referrer, country and webmentions cards show up to 10 rows.
- The Today commits card lists the 10 latest commits and links to the rest on the activity page.
- The tasks page switches pools without a reload, and pulling a task in returns to the pool it came from.
- A task's page shows its number above the title, with the GitHub `owner/repo#number` or the Linear key for a
  synced task.
- A blocked-by chip on a task row shows only the blocker's number. The title shows on hover and to screen readers.
- The issue sync asks Linear for 25 issues at a time, not 100, and stops at 250 assigned issues per workspace, down
  from 1,000.

### Fixed

- A click outside the task dialog no longer closes it and throws away what you typed. It closes on Esc, Cancel or a
  new X button.

## [1.1.0] - 2026-09-29

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

[Unreleased]: https://github.com/aaronmallen/aaronmallen.me/compare/1.3.0...HEAD
[1.3.0]: https://github.com/aaronmallen/aaronmallen.me/compare/1.2.0...1.3.0
[1.2.0]: https://github.com/aaronmallen/aaronmallen.me/compare/1.1.0...1.2.0
[1.1.0]: https://github.com/aaronmallen/aaronmallen.me/compare/1.0.2...1.1.0
[1.0.2]: https://github.com/aaronmallen/aaronmallen.me/compare/1.0.1...1.0.2
[1.0.1]: https://github.com/aaronmallen/aaronmallen.me/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/aaronmallen/aaronmallen.me/releases/tag/1.0.0
