Feature: Admin pages that stay live
  An open admin page hears each change to the tables it draws and morphs in the new page, without losing what the
  owner is doing on it.

  Background:
    Given I am signed in to the admin

  Scenario: A synced issue lights the inbox badge on Tasks > External
    When I open "/admin/tasks?filter=external" and its live stream
    Then the admin markup lacks ".pill-nav-dot"
    When the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('Synced', 1, 'external');
      INSERT INTO task_sources (task_id, provider, remote_id, url)
        VALUES (1, 'github', 'I_seven', 'https://github.com/aaronmallen/blog/issues/7');
      """
    Then ".top-bar .pill-nav-dot" shows
    And the admin markup holds "#command-palette-inbox .pal-r-sub:has-text('1 waiting')"

  Scenario: A new message shows in the open inbox
    When I open "/admin/inbox" and its live stream
    And the contact form brings in "Hello there"
    Then "[id^='message-']:has-text('Hello there')" shows

  Scenario: A new message shows on the mail page and the open thread stays open
    Given the contact form brings in "Answered"
    And the database runs:
      """
      UPDATE mail_threads SET status = 'read';
      """
    When I open "/admin/mail?thread=1" and its live stream
    And the contact form brings in "Hello there"
    Then "#thread-2:has-text('Hello there')" shows
    And ".mail-reader h2:has-text('Answered')" shows

  Scenario: A refetch after the session ends reloads into sign-in
    When I open "/admin/inbox" and its live stream
    And the admin session cookie goes away
    And the contact form brings in "Hello there"
    Then the admin address is "/admin/sign-in"

  Scenario: A refetch that fails shows the failed toast once while refetches keep failing
    When I open "/admin/inbox" and its live stream
    And every refetch of "/admin/inbox" fails
    And the contact form brings in "Hello there"
    Then ".toast-failed:has-text('Couldn')" shows
    When the contact form brings in "Hello again"
    Then "/admin/inbox" is soon asked for at least 3 times
    And the failed toast showed once

  Scenario: The mail Select button stays on screen after a live update
    When I open "/admin/mail" and its live stream
    And the contact form brings in "Hello there"
    Then "[id^='thread-']:has-text('Hello there')" shows
    And the admin markup holds "button[data-bulk-toggle][aria-pressed='false']:has-text('Select')"

  Scenario: The avatar menu still marks the current theme after a live update
    When I open "/admin/inbox" and its live stream
    And the contact form brings in "Hello there"
    Then ".top-bar .pill-nav-dot" shows
    When I click the avatar
    Then the avatar menu marks the current theme

  Scenario: The empty comment box keeps its Add button hidden after a live update
    Given the database runs:
      """
      INSERT INTO decisions (title, problem) VALUES ('Pick a queue', 'Jobs pile up');
      """
    When I open "/admin/decisions/1" and its live stream
    And the contact form brings in "Hello there"
    Then ".top-bar .pill-nav-dot" shows
    And "button:has-text('Add comment')" does not show

  Scenario: The mail composer keeps its rich editor and hides Cc and Bcc after a live update
    Given the services hold a google connection labelled "aaron@work.example"
    When I open "/admin/mail" and its live stream
    And I click the link "Compose"
    And I press the keys "Escape"
    And the contact form brings in "Hello there"
    Then "[id^='thread-']:has-text('Hello there')" shows
    When I click the link "Compose"
    Then "#mail-compose .mail-editor-surface" shows
    And "#mail-compose [data-mail-text]" does not show
    And the admin shows the button "cc"
    And "#mail-compose-cc" does not show

  Scenario: The people finder stays on screen after a live update
    Given the services hold a mastodon connection labelled "@aaronmallen@203.0.113.5"
    When I open "/admin/contacts" and its live stream
    And the contact form brings in "Hello there"
    Then ".top-bar .pill-nav-dot" shows
    And the admin markup holds "#person-finder input[aria-label='Search Mastodon'], #person-finder input[placeholder*='Mastodon']"

  Scenario: A new trusted author shows on the open webmentions tab
    When I open "/admin/settings/webmentions" and its live stream
    And the database runs:
      """
      INSERT INTO trusted_authors (author_url) VALUES ('https://ada.example/');
      """
    Then "#webmentions:has-text('ada.example')" shows

  Scenario: A new webmention shows in the open inbox
    Given the database runs:
      """
      INSERT INTO posts (title, slug, body, body_html, status, read_time, word_count, published_at)
        VALUES ('Hello', 'hello', 'Hi.', '<p>Hi.</p>', 'published', 1, 1, now() - interval '1 day');
      """
    When I open "/admin/inbox" and its live stream
    And the database runs:
      """
      INSERT INTO webmentions (post_id, source_url, author_name, type)
        VALUES (1, 'https://ada.example/reply', 'A neighbour', 'reply');
      """
    Then "#webmention-1:has-text('A neighbour')" shows

  Scenario: A new sign-in shows on the open security page
    When I open "/admin/settings/security" and its live stream
    And the database runs:
      """
      INSERT INTO sign_ins (outcome, provider, address, user_agent, browser, os)
        VALUES ('denied', 'github', '203.0.113.9', 'FF', 'Firefox', 'Linux');
      """
    Then ".li-title:has-text('Firefox · Linux')" shows

  Scenario: A new tag and a new task rule show on the open tagging tab
    When I open "/admin/settings/tagging" and its live stream
    And the database runs:
      """
      INSERT INTO posts (title, slug, body, body_html, status, read_time, word_count)
        VALUES ('Hello', 'hello', 'Hi.', '<p>Hi.</p>', 'draft', 1, 1);
      INSERT INTO tags (name, color, scope) VALUES ('elixir', 'mk-blue', 'public');
      INSERT INTO post_tags (post_id, tag_id) VALUES (1, 1);
      INSERT INTO task_rules (pattern, provider) VALUES ('octocat/*', 'github');
      """
    Then "#tags .tag-row:has-text('#elixir')" shows
    And "#task-rules .rule-pattern:has-text('octocat/*')" shows

  Scenario: A new connection shows on the open connected services tab
    When I open "/admin/settings/services" and its live stream
    And the services hold a linear connection labelled "ROOT workspace"
    Then ".svc-account:has-text('ROOT workspace')" shows

  Scenario: The page morphs under a script policy without unsafe-eval
    Given the contact form brings in "Already here"
    Then a browser that keeps the page's policy shows "#message-<id>" on "/admin/inbox" once the contact form brings in "Hello there"

  Scenario: A page names the tables behind it and the top bar
    Given the database runs:
      """
      INSERT INTO sprints (sprint_date) VALUES ((now() AT TIME ZONE 'America/Chicago')::date) ON CONFLICT DO NOTHING;
      """
    When I open "/admin/tasks" and its live stream
    Then the main element lists the live tables "task_tags mail_threads"

  Scenario: A page ignores a change to a table it does not list
    Given the database runs:
      """
      INSERT INTO sprints (sprint_date) VALUES ((now() AT TIME ZONE 'America/Chicago')::date) ON CONFLICT DO NOTHING;
      """
    When I open "/admin/tasks" and its live stream
    And the admin change stream announces "decisions"
    And the live page hears it and settles
    Then "/admin/tasks" was asked for 1 time

  Scenario: A page refetches for a change to a table it lists
    Given the database runs:
      """
      INSERT INTO sprints (sprint_date) VALUES ((now() AT TIME ZONE 'America/Chicago')::date) ON CONFLICT DO NOTHING;
      """
    When I open "/admin/tasks" and its live stream
    And the admin change stream announces "task_tags"
    Then "/admin/tasks" is soon asked for at least 2 times

  Scenario: A page refetches on the catch-up event
    Given the database runs:
      """
      INSERT INTO sprints (sprint_date) VALUES ((now() AT TIME ZONE 'America/Chicago')::date) ON CONFLICT DO NOTHING;
      """
    When I open "/admin/tasks" and its live stream
    And the admin change stream announces "*"
    Then "/admin/tasks" is soon asked for at least 2 times

  Scenario: The calendar ignores a new commit and refetches for a change to its events
    When I open "/admin/calendar" and its live stream
    And the admin change stream announces "commits"
    And the live page hears it and settles
    Then "/admin/calendar" was asked for 1 time
    When the admin change stream announces "calendar_events"
    Then "/admin/calendar" is soon asked for at least 2 times

  Scenario: While a refetch is in flight no other starts, and one more follows once it lands
    Given the database runs:
      """
      INSERT INTO sprints (sprint_date) VALUES ((now() AT TIME ZONE 'America/Chicago')::date) ON CONFLICT DO NOTHING;
      """
    When I open "/admin/tasks" and its live stream
    And the next refetch of "/admin/tasks" is held once the server answers
    And the admin change stream announces "task_tags"
    And the held refetch arrives
    And the admin change stream announces "task_tags"
    And the live page hears it
    And the admin change stream announces "task_tags"
    And the live page hears it
    Then the live page is asking
    And "/admin/tasks" was asked for 2 times
    When the held refetch lands
    Then "/admin/tasks" is soon asked for at least 3 times
    When the live page settles
    Then "/admin/tasks" was asked for 3 times

  Scenario: An in-place submit renders the page once and still shows a change made elsewhere
    Given the database runs:
      """
      INSERT INTO sprints (sprint_date) VALUES ((now() AT TIME ZONE 'America/Chicago')::date) ON CONFLICT DO NOTHING;
      INSERT INTO tasks (title, position, sprint_id) VALUES ('Ship it', 1, (SELECT id FROM sprints));
      """
    When I open "/admin/tasks?filter=today" and its live stream
    And I start the task "Ship it" from its row
    Then the admin shows the button "Stop"
    When the live page hears it and settles
    Then "/admin/tasks" was asked for 2 times
    When the contact form brings in "Hello there"
    Then ".top-bar .pill-nav-dot" shows

  Scenario: A save from the task panel reloads the page with no refetch before it
    Given the database runs:
      """
      INSERT INTO sprints (sprint_date) VALUES ((now() AT TIME ZONE 'America/Chicago')::date) ON CONFLICT DO NOTHING;
      INSERT INTO tasks (title, position, list) VALUES ('Email the accountant', 1, 'next');
      """
    When I open "/admin/tasks?filter=next" and its live stream
    And I rename the task "Email the accountant" to "Email the bookkeeper" in the task panel and close it
    Then ".task-title:text-is('Email the bookkeeper')" shows
    And "/admin/tasks" was asked for 2 times

  Scenario: A field keeps focus, the caret and unsent text while the page morphs
    Given the database runs:
      """
      INSERT INTO posts (title, slug, body, body_html, status, read_time, word_count, published_at)
        VALUES ('Hello', 'hello', 'Hi.', '<p>Hi.</p>', 'published', 1, 1, now() - interval '1 day');
      INSERT INTO webmentions (post_id, source_url, author_name, type, received_at)
        VALUES (1, 'https://ada.example/reply', 'A neighbour', 'reply', now() - interval '1 minute');
      """
    When I open "/admin/inbox" and its live stream
    And I type "sent from a bot" in "#webmention-1 input[name='reason']" and pick its letters 4 to 8
    And the contact form brings in "Hello there"
    Then "[id^='message-']:has-text('Hello there')" shows
    And "#webmention-1 input[name='reason']" keeps focus, the text "sent from a bot" and the letters 4 to 8 picked

  Scenario: A draft keeps its unsaved edits and what the editor drew from them
    When I open "/admin/posts/new" and its live stream
    And I fill the post editor's "Title" with "A fresh title" and "Body" with "Hello there"
    And the contact form brings in "Hello there"
    Then ".top-bar .pill-nav-dot" shows
    And the post editor's "Title" holds "A fresh title"
    And the post editor's "Body" holds "Hello there"
    And the admin markup holds "[data-editor-words]:text-is('2 words')"

  Scenario: The social composer keeps every account a script picked
    Given the services hold a mastodon connection labelled "@aaronmallen@203.0.113.5"
    And the services hold a bluesky connection labelled "@aaronmallen.example"
    When I pick every social account in the composer's memory
    And I open "/admin/social" and its live stream
    And the contact form brings in "Hello there"
    Then ".top-bar .pill-nav-dot" shows
    And every social account stays picked

  Scenario: Rows ticked by select all stay ticked and counted
    Given the database runs:
      """
      INSERT INTO tasks (title, position, list) VALUES ('first', 1, 'next'), ('second', 2, 'next'), ('third', 3, 'next');
      """
    When I open "/admin/tasks?filter=next" and its live stream
    And I click the button "Select"
    And I tick every task with select all
    And the contact form brings in "Hello there"
    Then ".top-bar .pill-nav-dot" shows
    And the admin markup lacks ".task input[name='ids[]']:not(:checked)"
    And the admin markup holds "[data-bulk-count]:text-is('3 ticked')"

  Scenario: An open dialog holds the morph until it closes
    When I open "/admin/inbox" and its live stream
    And I open the key help from the avatar menu
    And the contact form brings in "Hello there"
    Then "[id^='message-']:has-text('Hello there')" does not show within a second
    When I close the key help
    Then "[id^='message-']:has-text('Hello there')" shows

  Scenario: An open inline confirm holds the morph until it closes
    Given the database runs:
      """
      INSERT INTO journal_entries (entry_date, entry_time, body, body_html)
        VALUES ((now() AT TIME ZONE 'America/Chicago')::date, '09:00', 'Already here', '<p>Already here</p>');
      """
    When I open "/admin/journal" and its live stream
    And I ask to delete the journal entry "Already here"
    And the database runs:
      """
      INSERT INTO journal_entries (entry_date, entry_time, body, body_html)
        VALUES ((now() AT TIME ZONE 'America/Chicago')::date, '10:00', 'Arrived live', '<p>Arrived live</p>');
      """
    And the live page hears it and settles
    Then "main :text('Arrived live')" does not show within a second
    When I decline the confirm
    Then "main :text('Arrived live')" shows

  Scenario: A hidden tab makes no request for a change, and refetches once it shows again
    When I open "/admin/inbox" and its live stream
    And the tab is hidden
    And the contact form brings in "Hello there"
    And the live page hears it and settles
    Then "/admin/inbox" was asked for 1 time
    When the tab is shown
    Then "[id^='message-']:has-text('Hello there')" shows
    And "/admin/inbox" was asked for 2 times

  Scenario: A hidden tab that missed nothing makes no request when it shows again
    When I open "/admin/inbox" and its live stream
    And the tab is hidden
    And the tab is shown
    And the live page settles
    Then "/admin/inbox" was asked for 1 time

  Scenario: After the stream drops the page waits for it, then shows what changed
    Given the browser keeps hold of the page's event streams
    When I open "/admin/inbox" and its live stream
    And the page's event stream drops and its reconnect is held
    And the contact form brings in "Hello there"
    Then "[id^='message-']:has-text('Hello there')" does not show within a second
    When the reconnect goes through
    Then "[id^='message-']:has-text('Hello there')" shows

  Scenario Outline: The live pages pass axe
    When I visit "<route>"
    Then the page has no axe breaches in light or dark

    Examples:
      | route                        |
      | /admin/tasks?filter=external |
      | /admin/mail                  |
      | /admin/contacts              |
      | /admin/social                |
      | /admin/journal               |
      | /admin/calendar              |
