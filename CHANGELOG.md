# Changelog

This file records each notable change to the site. It follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [CalVer](https://calver.org) as `YY.M.MICRO`, dated by the UTC day of the tag.

## [Unreleased]

## [26.10.4] - 2026-10-07

### Added

- Admin pages update live. A change made through the API, MCP, the issue sync or another tab redraws the open page
  in place, keeping the focused field and its unsent text, and waits while a dialog is open. Each signed-in tab holds
  one stream open to `/admin/events`, which sends a heartbeat every 30 seconds.
- Each tag has an admin page at `/admin/tags/<name>` that lists the posts, projects, tasks, journal entries and
  decisions carrying it, in every status. A tag anywhere in the admin links there, and on the Tags screen only the pen
  button opens the rename form. `GET /api/v1/tags/:name` and the `read_tag` MCP tool return the same list.
- A task names who did it: me, an agent with its model, or both. The task editor sets them, the task page lists them,
  and a task that names no one reads as mine. A commit that closes an issue with a `Co-Authored-By: Claude ...`
  trailer credits that agent and model on the issue's task. The task list, the activity screen and saved views take
  `contributor:`, `agent:` and `model:` terms in the search box, and the Review's done card has a Done by switch with
  agent and model picks. The activity feed and the review name who did each task, and `save_task`, `list_tasks`,
  `read_activity`, `read_review` and their API routes take and return contributors.
- The issue sync copies each issue's links from GitHub and Linear onto its task, parents and children included, and
  imports the open issue at the other end of a link even when it is not assigned. A synced link follows its issue and
  leaves links made by hand alone. A task page shows these as "parent of" and "child of".
- A task tag rule names GitHub or Linear, so issues synced from Linear get tags too. A Linear rule matches
  `workspace/team`. The admin form, the API, `save_task_tag_rule` and `list_task_tag_rules` take and show the
  provider, and rules made before this release are GitHub rules.
- Decision rows and the decision page show the decision's #id, which copies on click, as a task's does.
- The `read_photo` MCP tool returns a photo from a draft, journal entry, task or comment as an image.
  `list_api_tokens` and `list_clients` list live API tokens and connected MCP clients with their scopes, but never a
  token.
- MCP tools and their API routes answer more:
  - `list_tasks` takes `sprint_on` to read one day's sprint and returns `total` across pages. Tasks carry their
    `position`, and `reorder_task` takes `after_id` to place a task after another, or first when null.
  - `list_posts` takes `status` and returns counts by status, with each post's words, views, visitors, readers,
    read-throughs and webmentions.
  - `list_social_posts` takes a `queue` of queued, posted or drafts and returns counts by queue. It,
    `list_webmentions` and `list_messages` no longer need `from` and `to`, and the last two return counts by status.
  - `list_decisions` takes a `query` and returns counts by status. `list_tags` takes a `query` and returns a count.
    `list_journal_entries` takes a `tag` and returns the journal's entries, words and streak.
  - `capture_task` takes a note.
  - Each social post carries `lengths`, the count and limit of each part on each network, and a send refused as too
    long names each part and network over the limit.
  - `list_inbox` rows carry a task's tags and source, a webmention's type and post, and a message's reply-to.
  - `read_post` and `read_social_post` return the `suggestion_id` that `accept_suggestion_edits` and
    `reject_suggestion_edits` take.
- The contact form drops a message sent within 3 seconds of the page loading, more than 24 hours after, or without
  the page's signed stamp, and answers as if it went. `CONTACT_MINIMUM_SUBMIT_SECONDS` and
  `CONTACT_STAMP_EXPIRY_HOURS` set the two limits.

### Changed

- Publishing and deleting through MCP need their own scopes. `publish_post` and `send_social_post` need publish, and
  every `delete_*` tool and `remove_tag` need delete. The consent page lists each scope. A client connected before
  this release keeps read, suggest and write only, and must connect again to see these tools.
- The time report groups by tag unless told otherwise, and its Group by control reads Tag, Project, Day. Task links
  in the report stand at least 24px tall, and 44px on a phone.
- The palette's Create task, Create decision and Create journal entry actions show their sections' icons.
- A click outside the edit note dialog closes it, as Cancel does.

### Removed

- The command palette no longer has a Log work action, and the admin no longer draws its dialog. The action added a
  role to the work history, not time to a task. Roles still go in through the Work tab on the Projects screen and the
  `add_work_entry` MCP tool.

### Fixed

- `upload_photo` failed through MCP for a photo over about 750 KB, because the server read only the first 1 MiB of
  the request.
- A retry after a failed webmention send mentioned every linked page again. It now sends only to the pages that
  failed.
- The Delete button on a journal entry did nothing with scripts off.
- A task deleted while an issue sync ran stopped the run, leaving the rest of the issues unsynced and no failure
  shown.
- A GitHub answer that left out the signed-in user made the sync read every issue as unassigned. The run now fails
  instead.

### Security

- A request body past the largest upload limit gets a 413 before the server reads it, so large bodies can no longer
  fill the server's temp folder.
- The request log hides every param whose name ends in `_key`, `_secret` or `_token`. Names such as `api_token` and
  `webhook_secret` used to reach it.
- MCP marks more text as untrusted: a synced task's title wherever a task shows, such as links, search, activity,
  attention, the review, the time report and the inbox, a synced comment's author, and the title, excerpt and link of
  inbox messages and webmentions.

## [26.10.3] - 2026-10-04

### Added

- A Decisions screen in the admin lists, opens, edits and closes decisions. Each one holds options, comments, tags,
  linked records and a timeline, and closing one asks for a note. Decision events and comments show in the activity
  feed, and the API and MCP read and write every part of a decision.
- Starting a task opens a work session, and pausing, finishing or canceling it closes the session. Each task keeps
  its worked time, which can be set by hand, and completing a task asks for it. Sessions can be edited or deleted,
  a Log work dialog in the command palette adds time, and sessions show in the activity feed. A Time screen sums work
  by project, tag or day over a range and drills into each row. The API and MCP pause tasks, change sessions, set
  totals and read the time report.
- A task's page has an Activity section listing its moves, tag changes, status changes and comments, and `read_task`
  returns the same timeline.
- The task, post, project, commit, journal entry, social post, work entry and decision pages have a Linked section,
  with a picker that finds a record of any kind. The API and MCP link, unlink and list links, and the reads for
  tasks, posts, social posts and journal entries return them.
- A Search screen in the admin finds tasks, posts, social posts, journal entries, commits, projects, work entries,
  people, messages and webmentions by their words, with a kind filter and paging. Typing in the command palette shows
  results by kind, with a See all results row. The API and the `search` MCP tool search the same way, and the tool
  names the read tool for each kind of result.
- The tasks, posts, journal and activity screens can save their filters as a named view, and the command palette has
  a Saved views group. The API and MCP list, create, change, delete and read saved views.
- An Inbox screen gathers unread messages, pending webmentions and synced issues not yet seen, with actions in place.
  One Inbox count in the nav replaces the Messages and Webmentions counts. The API and the `list_inbox` and
  `mark_task_seen` MCP tools read it and clear an issue.
- Tick rows on the tasks, posts, messages and webmentions lists to act on many at once. Tasks can be completed,
  canceled, deleted, moved, tagged and untagged, drafts deleted and posts tagged, messages marked read or unread and
  deleted, and webmentions approved, marked spam or ignored. The API and MCP have the same bulk actions.
- A Review screen shows a week or a month: work done, tasks carried, decisions resolved and dropped, and a note for
  the period. The API and the `read_review` and `save_review_note` MCP tools read the review and save its note.
- A Needs attention card on Today lists stalled work, with move, cancel, open, write and snooze actions. The API and
  the `list_attention` and `snooze_attention` MCP tools read and snooze it.
- A Calendar screen shows sprints, posts, social posts and journal days on a month grid, with a day panel, and as a
  list of days on a phone. Drag a scheduled post, social post or sprint task to another day, or move it from the day
  panel, though not to a time already past. The API and `list_calendar` read it.
- Keys in the admin: j and k move through a list, Enter opens the row and ? lists every key. On a task row x, s, m
  and e act on the row, p publishes a draft post, r marks a message read, g jumps to a section and c creates a record.
- The command palette can start, pause and complete a task, create a decision, start a post, a social post or
  today's journal entry, and log work.
- A task tag rules screen in the admin sets the tags for each repo, and issues the sync imports from GitHub or Linear
  get them. The API and MCP list, save and delete the rules.
- Each post has an analytics page with read-throughs, unique readers, outbound clicks and its first 30 days drawn
  against the median post. The posts list shows unique readers. The analytics dashboard gains an hour by weekday grid
  and feed subscriber cards, which count Atom feed fetches from known aggregators.
- A privacy page at `/privacy`, linked from the footer, says what the site records and how long it keeps it.
- The database dumps to a backups bucket at 00:30 Chicago time each night, keeping the 7 newest dumps. The
  `BACKUP_STORE_*` settings name the bucket, and a failed dump shows on Today.
- `mise run release:next` prints the next CalVer version.
- New MCP tools, each with an API route that answers the same JSON: `read_commit`, `read_project`,
  `read_work_entry`, `read_webmention`, `read_social_post` for a social post in any status, `list_people`,
  `read_person`, `save_person`, `delete_person`, `search_accounts`, `edit_task_comment`, `delete_task_comment`,
  `update_post_edit_note`, `sync_issues` and `upload_photo`. `read_post` returns the whole post through the API.
- `list_tasks` filters by list, tag and text, and `list_webmentions` by post. `read_activity` and
  `summarize_activity` run through API routes, and each activity row carries the ID of its record.
- `read_analytics` adds feed subscribers, webmentions and the change in views to the site answer, and bounces,
  outbound clicks, the first 30 days and unique readers to a page.
- Task answers in the API and MCP carry `updated_at` and the synced issue they came from, task comments carry
  `updated_at`, and journal entries carry `created_at` and `updated_at`.

### Changed

- Deleting a tag takes it off every record that has it, where it used to refuse while the tag was in use. A tag that
  is the last one on a task tag rule still can't be deleted.
- `REDIS_RECONNECT_ATTEMPTS` takes a list of waits in seconds, such as `0.5,1,2,4`.
- A tag's Atom feed redirects to its own path, and the feed's Last-Modified moves forward when a tag changes.
- A remote image in Markdown imported from GitHub or Linear shows as a link rather than loading.
- Cloudflare may keep a published photo for one day.
- `list_webmentions` gives `received_at` in UTC and always carries `spam_reason`, as `null` when there is none.
- The MCP server's opening text names every kind of record it can read, and its title names the whole site.
- `/mcp` and `/api/v1/photos` take a body up to about 33 MB, so a photo can upload through MCP.

### Fixed

- Completing, pausing or scheduling a task that is already closed is refused.
- MCP `update_post` keeps a scheduled post scheduled when it gets a blank or past `publish_at`.
- MCP `publish_post` runs the same checks as publishing in the admin.
- A post announcement check expands mention tokens and refuses a mention of someone not in the people list.
- API paging and ID fields refuse values out of range, and a bad ID list gets one plain error.
- Two sprint roll-overs that start at once no longer both carry the same tasks.
- A social post edited or moved after it was queued no longer goes out at its old time.
- Saving a post again keeps its publish time when that time falls in the repeated hour at the end of daylight time.
- A spam reason made only of Unicode spaces saves no reason.
- The commit backfill floors on the push date, so a commit pushed late with an older date no longer gets skipped.
- A database password with no user name now connects.
- Sidekiq's scheduler no longer reports each Redis connection notice as an error during an outage.
- Accepting suggestion edits that would leave a social post part empty is refused in the admin and through MCP,
  where it used to answer 500.
- The palette search box shows a focus ring and is 44px tall.
- Blue pills, such as Scheduled, and the checked Bluesky chip pass contrast in light mode.

### Security

- MCP tool results mark text someone other than the owner may have written, such as message bodies, webmention
  authors and excerpts, and synced task notes and comments, as `{ untrusted: true, text }`. Each tool that returns
  such text warns the agent to treat it as data.
- The app refuses to boot outside development and test while it holds the secrets committed to the repo.
- The app sends Strict-Transport-Security for one year in production.
- A webmention approves itself only when its source page sits under the author's URL, or on a host set as single
  author.
- Public throttles count an IPv6 visitor by their /64, and client registration has a cap across the whole site.
- The webmention client refuses every special-use IPv6 range.
- The request log and Honeybadger leave out notes, people fields and visitor addresses.
- A photo serves only while a record claims it.
- The MCP consent page leads with the host it sends you back to.

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

[Unreleased]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.4...HEAD
[26.10.4]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.3...26.10.4
[26.10.3]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.2...26.10.3
[26.10.2]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.1...26.10.2
[26.10.1]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.0...26.10.1
[26.10.0]: https://github.com/aaronmallen/aaronmallen.me/compare/26.9.4...26.10.0
[26.9.4]: https://github.com/aaronmallen/aaronmallen.me/compare/26.9.3...26.9.4
[26.9.3]: https://github.com/aaronmallen/aaronmallen.me/compare/26.9.2...26.9.3
[26.9.2]: https://github.com/aaronmallen/aaronmallen.me/compare/26.9.1...26.9.2
[26.9.1]: https://github.com/aaronmallen/aaronmallen.me/compare/26.9.0...26.9.1
[26.9.0]: https://github.com/aaronmallen/aaronmallen.me/releases/tag/26.9.0
