# Changelog

This file records each notable change to the site. It follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [CalVer](https://calver.org) as `YY.M.MICRO`, dated by the UTC day of the tag.

## [Unreleased]

### Added

- A `mermaid` code fence draws a diagram in artifacts, decisions, comments, notes and task notes, in the admin and on
  public task pages. Before, these showed the diagram's source.

## [26.10.35] - 2026-10-27

### Added

- A `mermaid` code fence draws a diagram on post and journal pages and in the admin preview, and redraws it when the
  site switches between light and dark mode. Pages with no diagram load no mermaid code. Feeds show the diagram's
  source as a code block.
- A daily job at 03:45 rebuilds the stored HTML of every journal entry, as one at 03:30 does for posts, so entries
  written before a change to the markdown pick it up with no edit.

### Changed

- Code blocks on posts, journal entries and the admin preview number each line. Copying a block leaves the numbers
  out.
- Code blocks lose their orange left border and keep the grey box.

## [26.10.34] - 2026-10-26

### Changed

- `read_memory_file` leaves out a file's change history unless you pass `history: true`, in the API and the MCP. The
  API takes it as `?history=true`. `revert_memory_event` needs an entry ID from that history.
- `start_task`, `pause_task`, `complete_task` and `save_task` reply with the task's ID, label and status and the fields
  the call changed, not the whole task. `read_task` gives the full record.

### Fixed

- A Gmail sync that Google rate limits partway through keeps the threads it stored and moves past them. Before, the
  account fetched the same threads on every run and failed each time.

## [26.10.33] - 2026-10-24

### Added

- Each project has tags of its own. A Tags button on the project page adds, renames, describes, colours and removes
  them, and `list_tags`, `create_tag`, `save_tag`, `update_tag` and `remove_tag` take `scope: "project"` in the API and
  the MCP. Project tags stay out of the global tag list and its picker.
- A page for each project tag at `/projects/:key/tags/:name` lists every record that holds it, grouped by kind as
  `/tags/:name` is. `read_tag` takes a `project` key to read one.
- A record that belongs to a project takes that project's tags. Tasks and task rules use their own project, agent
  sessions and project memory files use theirs, and decisions, notes, journal entries, mail threads, posts and
  artifacts use the projects they link to, tagged in each of them. Posts keep their public tags beside a new project
  tags field.
- MCP tools `tag_session`, `untag_session`, `tag_memory_file` and `untag_memory_file`, and a tags field in the admin
  session drawer and on memory file pages.
- Labels on GitHub and Linear issues become project tags on the task they sync into, made in its project when missing,
  at import and on every later sync. A label removed upstream leaves the tag in place.
- A filter bar on the admin project board takes GitHub style terms: `label:a,b` or `l:`, `-label:a`, `no:label`,
  `is:open`, `is:closed`, `is:doing`, `is:blocked`, `column:` or `col:`, and free text for a title or task number. It
  suggests terms and tags as you type, counts the matches, lists the terms it ignored and keeps the query in the URL.
  `list_tasks` takes the same query in the API and the MCP and returns the terms it ignored.
- A published board shows its project's tags on each card and has the same filter bar. Clicking a tag adds `label:` to
  the filter. An unpublished board's tags never reach a public page.

### Changed

- Every private tag on a record that belongs to a project moves into that project's tags, with a copy in each project
  when a record belongs to several. Task rules that file into a project move their tags with them, and a private tag
  left holding nothing is deleted.
- Moving a task to another project carries its tags over by name, made there with the same colour and description when
  missing. A task that leaves every project keeps them as private tags, and removing a record's last link to a project
  drops that project's tags from it.
- The site runs on Ruby 4.0.8.
- `mise run test` runs a black-box suite of Gherkin features in `features/`, which drives a real server, Sidekiq,
  Postgres and Redis for each worker. `mise run lint` gains checks for field error wording, the Sidekiq schedule, the
  GraphQL queries, API wording, API and MCP reach, and untrusted text. `mise run deps:schemas` fetches the GraphQL
  schemas.

### Removed

- The RSpec suite and its `test:ruby`, `test:browser`, `test:coverage` and `test:profile` tasks.

### Fixed

- On a phone, the admin wordmark's name now starts with the initials it shows, so speech input can follow it.
- An empty public project board's scroller takes keyboard focus and shows a ring, as the admin board does.

## [26.10.32] - 2026-10-23

### Added

- Notes in the admin, under Journal: a folder tree, Markdown notes with tags, an editor that saves as you type and
  refuses a save when the note changed elsewhere, and a page for each folder with its description, subfolders and
  notes. Clicking a folder's name in the tree opens its page, and its chevron folds it.
- `[[Title]]` and `[[Title|text]]` links between notes. A note lists its backlinks and links out, the notes home lists
  titles linked but not written yet, renaming a note rewrites the links to it in every other note, and deleting one
  says how many notes link to it.
- Notes and folders join record links, and a folder's links show on every note inside it under "From folders". Admin
  search and the palette find notes, and the notes sidebar has a search that takes `#tag`. Public search never returns
  a note.
- A `notes` scope for MCP clients, which `read` and `write` do not cover, with tools to list, read, search, create,
  edit, rename, move, pin, tag, duplicate and delete notes and to list, create, rename, move, describe and remove
  folders. Deleting a note or removing a folder also needs `delete`. A note an agent wrote comes back marked untrusted.
- Contacts in the Inbox group. People hold every Google Contacts field, and a contact page shows them with the
  contact's last six mail threads. People left settings, and `/people` links go to Contacts.
- Contacts sync both ways with Google. Each Google connection can turn on "Sync contacts", and one takes new contacts.
  An hourly pull brings contacts, labels and stars, and saves, edits and deletes here reach Google. When Google changed
  a contact first, the editor loads Google's version and asks you to redo the edit. The first sync links existing
  people by email, profile link or exact name. Handles go to Google as profile links and are never read back.
- Mail matches a sender to a contact by email, compose suggests contacts' addresses, and a sender who is not a contact
  gets an "Add to Contacts" button.
- A `contacts` scope for MCP clients. Without it a token sees only a contact's name, key and handles and cannot write
  any other field. The people tools take every contact field, `list_people` filters as the Contacts tab does, and
  `sync_people` runs a sync.
- A Calendar card on Today lists today's events, marks the one running now and counts down to the next.
- MCP tools to create, edit, move and delete calendar events, save and edit mail drafts, list, create and edit short
  links, delete shares and share groups, remove one file from a share group, run the short link and post link checks,
  and turn a mail thread into a task. `update_share` also sets alt text and changes a share's code. No MCP tool sends
  mail.
- The security tab lists each browser as one device, and a button signs out that device alone. A sign-in from a device
  the site knows raises no new-device alert.
- `mise run db:seed` fills every admin screen, notes, contacts and devices among them, and a second run adds nothing.

### Changed

- The settings tabs read tagging, webmentions, connected services, jobs and security, and `/settings` opens tagging.
  Webmention settings have their own tab, and `/settings/socials` links land there.
- Row facts that are not a state, such as an artifact's type, a post's failing links, mentions and suggestions, and the
  stale and over limit marks, show as coloured text, not pills. Note tags show as `#word` in the tag's colour.
- The security tab counts failed sign-ins from the last 7 days and lists only those, each with a button to dismiss it.
- The connected clients card counts MCP clients that called in the last hour, shows registrations with the same name
  and redirect host as one group, and lists the rest as "authorized, idle".
- An MCP sighting takes its title from the client, such as `claude-code 1.2`, and one client calling from two cities
  shows as one row with its last city.
- A repeat sign-in callback from a device that signed in under a minute ago goes to the admin and records no failed
  sign-in.
- Each admin session now carries its device, so every browser has to sign in once more after this release.

### Fixed

- The board and list switch on an admin project showed no icons.

## [26.10.31] - 2026-10-22

### Changed

- `read_memory` and `search_memory` only look a repo up. A repo no project holds no longer gets a new project from
  them; they return the global and task files or facts instead. Only `start_session` creates a project.

### Fixed

- On a phone, groups in the nav switcher sat below blank space left by a taller group beside them, and 26.10.30 spread
  "today" across the whole menu to hide it. The switcher now has a left and a right column that each stack their own
  groups with an even gap, "today" is as wide as the rows under it, and Tab moves down the left column, then the right.

## [26.10.30] - 2026-10-22

### Added

- Each agent session records the project it worked in. `list_sessions` and its endpoint filter by project, the admin
  session row and drawer show the project beside the repo and branch, and the sessions list has a project select.
  Sessions from before this release whose repo matches a project get that project.

### Changed

- Agent memory and sessions attach to projects. `start_session`, `read_memory` and `search_memory` take a project key,
  and an unknown key returns an error. A `repo` only finds the project that holds it, and a repo no project holds gets
  a new private project, named after the repo, with a GitHub task rule.

### Removed

- The `repo` memory scope. Each repo file moves onto the project whose repo matches it, and the rest are gone.
  `create_memory_file` and `move_memory_file` refuse a `repo` scope, memory files no longer return `repo`, and the
  admin memories page drops its repo pill and lists projects under "Working in".

### Fixed

- Typing "activity" in the command palette and pressing Enter opened a matching record rather than the Activity
  screen. Records now sit below the section groups.
- On a phone, the journal composer and quick-write modal squeezed the tag field into a sliver. It now takes a line of
  its own.
- On a phone, the nav switcher left a blank space under "today". The groups now pack under it.
- The session drawer's "Files read" rows ran the time into the scope, and memory descriptions in the drawer were cut
  off. The time takes the small type with a gap after it, and descriptions wrap.

## [26.10.29] - 2026-10-21

### Added

- The admin session drawer shows what an agent got from memory: "Index it started with" lists each line
  `start_session` returned, "Searches" lists each `search_memory` call with its filters and every fact it found, and
  "Files read" lists each `read_memory_file` call with its time. Each keeps the text the agent saw after a fact
  changes or a file goes, and a deleted file reads "a deleted file". Session rows count files read and searches.
- Project boards in the admin and on the public site have a list view beside the board, with a board | list toggle.
  `?view=list` or `?view=board` picks one, the browser remembers your choice, and a phone gets the list until you pick.
  The public board also shows a bar with its open and total counts.
- The Agents section of the Today card lists up to three artifacts agents wrote today.
- The Memories, Artifacts and Sessions tabs show their counts.
- The admin memory file page edits the file's description in place. A change from there or from
  `describe_memory_file` shows in the file's history, and you can revert it.

### Changed

- Short codes on aa.cool. A new file, share group or short link takes its row's ID in base 36 as its code, and a typed
  code is kept as typed, with no 8 character minimum. A path opens a record only when it matches the whole code, so a
  shortened link sent since 26.10.26 now answers 404. The admin, the API, MCP tools and sent social posts show each
  record's full code.
- `read_memory_file` and `search_memory` answer on an ended session and record nothing for it. Writes still refuse
  one.
- The memories list, the memory file page, the artifact screens and the sessions list and drawer follow the new admin
  design. Artifacts show their type as a coloured pill with an icon, and their tags in the colour of the tag with the
  same name. Each memory screen marks a fact or description an agent wrote, and the three screens carry the title
  "Agents".

### Removed

- The memory file page's "as loaded" view, and the admin's talk of files that "load". A new session's drawer shows
  "Files read" in place of "Memory it read", which stays for sessions from before this release.

## [26.10.28] - 2026-10-20

### Changed

- Every memory file has a description, and a memory file can no longer exist without one.

## [26.10.27] - 2026-10-20

### Added

- A `search_memory` MCP tool and `GET /api/v1/memory/search` find live memory facts by their text, filtered by repo,
  project, task and scope. Each fact comes with its file's ID and path.
- Memory files carry a one-line description. `create_memory_file`, its endpoint and the admin's new memory file form
  require one, `describe_memory_file` and `POST /api/v1/memory_files/{id}/describe` set or change it, and the admin
  memory file page shows it.

### Changed

- `start_session` and `read_memory` return an index of the memory files in scope, one entry per file with its ID,
  path, scope, description and count of live facts, in place of every fact. Agents read a file with
  `read_memory_file` and find facts with `search_memory`.
- A session records the memory files its agent read. `read_memory_file` and `search_memory` take a `session_id` and
  record the file read or each file a search hit. `start_session` records none, and the admin session drawer lists
  them under "Memory it read".

## [26.10.26] - 2026-10-19

### Changed

- Short codes on aa.cool. Each new file, share group and short link gets an 8 character code, and the share host opens
  a record from any start of its code: a path that matches a whole code opens that record, and any other path opens the
  oldest record whose code starts with it. The admin, the API, MCP tools and sent social posts show each record at the
  shortest path that opens it, and the social post counter counts a new link as 8 characters. A typed code shorter than
  8 gains random characters at its end. Every code shorter than 8 gains them too, so old links keep working. When you
  delete a record, its short paths open the next oldest record that starts with them.
- `add_memory_fact`, `edit_memory_fact`, their API endpoints and the admin take fact text of any length, in place of
  1,000 characters at most.

## [26.10.25] - 2026-10-18

### Fixed

- Each issue the sync brought in from GitHub or Linear used up a number among tasks with no project before it moved
  into its rule's project, so those tasks skipped from 35 to 472 in three days. A synced issue now takes one number,
  in its project, and the tasks with no project count up from 1 again with no gaps, in the order they had. Links
  between tasks show the new numbers.

## [26.10.24] - 2026-10-18

### Changed

- Admin controls whose screen reader name left out the text they show now start with it, so voice control finds them
  by what you see: the top bar's search button reads "Find or do anything ⌘K", the editor's heading button "H2
  heading", the review screen's links "Posts 2, open all", and its activity grid's days their full date.

### Fixed

- `start_session` and `read_memory` sent every loaded fact twice, so a repo with a lot of memory overran an agent's tool
  reply and the session could not start. Each fact now comes once, in the markdown, which names each file's and each
  fact's ID; `files` lists each file without its facts.

## [26.10.23] - 2026-10-18

### Added

- Agent memory. Agents keep Markdown memory files of typed facts, scoped to every session, a repo, a project or a task,
  and each change lands in a history that names the agent and model and offers a revert. The MCP tools `read_memory`,
  `read_memory_file`, `create_memory_file`, `move_memory_file`, `add_memory_fact`, `edit_memory_fact`,
  `remove_memory_fact`, `revert_memory_event` and `delete_memory_file`, and their API endpoints, need a new `agents`
  scope that `read` does not cover. `delete_memory_file` needs `delete` too. `read_memory_file` pages the history. Each
  write must name its agent and model, and agent text comes back marked untrusted.
- Agent artifacts: titled, typed and tagged documents where each body change adds a numbered version. `list_artifacts`,
  `create_artifact`, `read_artifact`, `update_artifact`, `restore_artifact_version` and `delete_artifact` need `agents`,
  and the last needs `delete` too.
- Agent sessions. `start_session` opens one and returns the memory its repo loads, `end_session` closes it and
  `list_sessions` reads them back. Memory and artifact writes take a `session_id`. A job runs every 15 minutes and
  closes sessions idle for 2 hours. Set `HONEYBADGER_CHECK_IN_CLOSE_IDLE_SESSIONS` to watch it.
- An Agents pill in the admin, with Memories, Artifacts and Sessions. Memories lists files by scope, shows what a
  session in a repo loads, and adds, edits, removes and reverts facts, moves a file and links records. Artifacts lists
  and searches them, edits in a two pane editor and restores old versions, and the palette gains New artifact. Sessions
  lists each day's sessions, with a drawer of the tasks, memory and artifacts each one touched. Today gains an Agents
  card, and record links take memory files and artifacts.
- Settings has tabs: Socials holds people and webmention settings, Tagging holds tags and task rules, Connected services
  holds services, API tokens and MCP clients, then Security and Jobs. `/settings` opens Socials, each old page redirects
  to its section, and the avatar menu holds one Settings item in place of a link per screen.
- The Jobs tab shows Sidekiq: a health card with seven days of processed and failed jobs, by UTC day, what each worker
  runs now, each queue with a drawer of its jobs, and the retry, dead and scheduled sets with a drawer for each job. A
  set's jobs run, retry, kill, delete or discard from a row menu, a "..." button or the drawer. A cron section lists
  each scheduled job with when it runs and how its last run went, error included, and filters to failed or paused ones.
  Run now, Pause and Enable act on each, and a pause holds across restarts. The tab label counts retries, dead jobs and
  failed cron entries.
- Activate maintenance mode, a button on Settings and a palette command, writes the flag file and sets a signed owner
  cookie. With that cookie the maintenance page offers Deactivate maintenance mode, which removes the flag. Everyone
  else sees the page as before.
- Bluesky posts with no photos carry a link card for their first link, with the page's title, description and image.
- Image shares store a copy no wider or taller than 1280px on upload, and pages show it in place of the original, so a
  group page with many images no longer answers 503s. Run `BackfillPreviews` on the Pi, as `docs/shares.md` says, for
  images stored before.
- The social queue and the activity feed show each part's photos, and the API and MCP `read_social_post` return them as
  `photos`.
- `mise run release --dry-run` lists each variable `.env.example` gained since the last tag.

### Changed

- Below 860px the admin top bar folds its pills into one switcher button that opens a panel of every screen, and at
  480px and 400px it tightens again, down to an "A/A" wordmark. Inbox moves second in the pills, the switcher and the
  palette.
- MCP `read_tag` pages each kind as the admin tag page does and returns short rows, such as id, title and status. Send a
  kind and a page to read more of one kind, which reports its own `partial` and `next_page`. The read tools give whole
  records.
- The API keeps each element of a tag array whole and refuses an element holding a comma rather than split it into two
  tags. API checkbox fields take JSON `true`.
- The deploy migration rewrites `\r\n` and lone `\r` line breaks in stored post bodies, social post parts and suggested
  edits to `\n`, and saves store `\n` alone from now on. A suggested edit can now span a line break in a post written in
  the admin.
- A query from a web request stops after 15 seconds and the request answers 500. `WEB_STATEMENT_TIMEOUT` sets the limit.
  Jobs, migrations and backups run without one.
- Today's attention card shows the worst five rows of each kind and a line that counts and links to the rest.
  `list_attention` and the API return `attention_counts`.
- Post link checks fetch each URL once a run, however many posts link it, and read only the status, so a large or slow
  page no longer times out. The run's counts count distinct URLs.
- Admin actions, API endpoints and search report unexpected failures to Honeybadger, where before they answered a bare
  500 or refusal and left no trace.
- API refusals for share uploads and renames name what is wrong with a filename or content type, and a post refusal
  lists every rule a field breaks.
- `mise run release` refuses to tag when a compare link is missing, or when a spec names a migration a tag has shipped.
- `mise run db:check` and `mise run db:rebuild` load the schema from the newest tag and run only the migrations after
  it.
- Entering the project no longer starts the pitchfork daemons, and leaving it no longer stops them. `mise run dev` and
  `mise run dev:stop` do.

### Removed

- The dead jobs page at `/admin/attention/dead-jobs`. The attention card's Dead jobs line opens the dead set on the Jobs
  tab, and the card's rows use that tab's menu, Copy error included.

### Fixed

- Bulk mail actions and bulk delete held a database connection while Gmail answered, which could stall mail sync.
- Two Gmail, calendar or health syncs could run at once, and a slow Gmail catch up sent the next run after the same
  threads.
- A Gmail body past about 1 MB, or an attachment name holding NUL, stopped mail sync for that account and every later
  one, on every run. Bodies now stop at 100,000 characters, and a thread that still fails goes to Honeybadger while sync
  moves on.
- A reply draft left in Gmail could become the message a sent reply answered, and the thread's preview.
- A failed mail draft save kept showing the last saved time. The hint now says the draft is not saved.
- Gmail settings syncs, Google token renewals and calendar runs made every open admin tab refetch.
- Reads, scrolls and clicks that came in after the 01:00 rollup never reached the admin totals. Each run now rebuilds
  the day before yesterday too.
- A cadence set on a past copy of a recurring task made a second series and a second open copy. The site now refuses it
  as moved.
- A live refresh after the session ended failed without a word and left stale data. The page now reloads to sign-in, and
  other failures show a toast.
- A failed person dialog in the social composer went to the new person page and lost the post. It now shows a toast and
  keeps the text.
- A live refresh wiped a people finder search.
- REST share uploads stopped at about 768 KB, where MCP took 25 MB.
- Short links took no title from a page served as `TEXT/HTML`, and control characters in a title came through.
- The privacy page was missing from the sitemap and its views went uncounted.
- The share group editor's file name link stood 23px tall on a phone.
- The `drop_sprint` description said every task goes back to Next. Synced tasks go to External.

### Security

- A fake Authorization header made the app parse up to 33 MB on `/api/v1/photos` before it answered 401. Only a live
  token raises the cap now, and `POST /pulse` refuses a body over 8 KB.
- `capture_task` with a lowercase or padded project key, such as `pod`, skipped the publish check and put the task on a
  public board.
- Adding or editing a person whose key a scheduled social post mentions needs `publish`, since it changes who the
  mention names.
- Suggested edit text and `read_analytics` sources come back marked untrusted.
- Failed sign-ins write at most 10 rows an hour per sender, which `SIGN_IN_THROTTLE_LIMIT` and
  `SIGN_IN_THROTTLE_WINDOW_MINUTES` change. Successful sign-ins always record, and the Security tab pages the list.

## [26.10.22] - 2026-10-17

### Fixed

- A Linear issue with more than ten sub-issues or relations synced none of its relations, so sub-issues not assigned to
  you never came in. Its relations now load in full, up to 250 of each.
- A live refresh that started before a Today pool switch could land after it and put the old pool back.

## [26.10.21] - 2026-10-17

### Added

- Maintenance mode. While the file `MAINTENANCE_FLAG_PATH` names exists, the site and the share host answer every
  request with a 503 page, or a JSON body for the API and MCP, and never touch the database. Scheduled jobs skip their
  run, other jobs wait and come back every five minutes, and Honeybadger stays quiet. Removing the file ends it with no
  restart. `docs/maintenance.md` holds the Pi script and the NAS steps.
- Likes and reposts approve on receipt, Bridgy ones too, through two new webmention settings that start on. Turned off,
  they fall back to the known-author rule.
- A trusted authors list. Approving a reply or mention adds its author, and marking a webmention as spam takes them
  off. The webmention settings screen lists them with a remove button, as do `GET /api/v1/trusted_authors`,
  `POST /api/v1/trusted_authors/remove` and the MCP tools `list_trusted_authors` and `remove_trusted_author`, which
  need `delete`. The list starts empty.
- Tag fields in the admin draw chips with suggestions in each tag's color: the post, project, task, journal, decision
  and task rule forms. The new tag box in a row's context menu suggests matching tags too. With scripts off, each
  stays the comma field it was.
- Tasks turn up by their label, as `23`, `#23`, `POD-23` or `pod-23`, in the link finder, the record picker, the Tasks
  search, global search, the palette and MCP `search`, with label matches first. Search hits show the task's label.
- Tags take a Markdown description. The admin rename form, the API and MCP `save_tag` set it, `list_tags` and
  `read_tag` return it, and the public tag page shows it under the heading and uses it for its description.
- The new task form and the create dialog take a project, and so does `capture_task` in the API and MCP. A live
  project's board gets a Create task button.
- An Add work form under Time worked on the task drawer and edit page adds a closed work session. `POST
  /api/v1/tasks/{id}/sessions` and the MCP tool `add_work_session` do the same.
- Task rows and board cards show "blocked by N" and "blocking N", each with the related titles in its tooltip.
- A dead jobs page at `/admin/attention/dead-jobs` lists every dead job. Today's attention card shows the newest five
  and a Dead jobs line that counts the rest, and `list_attention` returns `dead_job_count`.
- The sitemap lists published project boards.
- `mise run deps:audit` checks the gems and node packages for known advisories. The weekly outdated workflow runs it.

### Changed

- Giving a project a repo saves a GitHub task rule for that repo and project, and issues reach a project only through
  a rule. A migration adds a rule for every project with a repo that no rule names.
- A new project with a repo fetches its stars and releases at once, not at the 02:00 run.
- The admin tag page shows ten rows of each kind, with a link that pages through that kind alone.
- Complete on a task with tracked time closes it at once, without asking for the time.
- MCP task lists and `read_tag` leave each task's note out. `read_task` and `save_task` still return it.
- `read_analytics` and `search_accounts` mark the text strangers wrote as untrusted, as the other MCP tools do.
- `delete_mail_threads` moves threads to the Trash in Gmail and on the site, where the owner can restore them. Delete
  forever stays in the admin alone.
- The Performance screen reads the daily rollups and weighs each day's p50 and p95 by request counts, as
  `read_performance` does.
- Short link titles and health backfills that Redis refuses wait in Postgres and go out once Redis answers. Set up
  the `HONEYBADGER_CHECK_IN_QUEUE_HELD_TITLE_FETCHES` and `HONEYBADGER_CHECK_IN_QUEUE_HELD_BACKFILLS` check-ins for a
  run every minute.
- Sync issues now, Import commits, Check links, Run it now and Check again show a toast when Redis is down, in place of
  a 500. The `sync_issues` and `import_commits` endpoints and tools answer 503.
- Admin Links rows show the host as written, `www.` included.
- The Services page calls the MaxMind job "Country database refresh".
- `WORKTREES_DIR` moves the workspaces for `dev:create-workspace`, `dev:remove-workspace` and `dev:prune-workspaces`
  alike, and each refuses an id that is not a number.

### Fixed

- Turning on cross-posting for a post already published sent nothing, and a publish and a save close together could
  cross-post twice.
- A Mastodon post with a GIF failed with a 422, since the status went out before Mastodon finished the video.
- Bluesky self-replies failed after a reconnect until the worker restarted.
- The first LinkedIn send of a post skipped it when a recent post held the same text.
- Closing a recurring task's copy early dated the next copy on the same day, and the Recurring tab named the wrong day.
- Dropping a sprint left its tasks flagged as carried.
- A task total set below its closed work sessions put a negative day in the time report, the review and health days.
  It now adds nothing.
- Saving an overnight or multi-day calendar event moved its end to the start day, and moving one to daytime hours
  kept it ending the next day.
- Weekly calendar series never gained their instance a year out, and held events older than 90 days never went.
- A calendar create, edit, move or delete answered 500 when Redis was down, though Google held the change.
- A workout deleted in the fitness app stayed in health, and a workout logged late at night far west of Chicago could
  vanish.
- A health backfill stopped at the first 90 days with no data and never fetched older history.
- Mail, health and calendar sync failed for every account when one Google connection was revoked, and compose offered
  it as a sender.
- Gmail sync stopped when two labels swapped names, and dropped label changes past 100 pages of history.
- Marking as spam a thread whose sender had no valid address raised, after Gmail had already labelled it.
- Bulk snooze to a past time showed "pick an action from the bar".
- An open mail draft refetched the page on each save, and asked Gmail for the drafts list on every live refresh.
- Removing a Linear connection, or a token losing a repo, cancelled every open task that came from it.
- A webmention source that removed its link or went away never withdrew the mention when mentions, receiving or Bridgy
  were off, and a forget could remove one marked spam.
- An empty share group kept its page, zip and code. Failed uploads left files in the bucket.
- The share drawer offered no Markdown for a file that is not an image.
- Photos on tasks and comments on a published board answered 404, and posts that held a sized photo URL such as
  `/media/1280/...` never claimed the photo.
- Photos in decisions were never claimed, so the photo sweep could delete them.
- A note, comment or tag description that opened with `# Heading` put a second h1 on public pages.
- Board and task page views went uncounted, or counted to a post that shared the slug.
- Tag pages that only projects carried were missing from the sitemap.
- A refused tag rename or journal edit dropped the search or page it came from and lost what was typed, and Cancel on
  a journal edit kept dropped tags. Saving or removing the last tag on a page landed on a 404.
- Archiving an archived project wrote a new archive day over the old one.
- A post title with no letters or digits and a blank slug answered 500.
- A project name that made no slug, or the same slug as another project, saved.
- The Services page and Attention disagreed about a connection lapsing late on the window's last day.
- Delete posted with no confirm, and record keys copied nothing, after a calendar day click, a calendar drag or a
  Today pool switch. A cadence picked in the task panel showed no fields.
- The calendar drag scrolled the page and opened the context menu on touch.
- E did nothing in the task panel while a checkbox held focus.
- Make task toasts named the task by its row id, not its label.
- The feed subscribers card read 0 for a range of only today.
- Stray dots on the public board stats, the review repos card, the activity feed's workout line and service rows.
- Over REST, `suggest_edits` read every edit as part 1.
- `search_accounts` answered 500 for a network with no credentials, and `list_links` answered an empty list for a
  record that does not exist. Both now answer 503 and 404.
- The API took a bad `sprint_on` day, and kind `message` from a token without mail, without a clear refusal.
- Short link clicks, share downloads and visits counted fediverse preview fetchers and the site's own fetchers.

### Security

- A JSON body could change the record in an API call's path: `PATCH /posts/5` with `{"id": 9}` changed post 9.
- A client with `write` but not `publish` could change public pages through grouping, ungrouping and renaming shares,
  links on published boards, task rules, suggestions, tags, task capture and series. These now need `publish`.
- A `write` client could drop a trusted author with a spam verdict. That now needs `delete`.
- Mail bodies and `bcc` addresses no longer reach the request log or Honeybadger.
- Share and group file names may no longer hold a slash or be `.` or `..`, and zips write each entry name bare.
- Mail HTML loses its class and id attributes and its transforms, and stays inside its own box, so a message can no
  longer lay over the admin. Queue `Mail::Jobs::RecleanMailHtml` once to clean stored mail.
- Links in synced issue text and comments on public task pages carry `rel="nofollow ugc noopener"`.

## [26.10.20] - 2026-10-16

### Added

- A search page at `/search`, linked from the header and opened from any page with `/`. It finds published posts, public
  projects and tasks on published boards by their words or public tags, groups hits by kind and marks the words that
  matched. It never shows a draft or private record, carries noindex, and robots.txt keeps crawlers off it. Each visitor
  gets 20 searches a minute, which `SEARCH_THROTTLE_LIMIT` and `SEARCH_THROTTLE_WINDOW_MINUTES` change, and past that
  the page answers 429.
- A Related block under each post lists up to three other published posts: first those sharing the most tags, then those
  with similar wording.
- Short link destinations get checked each night with post links. Both count any 5xx and a timeout as broken, beside 404
  and 410, and each failing link keeps a reason, such as "404 Not Found", and the night it first failed.
- A "broken" filter on admin Posts lists published posts with failing links and a card of failing short links, each with
  Check again, a link to fix it and Open link. Post rows carry an "N links failing" pill, orange after one night and
  pink after two.
- A "failing" filter on admin Links. Each link shows how its last check went, with Check again in its drawer and on its
  edit page.
- A Links button in the post editor opens a drawer of the post's outbound links, failing ones first, with Find in post,
  Open link and, on a published post, Check again.
- A Broken links line on Today's Needs attention card. When the last link check stopped early, Today and the Posts
  broken filter show a banner with how far it got and Run it now.
- A short link made with no title takes its destination's page title once a job fetches it. A title you type wins.
- Share files take a name, and share groups take one that titles their page and zip. The admin sets them, as do `PATCH
  /api/v1/shares/{id}`, `/api/v1/share_groups/{id}` and `/api/v1/share_groups/{id}/files/{file_id}`, and the MCP tools
  `update_share`, `update_share_group` and `update_share_group_file`.
- The admin files list groups two or more single shares, adds them to a group, and pulls a file out of its group under a
  new code. The API and the MCP tools `group_shares`, `add_shares_to_group` and `ungroup_share_file` do the same with
  `write`. A share that joins a group loses its own link.
- The feed subscribers card lists direct feed readers under the aggregators, and `read_analytics` and the API return
  them as `readers`.

### Changed

- New codes for shares, share groups and short links take 3 characters while any are free, then 4, and so on. Codes made
  before keep their length.
- Single shares and group files live in one table, so single shares have new ids in the API and MCP. Their links still
  work.
- `check_post_links` runs each night at 03:00 Chicago time, in place of Mondays at 06:00, and checks short links too.
  Set its Honeybadger check-in to expect a nightly run.
- The feed subscribers card, `read_analytics` and the API take each aggregator's count from the latest day alone, so the
  rows add up to the total. An aggregator with no count that day drops off.
- Insights loses its Search and Performance tabs. Performance sits on Analytics, and the palette's "See all results"
  still opens search.
- Webmention lists show a like in pink and a reply in sand.
- The admin wordmark matches the public one: pink first, with the same size and focus ring.
- Admin Links rows turn their title pink on hover, and the open icon on Links rows and share cards turns pink too.

### Fixed

- A Linear sync past ten pages of 25 issues failed each run with `page_limit` and never imported the rest. The Linear
  and GitHub issue syncs now read every page.

## [26.10.19] - 2026-10-15

### Added

- LinkedIn joins Mastodon and Bluesky. Once `LINKEDIN_CLIENT_ID` and `LINKEDIN_CLIENT_SECRET` are set, Connected
  services connects a profile, and the footer links it. A thread goes out as one post with a blank line between parts,
  and the composer counts it that way. The first four photos go with it, with their alt text, and a WebP photo goes as a
  JPEG. Likes, replies and reposts come in when the account grants `r_member_postAnalytics`, and with `r_member_social`
  a retry looks for the post among recent ones before it sends again.
- A LinkedIn token lasts about 60 days and can't renew, so Connected services marks the connection "lapses soon" from
  seven days out (`attention.lapsing_days`) and "lapsed" after, and Today's attention list, `list_attention` and the API
  show a row for it. Reconnecting the same profile replaces its token and keeps its deliveries.
- Tasks have a number within their project, and projects have a key of 2 to 6 capitals and digits, made from the name
  when left blank. The admin, toasts and public pages print a task as KEY-n, or a bare number when it has no project. A
  number never comes back once its task goes. Every API route and MCP tool that takes a task takes that label as a
  string or the id as an integer, task replies carry `label`, and links carry `task_label`. `save_project` sets the key,
  and `read_project` and `list_projects` show it.
- Tasks repeat. The task form, its create dialog and the edit drawer have a Repeats picker: every N days, every N weeks
  on a weekday, a day of the month, the last day of the month, the Nth weekday of the month or a date each year. Closing
  the current copy makes the next one, with its title, note, tags and project, in the sprint for its next date, and the
  timeline marks it. A Recurring tab under Tasks lists each series with its next date and a switch that pauses it.
  `save_task` and `capture_task` take `recur`, every task reply shows it, and `list_task_series`, `pause_task_series`
  and `resume_task_series` reach `/api/v1/task_series`.
- Opening a decision makes a task, "Resolve decision #id: title", at the end of Next. Renaming, resolving, dropping or
  reopening the decision renames, completes, cancels or reopens it. A decision opened before this gets its task the
  first time it reopens.
- Board columns, in the admin and in public, show 20 cards and a Load More that grows the column by 20
  (`board.column_size`), and each head counts every task. A done or canceled task leaves both boards 14 days after it
  closed (`board.closed_days`) and stays everywhere else. A task that changes column goes to the top of its new one.
- The admin board has Select, a box on each card and a bulk bar that moves the picked cards to any column, all or none.
  Cards show how many open tasks they block and how many block them, in place of link chips.
- Each card on a published board links to a public task page at `/projects/:slug/tasks/:number`, with the task's title,
  status, column, close date, notes, comments, related tasks and source issue, but no tags or time. A related task shows
  only when it sits on a published board.
- Share groups. Ticking "Share as one link" on upload puts every file under one code, whose page shows the images in a
  carousel and lists the other files. Each file has its own link at `/<code>/<id>`, and Download all streams them as one
  zip at `/<code>.zip`. Groups show as cards on Files, and a group's drawer changes its code, sets alt text, removes a
  file, deletes the group and shows its views and downloads.
- Shares in the API and MCP: `upload_share`, `upload_share_group`, `list_shares`, `read_share`, `list_share_groups` and
  `read_share_group`, over `/api/v1/shares` and `/api/v1/share_groups`. Uploads take base64 and need `publish`, and
  `list_shares` filters by `query`.
- `SHARE_TRANSFERS` caps the share downloads, range requests and zips each web worker streams at once. Unset, it leaves
  two threads free and never falls under one. Past the cap a transfer gets a 503 with Retry-After, so slow downloads
  can't take every thread from the blog, admin, API and MCP server. Group pages and short links stay outside the cap.
- A Performance tab beside Traffic on Analytics, also under Insights. It charts server time per day and ranks routes and
  jobs by p95 over 7, 14 or 30 days, with browser load and LCP beside each GET route and a link to its 25 slowest
  requests. The site times each request and job, and the reader beacon now sends page load times with only the route and
  device class. Raw rows stay 30 days and a nightly job keeps each day's p50 and p95. `read_performance` and
  `GET /api/v1/performance` read the same figures with `read`.
- Clients with `mail` can link a record to a mail thread through `link_records`, `unlink_records` and the record link
  routes, and only they see a record's mail threads among its links.
- `list_tasks` takes `window_by`. `closed` keeps only the tasks closed inside the window, and the report prompt now uses
  it, so a task made in the range and canceled after it no longer shows as dropped there. `touched` stays the default.
- The mail reader has a Trash button for a Gmail thread outside trash and spam.
- `MAIL_BACKFILL_DAYS` limits the Gmail backfill to the last N days. The backfill skips trash either way.
- `PREVIOUS_DATA_KEY` rotates `DATA_KEY`: credentials sealed under either key open, and `mise run db:reseal` seals each
  one again under the new key, prints how many it changed and fails when any opens under neither.
- `MAXMIND_DATABASE_PATH` sets where the country database lives, `tmp/maxmind/GeoLite2-City.mmdb` by default. The worker
  fetches the file when it boots with MaxMind set up and no file there.
- Each scheduled job sends a Honeybadger check-in when a run finishes, so Honeybadger alerts when a run is late or
  missing. Set `HONEYBADGER_CHECK_IN_<JOB>`, such as `HONEYBADGER_CHECK_IN_SYNC_GMAIL`, for each job to watch. A job
  with none set runs as before.
- `mise run db:restore` loads a dump, from disk or the backups bucket, into a scratch database, checks that migrations,
  posts and tasks hold rows, then drops it.
- More mise tasks: `db:console` opens psql on the database the settings name, `db:explain` prints the plan of a
  statement in a transaction it rolls back, `deps:outdated` lists outdated gems, node packages and tools, `test:schemas`
  fetches the GitHub and Linear schemas the suite checks queries against, and `dev:prune-workspaces` drops test
  databases left by deleted workspaces.
- `mise run lint` fails on a locale key no code reads and on an error page in `public/` that differs from a fresh
  render.

### Changed

- `publish` now covers anything that shows in public, not only what can't be called back. `upload_share`,
  `upload_share_group`, `add_work_entry`, `update_webmention_settings`, `update_post_edit_note` and
  `approve_webmentions` need it outright. Other tools keep `write` but refuse a public target without `publish`: a
  public project, a published or scheduled post, a task on a published board or a link that puts one there, an approving
  `moderate_webmention`, and `sync_issues` while a published board is in its reach. Over the API the refusal is a 403
  `insufficient_scope` naming `publish`. Before you deploy, check that each token and MCP client that edits public work
  holds `publish`.
- Mail stays behind `mail` in more places. Without it, `list_tags` leaves mail out of its counts and drops tags only
  mail carries, `remove_tag` refuses a tag a mail thread carries, `update_tag` refuses a tag only mail threads carry,
  and `list_inbox` leaves mail out before it keeps the newest rows, so tasks and webmentions no longer hide behind a
  full mailbox. Every API reply also drops workout rows without `health` and mail rows without `mail`.
- A task belongs to one project at most. Linking a task to a project moves it there, and unlinking clears it. A task
  rule gives one project, and only to a task with none. The migration keeps one project per task, the one that owns the
  issue's repo and then the oldest link, and keeps the lowest one on a rule that named several. A second migration gives
  every task, once, the project and tags its rules give, and changes nothing set by hand. The time report no longer
  marks a project as sharing time.
- Live updates redraw less. Each admin page names the tables it draws and skips changes to the rest, so new mail no
  longer redraws the board and a new commit no longer redraws the calendar. A hidden tab waits until it shows, changes
  within one second share one refetch, a tab skips the echo of its own save, and writes that touch only `updated_at`,
  counts or sync cursors send no change.
- Task rows lose their check box. Each open row's hover bar offers Complete, started or not, and a closed row's offers
  Reopen.
- A task on a later sprint shows that sprint's date in place of Today, and its Move menu offers Today.
- The time report card shows one hint when its rows add up to more than the total, and row headings lose the shared
  pill.
- A calendar event that fails its checks comes back in its form with the values you typed and an error beside each
  field, in place of a toast.
- Admin ledes, hints and tooltips now match what each screen does, a few that were wrong among them.
- Opening a draft thread shows an Edit draft link, and only that asks Gmail for the draft.
- The Inbox lists the newest 100 rows, and its count still says how many wait.
- The mail folder column is 240px wide, and a long account name in a label group head truncates.
- Linear's own mark replaces the stand-in icon on task source links and the Linear service tile.
- Reconnecting a GitHub or Mastodon account updates the connection it holds, so scheduled deliveries keep pointing at it
  and a revoked mark clears.
- A post that lost a picked network before it sent records a failed delivery for that network, such as "No mastodon
  account is connected", in place of looking fully sent.
- Webmention sends and checks try again when the other side answers 429 or a 5xx, and a check that fails any other way
  stops at once rather than trying six times.
- `sync_issues` answers 503 when neither GitHub nor Linear is set up. An issue sync that stops at the page cap records
  `page_limit`, a failed reap shows on the commits sync, and a crash in any sync job or import shows as a crashed sync
  in place of the last good run.
- API tokens record their last use at most every five minutes, as MCP clients do, and `list_api_tokens` says so.
- Production Puma runs two preloaded workers when `HANAMI_WEB_CONCURRENCY` is unset, and Puma and Sidekiq turn on YJIT.
  Set `MALLOC_ARENA_MAX=2` in the service units, since it has to be set before the process starts.
- Public pages weigh less. They link their own stylesheet, about a quarter of the old size, draw icons as inline SVG
  with no icon font, preload the body and heading fonts, and set the saved theme from a small inline script, so
  Cloudflare can serve the cached page to every reader. Fingerprinted assets send a one year immutable Cache-Control,
  and `/site.webmanifest` caches for five minutes.
- Post photos list 640, 1280 and 1920px copies in a srcset. Photos send an ETag and answer a match with a 304, and a
  signed in request for an unpublished photo caches in your browser for an hour. After you deploy, run the photo width
  backfill in `docs/media-store.md` once, since older photos list no copies until then.
- Posts store their rendered HTML, first paragraph, read time and word count, and a nightly job renders every post again
  so a renderer change reaches old posts.
- Mail search matches through a trigram index in place of reading every message, and a match no longer spans two
  messages of a thread. Before you deploy, allow time for the migration, which builds the index over every stored
  message.
- Today and the Tasks tab load only the picked pool and fetch the other when you pick its tab, the people page fetches
  one edit drawer when you open a person, and the task drawer asks for the task alone, not a whole admin page.
- `mise run release` replaces `release:next` and tags the next version. It tags only when CI passed on that commit,
  unless given `--skip-ci`, and never pushes. It refuses a commit already tagged, entries left under `[Unreleased]` and
  a changelog with no section for the version. `--dry-run` prints the version, the commit and its CI state.
- `mise run test:coverage` fails when line coverage drops below 98.3% or branch coverage below 90.8%.

### Fixed

- An issue sync that failed to start, complete, cancel or reopen a task still marked the issue handled, so it never
  tried again. The run now counts as crashed and the next one retries.
- The Gmail backfill went to the dead set after three failed tries and nothing started it again. It now saves its page
  and resumes when it has stalled for an hour.
- One failing Google account stopped Gmail sync for every account sorted after it.
- Reconnecting one Google account and picking another in Google's chooser wrote the second over the first, and the first
  stopped syncing.
- A mail attachment named only with spaces stopped every Gmail sync at that thread.
- A reply to a trashed thread showed only under Trash, and a draft started in Gmail hid its thread from every folder. A
  thread now counts as trashed, a draft or spam only when every message does. Stored threads keep their flags until
  Gmail reports a change.
- The plain body of an HTML-only message kept entities such as `&amp;`, which reached the preview, the API and search.
  Stored messages keep the old body until they sync again.
- The calendar sync deleted every calendar and event when Google was not set up.
- Archiving or starring on a later page of Mail sent you back to page 1.
- A live update reset the mail editor to a bare textarea, showed Add on an empty comment box, undid the Cc, Bcc and
  people finder reveals, hid the bulk Select button and cleared the theme picker's mark. It also reset boxes a script
  ticked, such as Select all and the restored social picks, so a post went to one network or a bulk action hit one row.
- When an admin script failed to start, the task and mail lists stuck in select mode with no way out. Each setup step
  now runs on its own.
- A live update that landed mid-save put a dragged task, event or mail row back, and an upload or new short link wiped
  text typed in an open drawer.
- Two quick submits of Make a task on a mail thread made two tasks.
- Two deletes of one work session at once both took its time off the task, and an edit racing a stop could write a
  running session over a closed one.
- `save_task` with list `today` left a task on a later sprint where it was.
- A bulk action on Today dropped the pull column's pool.
- A saved view from the Completed tab lost its date range.
- Alt+Up and Alt+Down in a work session's hour or minute field moved the row.
- Starting a work session moved a task's manual time to today on the time report.
- A stale tab could make sign-in open the live event stream as a blank page.
- Accepting a suggestion for one part of a social post failed when another part already ran over its limit.
- A social post that sent while a suggestion saved kept that suggestion pending.
- A delivery that gave up after five retries could keep no error.
- Two first connects to one Mastodon server at once answered a 500.
- A malformed Google token or profile reply answered a 500 when connecting Google.
- A request from an API token or MCP client deleted mid-request answered a 500 in place of a 401.
- A share whose file had gone from the store hung the download. It now answers 404.
- A failed photo upload left the copies it had already stored in the bucket.
- Atom feed pages after the first kept their Last-Modified when a new post pushed entries down, so a reader got a 304
  for a page that had changed. Sending a post's webmentions also moved its updated date in the feed and the sitemap.
- Open draft pull requests took the import day as their date. They now take the time GitHub opened them.
- Commits from a repo with capitals in its name credited no agent.
- The commit backfill could miss commits when more than 100 on one branch shared a second.
- Unlinking a record of an unknown kind answered a 500 in place of not found.
- Admin analytics left days not yet rolled up out of the prior range, and a post's readers counted the month so far, not
  the range picked.
- The post schema said `webmentions_enabled` decides whether a post sends webmentions. It only decides whether the post
  accepts them.
- An MCP client with no name showed under different labels on Clients, its menu, Security and the health card.
- 33 admin form errors showed no message.
- A run of part of the suite overwrote the test runtime log, so the next full `mise run test` split its workers
  unevenly.

### Security

- Admin sign-in uses PKCE, and its state expires after ten minutes. The site refuses a sign-in begun before you
  deploy, so start it again.
- Share and share group links get 16-letter codes, too long to guess. Short links keep five letters, and codes already
  handed out keep working. A share upload refuses a content type that isn't one plain type, and every share file and zip
  goes out with a content security policy that sandboxes it.
- The share host and `/pulse` read the host from the Host header alone, so a forwarded header can no longer choose which
  app answers.
- Connecting Mastodon refuses a server that resolves to a private or local address, and the Mastodon clients no longer
  follow redirects.
- A request with no token can no longer make the server read a large body. `/api/v1/photos` and `/mcp` hold it to 1 MB,
  and the server reads a body sent with no length in chunks and refuses it once it passes its route's limit.
- Mail HTML can no longer set `position` or `z-index`, which let a sender lay a panel over the admin. Stored mail keeps
  its old HTML until the `RecleanMailHtml` job fetches and cleans it again, so queue it once after you deploy.
- `update_post` refuses a scheduled post whose time has passed unless the call gives a new one, so a client without
  `publish` can't send an overdue post live.
- More text that others write reaches MCP marked `{ untrusted: true, text }`: commit messages, calendar event titles,
  places, notes and guests, the error text in dead jobs, deliveries and sync failures, and the paths, hosts and click
  fields in `read_analytics`. The REST API still answers plain text.

## [26.10.18] - 2026-10-13

### Added

- The admin sign-in page has a GitHub button and a Google button. Google sign-in uses the OAuth client that already
  connects Google accounts, asks only for `openid email` and keeps no token.
- Each project has a board in the admin, opened from the project list, with backlog, ready, in progress, done and
  canceled columns. A card moves by its arrows, by the Board column item in its task menu, or by drag, with a mouse
  or after a short hold on a touch screen. Moving a card starts, completes, cancels or reopens its task, and moving
  between backlog and ready sets only its stage.
- Tasks carry a stage, backlog or ready, which every API and MCP task read shows. The `stage_task` MCP tool and
  `POST /api/v1/tasks/{id}/stage` set it on any task that is not done or canceled.
- A Publish Kanban switch in the project editor puts a public project's board at `/projects/:slug`, read only, and
  its card on the projects page links there. `read_project`, `list_projects` and the API show the flag. Any other
  slug answers "That board isn't public." with a 404.
- The mail reader shows a message's HTML, with its links, lists and images, and falls back to the plain body when a
  message has none.
- A mail thread in Waiting shows an "in waiting" chip on its row, and the reader names the rule that put it there.
- `MEDIA_STORE_READ_TIMEOUT`, `SHARE_STORE_READ_TIMEOUT` and `BACKUP_STORE_READ_TIMEOUT` set how long each store
  waits on a read, 30 seconds for media and 300 for the others by default. Store errors now name the bucket.

### Changed

- Sign-in matches a verified email, not a GitHub id. GitHub sign-in asks for `user:email` and takes the primary
  verified address, and Google takes the address Google has verified. Each row in the sign-in log names the provider.
- GitHub, Google and Mastodon share one callback route for signing in and connecting alike. `AUTH_CALLBACK_PATH` sets
  it, under `/admin` and with a `:provider` part, and it defaults to `/admin/auth/:provider/callback`, the path each
  of them already uses.
- A mail row drags from anywhere on it, and the grip is gone. A mouse drag starts after 6px, and a finger has to hold
  still for 300ms, so a swipe still scrolls and a tap still opens the thread. Below 1180px, where no folder shows,
  rows don't drag.
- Every mail account's Label menu has the new-tag field. A new tag on a Gmail thread stays on the site and never
  reaches Gmail, while picking an existing Gmail label still writes through.
- The mail bulk bar's Move and Label selects act as soon as you pick, and Select all reads "Select all N".
- Projects sit in the tasks group beside Tasks and Calendar, with their tabs, not under Publish.
- Before you deploy, add your email to `owner_identities` on the live database. The migration drops the GitHub id
  rows and every session ends, so with no email row nobody can sign in.

## [26.10.17] - 2026-10-12

### Fixed

- Google Health syncs again from an account that also grants mail or calendar. Google refused any Health read whose
  token carried those scopes with a 403, so every Health sync and backfill failed. Health now reads with a token
  that holds only its own scopes.
- The Gmail backfill fills in older mail. It hit Gmail's per-minute limit partway through its first page and gave up
  after three tries, so no account got past it. It now takes 25 threads every 30 seconds and waits two minutes when
  Gmail says to slow down.

## [26.10.16] - 2026-10-12

### Changed

- Connecting Google lets you untick mail, calendar or any Health scope, and asks Google only for what stays ticked.
  Each Google account's detail has a Change access button that opens the same choice with what the account holds,
  and a scope you left off shows as off rather than asking you to grant it.

### Fixed

- Google sits under a Personal group on Connected services, and its picker line names Gmail and Google Calendar. It
  used to sit under Health.

## [26.10.15] - 2026-10-12

### Added

- Mail under the Inbox group replaces Messages. It lists threads from every Google account and the contact form, by
  account, folder, label, unread or search, with a folder sidebar on wide screens. The reader folds earlier messages,
  shows a People card for the sender and lists each message's attachments, which download from Gmail on click. A job
  syncs Gmail every five minutes, and a new account fills in its whole mailbox, spam and trash included, a page at a
  time. `read_sync_state` shows each run.
- Thread actions in the reader, the bulk bar and the inbox now reach Gmail: read, unread, star, archive, spam, label,
  Move to Inbox, Delete, Restore and Delete forever. A label stays with its own account, and the toast says how many
  threads it skipped. When Gmail refuses a change, the page says so and changes nothing.
- Compose and Reply send through Gmail with a rich-text editor, the account's Gmail signature and a file picker for up
  to 25 MB. Send & archive files the thread as it sends. Compose saves a Gmail draft as you type, the draft shows in
  Drafts, and opening it brings compose back.
- A Mail settings page turns each account's inbox and sending on or off, shows or hides the contact form and picks
  what puts a thread in Waiting: starred, unread contact form mail, mail from People, a needs-reply label or Gmail's
  important mark. It can leave out GitHub, Linear and Docs notices. Each Waiting row says which rule matched.
- Make a task, in the reader and on each Waiting row, turns a thread into a task linked to it and archives the thread.
  The thread then shows its task, and the task page lists the thread among its links.
- On wide screens a grip on each mail row drags the thread, or every picked thread, onto a folder or label.
- Google Calendar events show on the calendar page, from 90 days back to a year ahead for every Google account, synced
  every 15 minutes. The day panel lists each event with its calendar, times, place, guests, notes and Meet link. A
  picker hides calendars, and Work only shows the work accounts' calendars.
- The day panel makes, edits and deletes Google events, and a recurring event asks whether to change this one or all
  of them. A grip drags an event to another day at the same time, and a Move form does the same without a script. A
  Work account switch on each Google connection in Connected services keeps that account's calendars read-only.
- A `mail` scope for MCP consent and API tokens, which `read` does not cover. It grants `list_mail_threads`,
  `read_mail_thread`, `mark_mail_thread`, `mark_mail_threads_read`, `mark_mail_threads_unread`, `tag_mail_threads`,
  `untag_mail_threads`, `delete_mail_threads` and `snooze_mail_threads`, and the API's `/mail/threads` endpoints.
  Without it, search, `list_inbox` and the inbox tools leave mail out.
- `list_calendar` and the API calendar return Google events to any token with `read`.
- A right-click, the Menu key or Shift+F10 on an admin row opens a menu of everything that row can do, drawn as it
  stands when the menu opens. Tasks, posts, social posts, projects, people, journal entries, decisions, files, links,
  tags, inbox rows, webmentions, comments, work sessions, sprints, commits, task rules, tokens, MCP clients, services,
  Today's attention rows, dead jobs, mail threads and Google events all have one. With rows picked, a right-click on a
  picked task, post, webmention or mail thread opens a menu for all of them. Deletes ask for a second click.
- A running task's tracked time counts up on the page without a reload.

### Changed

- Task controls and the row actions on the inbox, posts, calendar, webmentions, links, sessions, comments and sprints
  lists update the page in place instead of loading a new one, and show the same toast. Filters do the same and
  replace the address rather than add to history, so Back leaves the screen.
- Google connections in Connected services hold many accounts, one row each, with Grant on a row that lacks a scope.
  Each asks for full Gmail and Calendar access, so existing accounts need a Grant. Health keeps syncing from the
  account that granted it. The settings, environment variables and callback route change from `google_health` to
  `google`, so production needs `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` and the redirect URI
  `/admin/auth/google/callback`.
- Contact form messages move into Mail as threads, keeping their ids, so old admin links, API and MCP ids and search
  hits still work.

### Removed

- The Messages screens and the eight message MCP tools, replaced by Mail and the mail thread tools.
- The Apply button on filters with scripts off.

## [26.10.14] - 2026-10-11

### Fixed

- A day's health strip in Activity sits under its date as three small lines. It used to take the wide column and
  squeeze the day's events into the narrow one.

## [26.10.13] - 2026-10-11

### Fixed

- Google Health syncs. Google refused the resting heart rate and HRV reads with a 400, so every sync and the
  first backfill failed and stored no days or workouts.

## [26.10.12] - 2026-10-11

### Added

- Google Health joins Settings > Services. It connects one Google account with read-only access to sleep, activity
  and health metrics, renews its token on its own and shows that it needs a reconnect when Google revokes it.
  Disconnect revokes the token at Google too. A job syncs every 15 minutes and reads the last 3 days again, and the
  first connect pulls all the history Google holds. `read_sync_state` shows each run.
- A Health tab under Insights lays out 14, 30 or 90 days of sleep, HRV, resting heart rate, exercise, focused time
  and commits. It flags short nights, low HRV, high resting heart rate and commits after 22:00, opens any day with
  its workouts and work, and shows patterns such as focused time after short nights. A card lists the MCP clients
  and API tokens that can read health data.
- Today shows last night's sleep, HRV and resting heart rate. Activity lists workouts under a Workouts filter, and
  each day with health data shows a strip of its figures.
- A `health` scope for MCP consent and API tokens. It grants `GET /api/v1/health/days` and the `read_health_days`
  MCP tool, which return day rows, workouts and patterns for a date range. `read` no longer reaches health data:
  `read_activity`, `summarize_activity` and `read_saved_view` leave workouts out without `health`.

### Changed

- The task drawer keeps a header with the key, status, list, source and close, and a footer with Delete, Close and
  Edit, in view while the body scrolls. The body shows the title, notes and a grid of list, sprint, tags,
  contributors, dates, carried and worked. Tags moved from the header into that grid.
- Edit, a row's pen or `e` turn the task drawer into the edit form in place, and Save or Cancel turn it back. The
  task modal now only adds tasks.
- A task's timeline splits into Time worked, with each session's start, end and length and Set total, Comments, and
  a closed list of moves, tag changes and status changes. A comment shows when it was edited. The Add button on task
  and decision comments shows once the box holds text.
- The Services screen shows a tile for each service, in brand colors for Mastodon and Bluesky, and the connect
  dialog moves Continue to its footer.

### Fixed

- Task, comment and session rows in Activity open the task in the drawer, scrolled to that comment or session. A
  task row used to open the tasks list.
- A task with a six-digit id and a GitHub source link no longer pushes the ticked tasks list wider than a phone
  screen.

## [26.10.11] - 2026-10-11

### Added

- File shares at `aa.cool`. A Files tab under Publish uploads one or more files up to 100 MB, by form or by drop, and
  gives each a five-character link on `aa.cool`, copied as the upload ends. It searches, filters images from other
  files and pages twelve at a time. A drawer for each file changes its code and alt text, copies the link or Markdown,
  shows its downloads and deletes it. Images, PDFs, video and audio open in the browser, other files download under
  their own name, and range requests work. A download counts once, and bots, later ranges and the admin's own
  previews don't count.
- Short links at `aa.cool`. A Links tab under Publish shortens a link with a code you pick or one it draws, and says
  when you shortened the link before. It searches, sorts by newest or most clicked and pages fifteen at a time. A
  drawer for each link changes where it points, its code and its title, copies it and deletes it. A link answers with
  a redirect and counts each click from a browser.
- A social post takes up to four photos on each part, each with alt text. Drop, paste or pick them, then move or
  remove them, and the preview shows them. Mastodon and Bluesky get them as photos with their alt text, shrunk to fit
  each network's limit.
- `mise run test:profile <files>` runs spec files in one process for test-prof, and `mise run test:coverage` merges
  coverage results.

### Changed

- A social post sends each outside link as its `aa.cool` short link and reuses a code made before. Links to the site
  stay long, and the saved post keeps every link as written. The counter and preview count the short length.
- The site and the admin take the new design's brighter palette in both themes, text colors included.
- Signed out, the public header shows a theme toggle in place of the settings menu, and admin pages show the public
  site header.
- The post editor's Preview tab sets the title and body in the public post page's type.
- Webmention settings have their own screen, and the webmention inbox links to it from a Settings button.
- On the Review screen, a decision's outcome sits on its own line under its title.
- `mise run test` runs the specs across processes, each on its own database. CI runs lint, Ruby specs and browser
  specs as separate jobs and merges their coverage.

### Fixed

- A live refresh in the admin keeps what you typed in a form. It used to empty every field but the focused one, so a
  change from a job, the API or MCP could wipe a draft.
- The task page and the new task page no longer fail on their back link when the admin's other back link loads first.
- The copy button and tags on the tasks list keep a full tap target when the line wraps.

### Security

- A signed-out post over 1 MB to the photo upload path is refused before the site reads it. It used to parse up to
  25 MB.

## [26.10.10] - 2026-10-10

### Added

- A weekly job checks every outbound link in each published post. A link that fails two checks in a row shows on the
  attention card with its post and the reason, links to the post's editor and can be snoozed. It drops off once it
  answers again or leaves the post. `list_attention` returns broken links too.
- Jobs that died after their last retry show on the attention card with their name, when they died and their error,
  with Retry and Discard buttons. `list_attention` returns them as `dead_jobs`. A dead job the card already shows as a
  sync failure is not listed twice, and the card still loads while Redis is down.
- The Review screen has a heat map with one column per day and rows for done, commits, time worked and journal
  entries. Pick a day to narrow every card but Carried over to it, and pick it again or change period to clear it. A
  Done by select narrows done tasks to anyone, you or one contributor. The API's review and `read_review` take a
  `focus` day and return counts for each day.
- An On this day card on the Review screen lists journal entries and posts from the same dates in earlier years. The
  API's review and `read_review` return them as `earlier`.
- The Completed tab on Tasks takes a date range, and the task search takes `project:` beside `tag:`. Review links
  into both.
- API tokens take scopes and an optional last day when you mint them. An endpoint refuses a token without the scope
  it needs with a 403 that names the scope, and an expired token gets a 401. Tokens minted before keep every scope and
  never expire.
- `mise run db:check` builds a scratch database from the migrations and fails when the schema dump does not match.
- The Security and Connected services screens update on their own when a sign-in or a connection changes.

### Changed

- The Review cards follow the new design. Each shows at most five rows or groups, with two items per group and a
  "+N more" count, opens the rest in place without scripts, and links to the full list in Tasks, Decisions, the
  journal, Posts or Social. Done groups by tag or by project.
- Time sits under Insights as "time report", and People sits under Settings beside Tags.
- The command palette groups screens under their category, such as Inbox, Insights and Settings, and hides a header
  once a search empties it.
- The journal search box searches as you type, like the other search boxes. Without scripts it keeps its button.
- Icon-only buttons in the admin show their name on hover.
- MCP and API text names the site's time zone as America/Chicago.
- Tag refusals across the API and MCP read "lowercase words joined by hyphens".
- `list_projects`, `save_project` and the post write tools answer with the same fields as the API, which adds
  `created_at`, `updated_at` and post tags.
- `POST /posts/{id}/publish` ignores a request body, as its OpenAPI entry already said.

### Fixed

- A visitor throttled just before local midnight stays throttled after it. The contact form, webmentions, MCP client
  sign-up and the analytics beacon used to start the count over at midnight.
- A social post due to go out with none of its accounts left now shows as failed. It used to stay scheduled for good.
- A webmention whose target page answered with a server error or didn't answer at all is now retried. It used to be
  skipped.
- A start replayed from Linear joins the sprint current when the sync runs, and never moves a running session's start
  later.
- Issue comment sync no longer deletes the copy of a comment past the first 100 on a long thread.
- Later today in the snooze menu no longer offers a time tomorrow late in the evening.
- A `#` heading in a post body renders as a second-level heading, so the page keeps one top heading.
- A single-author host given as an IPv6 address now matches its webmentions.
- Connecting an account someone already connected says the account is taken, where it used to show an error page.
- MCP refusals for projects, work entries and tags say what is wrong in words, where they used to say "check this
  field". A tag name with a control character says so on the tag form too.
- The light theme color matches the page background, and every static error page keeps a full tap target on a phone.

### Security

- MCP's `/authorize` refuses a request without `code_challenge_method`, where it used to let one through.
- The bulk message and webmention MCP tools mark the subject, body and reply address, and the author name, URL,
  excerpt and source, as untrusted, as the single-record tools already did. So does `delete_messages`.

## [26.10.9] - 2026-10-10

### Added

- The GitHub dialog on the Connected services tab takes a personal access token beside Sign in with GitHub. The site
  asks GitHub who owns the token before it saves it, labels the connection with that account and shows GitHub's reason
  when it refuses one. Test connection checks it, the connection detail says OAuth or token, and Disconnect reminds you
  to revoke the token on GitHub.
- `/sitemap.xml` lists the home, About, Projects, Contact and Writing pages, each published post with its last change,
  and each tag page that has a published post. `/robots.txt` keeps crawlers off the admin, API, MCP, OAuth, pulse and
  webmention paths and points them to the sitemap.
- A post with three or more sections shows an On this page list beside the body from 1100px wide. It stays in view as
  you scroll and marks the section you are reading. Without scripts it is a list of plain links.
- Each post heading gets an id made from its text, so a link to `#its-text` lands on it, and a repeated heading gets a
  numbered suffix. A code fence with a file name after the language, such as `ruby config/providers/redis.rb`, shows
  the file name above the code. An image alone in its paragraph with a title shows as a figure, with the title as its
  caption. The admin preview shows all three.
- The contact page shows the time where the site lives and ticks over each minute. Without scripts it names the time
  zone.
- Each public page with no image of its own shares a default image as a large card. Every shared image carries alt
  text.
- The home, About, Projects, Contact, Writing and tag pages each have their own description for search and share
  cards. The home page's tab reads "Writing and projects" beside the owner's name.
- Posts carry JSON-LD that names them as blog posts, and the home page carries JSON-LD for the site and its owner, with
  the owner's profile links.

### Changed

- The public site runs full width, with type and spacing that grow with the window. The header is a sticky bar of
  pill links with the settings menu behind a round button, and on a phone the pills wrap to a full row in place of the
  menu. The footer shows a glasses mark before the copyright.
- The slash in the wordmark cycles through colors on hover or focus, in the public header and the admin top bar. It
  stays still when you ask for reduced motion.
- The home page sets writing beside projects from 900px wide. Writing rows set the date beside the title once the list
  is 720px wide, and only the title links to the post. Project cards are boxed and fill a grid of one to four columns,
  with the site's address at the foot and past projects left unfilled. About keeps a career sidebar in view, contact
  sets its details beside the form, and the privacy, tag and Writing pages open with the same page head.
- A post's title grows with the window over a serif body that ends in a glasses mark, and the meta line reads "N min".
  Edits, Also posted on and responses sit in one block, where each response shows an initial and the author's domain.
  Previous, All writing and Next cards replace the post footer.
- Post images after the first load only when you scroll near them, and the site's own photos in a post carry their
  size, so the page no longer jumps as they load.

### Fixed

- A post with no summary is described by its first paragraph cut to 160 characters, where it used to send the whole
  paragraph. No page sends an empty description tag any more.

### Security

- `read_pull_request`, `list_pull_requests`, `search`, linked records, `read_activity` and activity saved views mark
  pull request titles and descriptions as untrusted, since people other than the owner write them.

## [26.10.8] - 2026-10-09

### Fixed

- Connect on the Connected services tab opens GitHub's or the Mastodon server's sign-in page. A plain click did nothing,
  because the admin's content security policy blocked the redirect.
- Connecting GitHub no longer fails on GitHub with "The redirect_uri is not associated with this application". It now
  comes back through the same address as sign-in.

## [26.10.7] - 2026-10-09

### Added

- Settings has a Connected services tab. Connect GitHub and Mastodon through OAuth, Bluesky with a handle and an app
  password, and Linear workspaces with an API key, then test or disconnect each one. Mastodon works on any server, and
  Mastodon and Bluesky take more than one account. The site encrypts the keys it keeps, and posting, commit import,
  issue sync and the MCP tools follow a new connection with no restart.
- A social post goes to each account ticked in the composer. Its To row opens a Post as menu grouped by network, with
  chips for the picked accounts, all and none links for each network, Everywhere, and a search once there are more than
  five accounts. A new post starts with the accounts you last sent or scheduled to, kept in the browser, or with the
  first account when there are none.
- Pull requests you author, in any repo and from forks too, import from GitHub every 15 minutes and show in Today's sync
  health. Each one has an admin page, shows opened, merged and closed rows in Activity and `read_activity`, links to
  other records and turns up in search. `list_pull_requests`, `read_pull_request` and `GET /api/v1/pull_requests/:id`
  read them.
- Messages open in the reading pane, where you can mark one read or unread, snooze or wake it, label it with tags and
  delete it. The Messages screen searches the subject, sender, body and tags, and filters by status and tag, with a new
  Inbox filter for everything but spam. `tag_messages` and `untag_messages` tag messages, `list_messages`,
  `read_message` and the API return their tags and `snoozed_until`, and the Tags screen counts them.
- The people page has a Find an account panel beside the list. Add on a result opens the new person drawer with the
  name, key and handle filled in.
- The projects field on a task rule has a search with chips, and marks archived projects.

### Changed

- Sign-in lets in only a GitHub account listed in the owner identities table. `OWNER_GITHUB_ID` goes, and an empty table
  lets nobody in, so the live site needs its first row added by hand.
- The site needs a `DATA_KEY` secret, apart from `APP_SECRET`, to encrypt service keys. `mise run setup:environment`
  writes one.
- The time report total, its project and tag groups, and the review's worked figures count overlapping task time once,
  so three tasks run in the same hour count one hour. Task rows still show each task's full time, a group with overlap
  shows a hint, and the API and MCP report an `overlapped` flag. Past reports change to match.
- The API and MCP list one delivery for each account a social post goes to, with its `account`, which is null for sends
  from before this release. Adding a network to a post that picked accounts adds every account on that network.
- The social queue shows networks in their colors, and on a posted item each network links to the post it made, named by
  account when it went to more than one.
- People rows show handles as colored links with a hover pencil, the person drawer shows network colors with Remove on
  the left, and the handle fields in the person form, including the one in the mention dialog, lose their search boxes.
- Accepting or rejecting one suggestion keeps the suggestions dialog open.
- Analytics and post analytics open on 30 days.
- The palette tells screen readers when its rows are still loading.

### Removed

- `GITHUB_API_TOKEN`, `LINEAR_API_KEYS`, `BLUESKY_APP_PASSWORD` and `MASTODON_ACCESS_TOKEN`, and the settings behind
  them, with no fallback. Connect each service from the Connected services tab instead.

### Fixed

- Blue and pink tags on a ticked task row no longer fall below 4.5:1 contrast. Code keywords take the lighter pink too.
- Linked records on the project editor no longer start below the side column and leave a gap under the tagline card.

## [26.10.6] - 2026-10-08

### Added

- The API serves social posts at `/api/v1/social_posts`: list by day range and queue, create, update, send now or at
  `schedule_at`, and delete one that has not gone out. Each answer carries each part's length and limit on every
  network the post targets. `list_social_posts`, `create_social_post`, `update_social_post`, `send_social_post` and
  `delete_social_post` now call these routes, and a `list_social_posts` row carries targets, `updated_at` and the
  full delivery, as `read_social_post` does.
- `w` opens a journal modal on every admin screen, with the same Markdown editor as the journal page, a live word
  count, tags, and Ctrl or Cmd+Enter to save today's entry. The palette's Create journal entry, the Journal row on
  Today and the attention card's Journal row open it too.
- Needs attention on Today shows how many inbox rows wait, how many cross-posts failed, and an Open security link on
  each new device row.
- The palette gains Plan tomorrow, Import commits, Sync issues, Keyboard shortcuts and Toggle theme. Typing in it
  offers Create task with the typed title and See all results. ⌘K and Ctrl+K open it, `c` creates a task and `w`
  writes in the journal.
- Admin search, the palette, `search` and `GET /api/v1/search` find decisions.
- Analytics, post analytics and the Security page show each visit's and sign-in's country by name, and
  `read_analytics` returns `country_name` beside `country_code`. Rows stored before this release show the code.
- A task row counts its comments, and clicking an open task's box completes it.
- `mise run dev:create-workspace <id> [base]` sets up a jj workspace with its own test database, and
  `mise run dev:remove-workspace <id>` drops it. `mise run test:ruby [paths]` runs specs with no asset build, and
  `mise run db:start` and `mise run redis:start` start Postgres and Redis.

### Changed

- The admin has a new look and fills the window. A top bar holds six pills (Today, Tasks, Journal, Publish, Inbox and
  Insights), each with tabs under its page head, a search button and an avatar menu with settings, key help, theme
  and sign out. Screens lay out in cards, in two columns from 860px. The task panel and the post editor's details
  open in drawers on the right, every button is a pill, and a confirm asks in place of the button that needs it
  rather than in a browser prompt. A missing admin address shows a 404 inside the admin.
- Row actions in task, pull in, attention, journal, project, decision option, task rule and work history lists show
  on hover or focus as icon buttons. On touch screens and phones they always show.
- The palette lists Actions, Saved views, Go to, Records and Search, and ranks records of every kind in one list of
  eight, each named by its kind.
- Today heads with a line built from the sprint and drops its stat strip and journal card. Sprint tasks show in large
  rows, the pull in list folds under Pull from a list while the sprint has tasks, and Shipped today counts the repos
  pushed to today, where it used to count the last 30 days.
- Tags, task rules, API tokens, MCP clients and Security share one Settings head. A tag's editor opens in the panel
  on the right of the Tags page rather than under the tag.
- The issue sync replays each change to a Linear issue at the time Linear logged it, so a start or stop no longer
  lands up to 15 minutes late, and two starts between runs leave two sessions. A task started by hand moves to
  Linear's start time. Sessions logged before this release stay as they are.
- `mise run dev:stop` leaves Postgres and Redis running.

### Fixed

- Code blocks in posts no longer split a comment or a block's parameters across lines or draw stray borders.
- `mise run dev:stop` in a jj workspace no longer stops the main checkout's server and worker.
- The key help no longer shows blank keys beside its fixed rows.

## [26.10.5] - 2026-10-07

### Added

- A Security page at `/admin/security` lists each sign-in, wrong account and failed GitHub callback with its time,
  outcome, browser, OS, city, country and IP. Each live API token and MCP client lists the devices and cities it has
  called from, with first and last seen, the call count and the last IP. The page sits in the admin menu and the
  palette, and links to the Honeybadger project when `HONEYBADGER_PROJECT_URL` is set. A daily job deletes these
  records after 90 days.
- The attention list shows a sign-in, token or MCP client that turns up from a device or city it has not used before,
  for 7 days or until snoozed. A credential's first device sets the baseline and does not show. The site keeps the
  devices and cities it knows after the 90-day prune, so an old one does not come back as new, and `list_attention`
  returns these rows.
- The inbox head has Mark All As Seen and Snooze All for the rows on the page. Each row has a Snooze button with
  quick picks and a date and time, and a Snoozed section lists what waits with a Wake now button. A woken row returns
  to the top. `clear_inbox`, `snooze_inbox`, `snooze_inbox_row` and `wake_inbox_row`, and `POST /api/v1/inbox/seen`,
  `/inbox/snooze`, `/inbox/snooze/all` and `/inbox/wake`, do the same.
- `/projects` sorts public projects by stars and lists archived ones under Past Projects. The home page shows the
  three active projects with the most stars.
- A task rule can link synced issues to projects as well as tag them. An issue from a project's own repo links to that
  project with no rule, and giving a project a repo links its past imports once.

### Changed

- A project is public or private, and archived when it has an archive date. Private projects stay off the site, and a
  tag only they carry has no public page. The admin editor and `save_project` ask for the visibility, and the API and
  MCP return it with a status of active or archived. Every project made before this release is public.
- Task tag rules are task rules. The admin page, `save_task_rule`, `list_task_rules`, `delete_task_rule` and
  `/api/v1/task_rules` replace the old names, which no longer answer.
- An issue row in the inbox has an Edit button that opens the task dialog in place of its tag field. A seen
  webmention leaves the inbox but stays pending on the Webmentions page.
- A long title in an admin list wraps beside its buttons at desktop width rather than pushing them below it.
- The weekly MaxMind refresh downloads GeoLite2 City in place of GeoLite2 Country. Analytics still keeps a country
  only.

### Removed

- Projects no longer have a featured flag or a hand-set order, so the move controls and the `move_project` tool are
  gone.

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
- `mise run release --dry-run` prints the next CalVer version.
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

[Unreleased]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.35...HEAD
[26.10.35]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.34...26.10.35
[26.10.34]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.33...26.10.34
[26.10.33]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.32...26.10.33
[26.10.32]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.31...26.10.32
[26.10.31]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.30...26.10.31
[26.10.30]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.29...26.10.30
[26.10.29]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.28...26.10.29
[26.10.28]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.27...26.10.28
[26.10.27]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.26...26.10.27
[26.10.26]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.25...26.10.26
[26.10.25]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.24...26.10.25
[26.10.24]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.23...26.10.24
[26.10.23]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.22...26.10.23
[26.10.22]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.21...26.10.22
[26.10.21]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.20...26.10.21
[26.10.20]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.19...26.10.20
[26.10.19]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.18...26.10.19
[26.10.18]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.17...26.10.18
[26.10.17]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.16...26.10.17
[26.10.16]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.15...26.10.16
[26.10.15]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.14...26.10.15
[26.10.14]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.13...26.10.14
[26.10.13]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.12...26.10.13
[26.10.12]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.11...26.10.12
[26.10.11]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.10...26.10.11
[26.10.10]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.9...26.10.10
[26.10.9]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.8...26.10.9
[26.10.8]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.7...26.10.8
[26.10.7]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.6...26.10.7
[26.10.6]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.5...26.10.6
[26.10.5]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.4...26.10.5
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
