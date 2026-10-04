# Changelog

This file records each notable change to the site. It follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [CalVer](https://calver.org) as `YY.M.MICRO`, dated by the UTC day of the tag.

## [Unreleased]

## [26.10.2] - 2026-10-03

### Added

- `REDIS_CONNECT_TIMEOUT`, `REDIS_TIMEOUT` and `REDIS_RECONNECT_ATTEMPTS` set how long Sidekiq waits on Redis and how
  often it tries again, so a short outage need not fail a job. Left unset, Sidekiq keeps its own defaults.

### Fixed

- The Atom feeds answer a reader whose `If-Modified-Since` date has a one-digit day, such as
  `Thu, 1 Oct 2026 12:00:00 GMT`. They used to answer 500, and now ignore a date they cannot read.
- Publishing or saving a post, and receiving a webmention, no longer answer 500 when Redis is down. The post or
  mention saves, its job waits in Postgres, and it goes out within a minute of Redis coming back.
- The issue sync no longer stops for good when a deleted or moved issue comes back assigned. Its old task reopens,
  where the sync used to fail on that issue every run.
- A photo dropped into a post's edit note keeps its claim, so the sweep of unclaimed photos no longer deletes it.
- Visit beacons for media, the web manifest and the Atom feeds no longer count as views, so made-up media keys
  cannot fill the top paths.
- The admin activity and journal pages ignore a date before year 1000 or after 9999, where they used to answer 500.
- The post editor and the social composer check a Bluesky part's length with the `?ref=bluesky` tag on its links, so
  a part that fits only without the tag no longer saves and then fails to send.
- A webmention whose target slug decodes to bad UTF-8 answers 400, where it used to answer 500.
- Linking a task to an ID past 2147483647 gets the "task is gone" error in the admin, the API and MCP, where it used
  to answer 500.
- The contact form refuses a subject, body or reply-to made only of Unicode spaces, where it used to answer 500.
- The admin photo upload and task palette answer 400 to a body that is not valid JSON, where they used to answer 500.
- The newer link on the admin journal no longer skips days when one day holds more entries than fit on a page.
- The MCP `report` prompt refuses a range over 366 days, as `summarize_activity` and `read_analytics` do.

## [26.10.1] - 2026-10-02

### Added

- A JSON API at `/api/v1` lists, reads, creates, changes and deletes journal entries, tasks, task comments, task
  links and sprints. It takes a bearer token minted on a new API tokens page in the admin, which shows each token
  once and can revoke it. A token never expires. `GET /api/v1/openapi.json` serves an OpenAPI 3.1 document of every
  route. The MCP tools for these records now run through the same code and answer as before.
- Drag a task row by its grip to reorder it in its list or sprint, or move a focused row with Alt+Up and Alt+Down.
  A move saves at once, and a failed save puts the rows back and shows a toast.
- `read_analytics` answers far more:
  - `path` narrows the answer to one page, with its days, referrers, countries, sources, devices, scroll depth and
    the pages on the site that sent readers to it. For a published post it adds `since_publish`, which numbers the
    days from the day it went out, so two posts line up.
  - `hours` gives views and visitors for each hour, and `since` counts views, visitors and read time from a given
    time. `read_spread` sorts views by read time and gives the median. These read raw visits, so they reach back
    90 days, and the answer says so when a range starts before that.
  - `reach` counts visitors once a month, `devices` splits views into desktop, mobile, tablet and in-app, and
    `entry_pages` and `exit_pages` name where each day's visits start and end.
  - `sources` counts visits by the `?ref=` on the link. Links in posts sent to Mastodon and Bluesky carry
    `?ref=mastodon` or `?ref=bluesky`, and links in the Atom feed carry `?ref=feed`.
  - The tool's description defines a view, a visitor, a bounce and read seconds, and the answer names its
    `time_zone`.
- Each row on the admin posts list shows visitors beside views.
- `read_activity` rows carry their tags.
- A webmention marked spam can carry a note saying why, in the admin and through `moderate_webmention`.
  `list_webmentions` returns it as `spam_reason`, and gives `received_at` in Chicago time with a `time_zone`.
- Marking a message spam flags its sender, and later messages from that address land as spam. Marking one of their
  messages read or unread clears the flag. Spam messages go 30 days after they were marked.
- The @ list in the social composer ends with an Add New row, which opens a form to add a person without leaving the
  post. Each handle field on that form, and on the People screen, can search Mastodon or Bluesky for the account
  when that network has credentials.
- On a published post, saving a changed body opens a dialog that asks for the edit note. The note's card now sits
  under the body editor rather than in the sidebar.
- The glasses favicon is back, with an apple-touch-icon, a web app manifest and a theme color for light and dark.
  `mise run assets:icons` draws the icons from the SVG.
- `mise run db:seed` fills a development database with a record in every state, from tasks and sprints to posts,
  webmentions, messages and analytics. A second run adds nothing.

### Changed

- Anonymous visitors to the home page, about, projects, the post list, a post and a tag page get a copy that
  Cloudflare may keep for five minutes. A missing photo's 404 keeps for one minute.
- Edit notes read newest day first, each under an orange "Edited" date, on the post page and in the Atom feed.
- The contact form takes at most 20 messages an hour from everyone together, set by `CONTACT_TOTAL_THROTTLE_LIMIT`.
  The limit for one sender treats every IPv6 address in a /64 as one sender.
- The MCP `suggest_edits` and `accept_suggestion_edits` tools, and accepting a suggestion in the admin, work on
  drafts and scheduled posts only. A published post changes through an edit with a note.
- `read_analytics` and `summarize_activity` refuse a range longer than 366 days.
- A closed GitHub or Linear issue syncs once a day rather than every run, so a reopened issue can take up to a day
  to show.
- An MCP client that holds no live token and has not connected in 90 days goes, with its codes and tokens.

### Removed

- The up and down carets on task rows. With scripts off, the admin can no longer reorder tasks.

### Fixed

- Yesterday's analytics read zero between midnight and the 01:00 rollup, or all day after a failed rollup.
- A read sent after midnight for a page opened before it failed, so the visit lost its read time.
- Visits to a post or tag page that does not exist no longer count in analytics.
- The Atom feed now changes when an edit note, a tag name or a deleted post changes it. Before, a reader could keep
  a stale copy.
- A message near the length cap with line breaks passed the counter, then failed as too long.
- A thread sent to Bluesky signed in once per part, and a long one could hit Bluesky's sign-in limit.
- A webmention sent again inside the throttle window got a 202 but never landed. It now gets a 429.
- A webmention endpoint that answers 4xx no longer retries, and one dead endpoint no longer leaves later edits
  pinging links the post dropped.
- Searching the activity feed or `read_activity` for two repos dropped every commit.
- One post that failed to publish held back every post due after it.
- A task capture or edit refused for its sprint date kept the task or its new title and tags.
- Two tasks or projects saved at the same moment could take the same place, and a project save then failed with a
  500.
- Reordering a task did nothing when it shared a place with its neighbor.
- A photo uploaded while the nightly sweep ran could vanish with the post that just claimed it.
- An MCP client that connects to OAuth 2.1 without a `redirect_uri` could not finish signing in.
- The first request or job after Postgres dropped its connections failed with a 500.
- A GitHub issue sync with no token logged a failure on Today every 15 minutes.

### Security

- Refreshing an MCP token ends the old access token at once rather than an hour later.
- Revoking an MCP client while it refreshed a token could leave it a live token.
- A request body over 1 MB, or 25 MB for a photo upload, gets a 413, and a multipart body sent anywhere but photo
  uploads gets a 415.

## [26.10.0] - 2026-10-01

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

## [26.9.4] - 2026-09-30

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

## [26.9.3] - 2026-09-29

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

## [26.9.2] - 2026-09-27

### Fixed

- The writing and tag feeds answer browsers and readers that ask for any type, not only `application/atom+xml`.
  They used to get a 406.
- CI runs again: it sets `GEM_HOME` in the install step, compiles Ruby the way `mise.lock` expects, and resolves the
  link-local test address on Linux.

## [26.9.1] - 2026-09-27

### Fixed

- Social posts reach Bluesky. Each part now sends a TID as its record key, where Bluesky refused the old key with a
  400, and a failed send names Bluesky's reason.
- MCP clients such as Claude Code ask for every scope, not read alone. The protected resource document now lists
  `scopes_supported`, where they look for the scopes to ask for.

## [26.9.0] - 2026-09-27

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

[Unreleased]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.2...HEAD
[26.10.2]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.1...26.10.2
[26.10.1]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.0...26.10.1
[26.10.0]: https://github.com/aaronmallen/aaronmallen.me/compare/26.9.4...26.10.0
[26.9.4]: https://github.com/aaronmallen/aaronmallen.me/compare/26.9.3...26.9.4
[26.9.3]: https://github.com/aaronmallen/aaronmallen.me/compare/26.9.2...26.9.3
[26.9.2]: https://github.com/aaronmallen/aaronmallen.me/compare/26.9.1...26.9.2
[26.9.1]: https://github.com/aaronmallen/aaronmallen.me/compare/26.9.0...26.9.1
[26.9.0]: https://github.com/aaronmallen/aaronmallen.me/releases/tag/26.9.0
