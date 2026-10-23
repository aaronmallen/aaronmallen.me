Feature: Admin list row actions
  The buttons on inbox, post, mail, calendar, webmention, link, task and sprint rows act in place: the page stays,
  any dialog closes and a toast says what happened. A few forms still post and load the page.

  Background:
    Given I am signed in to the admin

  Scenario Outline: Clicking "<button>" on an inbox <kind> acts in place and shows the toast
    Given the inbox holds:
      | kind   | title   |
      | <kind> | <title> |
    When I visit "/admin/inbox"
    And I keep the row page
    And I click "<button>" on the row ".inbox-row:has-text('<title>')"
    Then a row toast says "<toast>"
    And the admin markup lacks "dialog[open]"
    And the row page stayed

    Examples:
      | kind       | title        | button          | toast       |
      | issue      | Fix the feed | Move to Someday | Moved       |
      | issue      | Fix the feed | Seen            | Marked seen |
      | message    | Hello there  | Read            | Marked read |
      | webmention | Ada          | Approve         | Approved    |

  Scenario: Snoozing an inbox message until tomorrow morning acts in place and shows the toast
    Given the inbox holds:
      | kind    | title       |
      | message | Hello there |
    When I visit "/admin/inbox"
    And I keep the row page
    And I click "Snooze" on the row ".inbox-row:has-text('Hello there')"
    And I click "Tomorrow morning" in the open dialog
    Then a row toast says "Snoozed until"
    And the admin markup lacks "dialog[open]"
    And the row page stayed

  Scenario: Snoozing an inbox message until a time of my own acts in place and shows the toast
    Given the inbox holds:
      | kind    | title       |
      | message | Hello there |
    When I visit "/admin/inbox"
    And I keep the row page
    And I click "Snooze" on the row ".inbox-row:has-text('Hello there')"
    And I set "Date and time" in the open dialog to a day from now
    And I click "Snooze" in the open dialog
    Then a row toast says "Snoozed until"
    And the admin markup lacks "dialog[open]"
    And the row page stayed

  Scenario: Waking a snoozed message acts in place and shows the toast
    Given the inbox holds:
      | kind    | title       | snoozed |
      | message | Hello there | 3600    |
    When I visit "/admin/inbox"
    And I keep the row page
    And I open "" under "#inbox-snoozed"
    And I click "Wake now" on the row ".inbox-snoozed-row:has-text('Hello there')"
    Then a row toast says "Back in the inbox"
    And the admin markup lacks "dialog[open]"
    And the row page stayed

  Scenario: Publishing a draft from the posts list acts in place and shows the toast
    Given the database runs:
      """
      INSERT INTO posts (title, slug, body, body_html, webmentions_enabled, read_time, word_count)
      VALUES ('Fresh draft', 'fresh-draft', 'Hi.', '<p>Hi.</p>', false, 1, 1);
      """
    When I visit "/admin/posts?status=draft"
    And I keep the row page
    And I click "Publish Fresh draft" on the row ".li:has-text('Fresh draft')"
    Then a row toast says "Published"
    And the admin markup lacks "dialog[open]"
    And the row page stayed

  Scenario: Marking an open mail thread read acts in place and shows the toast
    Given the inbox holds:
      | id | kind    | title       |
      | 1  | message | Hello there |
    When I visit "/admin/mail?thread=1"
    And I keep the row page
    And I click "Mark read" on the row ".mail-reader"
    Then a row toast says "Marked read"
    And the admin markup lacks "dialog[open]"
    And the row page stayed

  Scenario: Snoozing an open mail thread acts in place and shows the toast
    Given the inbox holds:
      | id | kind    | title       |
      | 1  | message | Hello there |
    When I visit "/admin/mail?thread=1"
    And I keep the row page
    And I click "Snooze" on the row ".mail-reader"
    And I click "Tomorrow morning" in the open dialog
    Then a row toast says "Snoozed until"
    And the admin markup lacks "dialog[open]"
    And the row page stayed

  Scenario: Deleting an open mail thread acts in place and shows the toast
    Given the inbox holds:
      | id | kind    | title       |
      | 1  | message | Hello there |
    When I visit "/admin/mail?thread=1"
    And I keep the row page
    And I click "Delete" on the row ".mail-reader"
    And I accept the row confirm
    Then a row toast says "Thread deleted"
    And the admin markup lacks "dialog[open]"
    And the row page stayed

  Scenario: Moving a post on the calendar acts in place and shows the toast
    Given the database runs:
      """
      INSERT INTO posts (title, slug, status, published_at, body, body_html, webmentions_enabled, read_time, word_count)
      VALUES ('Spread me out', 'spread-me-out', 'scheduled',
              (((now() AT TIME ZONE 'America/Chicago')::date + 2) + time '09:00') AT TIME ZONE 'America/Chicago',
              'Hi.', '<p>Hi.</p>', false, 1, 1);
      """
    When I visit the admin calendar 2 days from today
    And I keep the row page
    And I set "Move Spread me out to" to the date 3 days from today
    And I click the button "Move"
    Then a row toast says "Moved to"
    And the admin markup lacks "dialog[open]"
    And the row page stayed

  Scenario: Approving a webmention from the webmentions list acts in place and shows the toast
    Given the inbox holds:
      | kind       | title |
      | webmention | Ada   |
    When I visit "/admin/webmentions"
    And I keep the row page
    And I click "Approve" on the row ".wm-card:has-text('Ada')"
    Then a row toast says "Approved"
    And the admin markup lacks "dialog[open]"
    And the row page stayed

  Scenario: Deleting a short link from the links list acts in place and shows the toast
    Given the database runs:
      """
      INSERT INTO short_codes (code) VALUES ('talk-now');
      INSERT INTO short_links (short_code_id, destination) VALUES (1, 'https://example.com/talk');
      """
    When I visit "/admin/links"
    And I keep the row page
    And I click the first ".link-row-title a" reading ""
    And I click "Delete link" in the open dialog
    And I accept the row confirm
    Then a row toast says "Link deleted"
    And the admin markup lacks "dialog[open]"
    And the row page stayed

  Rule: A task's sessions and comments

    Background:
      Given the database runs:
        """
        INSERT INTO tasks (title, list, position, worked_seconds) VALUES ('Write the brief', 'next', 1, 1800);
        INSERT INTO work_sessions (task_id, started_at, ended_at)
        VALUES (1, now() - interval '1 hour', now() - interval '30 minutes');
        INSERT INTO task_comments (task_id, body) VALUES (1, 'First thought');
        """
      When I visit "/admin/tasks/1"
      And I keep the row page

    Scenario Outline: Deleting a <thing> on the task page acts in place and shows the toast
      When I click the button "Delete <thing>"
      And I accept the row confirm
      Then a row toast says "<toast>"
      And the admin markup lacks "dialog[open]"
      And the row page stayed

      Examples:
        | thing   | toast           |
        | session | Session deleted |
        | comment | Comment deleted |

    Scenario: Editing a session still posts and loads the page
      When I click the first "summary" reading "Edit"
      And I click the first button "Save"
      Then ".toast" shows
      And the row page loaded again

  Rule: The upcoming sprints

    Background:
      Given the menu screens hold "a sprint in two days"
      When I visit "/admin/tasks?filter=upcoming"
      And I keep the row page

    Scenario: Dropping a sprint acts in place and shows the toast
      When I click the button "Drop"
      And I accept the row confirm
      Then a row toast says "Sprint dropped"
      And the admin markup lacks "dialog[open]"
      And the row page stayed

    Scenario: Declining the drop asks first and keeps the sprint
      When I click the button "Drop"
      And I decline the confirm
      Then ".toast" does not show
      And the admin shows the button "Drop"
      And the row page stayed

    Scenario: Opening a sprint still posts and loads the page
      When I click the button "Open sprint"
      Then ".toast" shows
      And the row page loaded again

  Rule: Axe

    Scenario Outline: The screen at <path> passes axe
      Given the inbox holds:
        | id | kind    | title       |
        | 1  | message | Hello there |
      When I visit "<path>"
      Then the page has no axe breaches in light or dark

      Examples:
        | path                         |
        | /admin/inbox                 |
        | /admin/mail?thread=1         |
        | /admin/webmentions           |
        | /admin/links                 |
        | /admin/tasks?filter=upcoming |
