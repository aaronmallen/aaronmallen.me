Feature: Admin inbox snooze
  Snooze puts an inbox row to sleep until a time the owner picks. A snoozed row leaves the inbox and its count,
  waits in a Snoozed section, and comes back at the top once it wakes.

  Background:
    Given I am signed in to the admin

  Scenario: Each inbox row's Snooze button opens its own dialog and tells screen readers so
    Given the inbox holds:
      | id | kind       | title      | arrived |
      | 7  | message    | message    | -300    |
      | 8  | webmention | webmention | -200    |
      | 9  | issue      | task       | -100    |
    When I visit "/admin/inbox"
    Then the inbox screen's ".inbox-row [data-dialog-open^='snooze-']" carry "data-dialog-open" "snooze-task-9, snooze-webmention-8, snooze-message-7"
    And the inbox screen has "dialog#snooze-task-9[data-dialog]"
    And the inbox screen has "dialog#snooze-webmention-8[data-dialog]"
    And the inbox screen has "dialog#snooze-message-7[data-dialog]"
    And the inbox screen has no "[data-dialog-open]:not([aria-haspopup='dialog'])"

  Scenario: The snooze dialog offers the quick picks and a date and time field that starts now
    Given the inbox holds:
      | id | kind    | title   |
      | 7  | message | message |
    When I visit "/admin/inbox"
    Then the snooze dialog "dialog#snooze-message-7" offers the quick picks for now
    And the inbox screen's "dialog#snooze-message-7 input[type=datetime-local]" starts at the current minute

  Scenario: The snooze dialog takes its title from its id and saves from its foot
    Given the inbox holds:
      | id | kind    | title   |
      | 7  | message | message |
    When I visit "/admin/inbox"
    Then the inbox screen has "dialog#snooze-message-7 .dialog-head h2#snooze-message-7-title"
    And the inbox screen has "dialog[aria-labelledby='snooze-message-7-title'] form#snooze-message-7-form"
    And the inbox screen has "#snooze-message-7 > .dialog-box > .dialog-foot [type=submit][form='snooze-message-7-form']"

  Scenario Outline: Snoozing a <kind> from a quick pick drops it until then
    Given the inbox holds:
      | id | kind       | title      |
      | 7  | message    | message    |
      | 8  | webmention | webmention |
      | 9  | issue      | task       |
    When I post the form to the admin "/admin/inbox/<kind>/<id>/snooze" with:
      | pick | 2030-01-08T08:00 |
    And I follow the admin post
    Then the admin toast says "Snoozed until"
    And the database answers "2030-01-08 08:00" for:
      """
      SELECT to_char(snoozed_until AT TIME ZONE 'America/Chicago', 'YYYY-MM-DD HH24:MI') FROM <table> WHERE <key> = <id>
      """
    And the inbox shows the rows "<left>"

    Examples:
      | kind       | id | table        | key     | left                |
      | message    | 7  | mail_threads | id      | task, webmention    |
      | webmention | 8  | webmentions  | id      | task, message       |
      | task       | 9  | task_sources | task_id | webmention, message |

  Scenario: Snoozing from the field sleeps until the time in it
    Given the inbox holds:
      | id | kind    | title   |
      | 7  | message | message |
    When I post the form to the admin "/admin/inbox/message/7/snooze" with:
      | snoozed_until | 2030-01-09T17:30 |
    Then the database answers "2030-01-09 17:30" for:
      """
      SELECT to_char(snoozed_until AT TIME ZONE 'America/Chicago', 'YYYY-MM-DD HH24:MI') FROM mail_threads WHERE id = 7
      """

  Scenario Outline: Snoozing refuses <case> and keeps the row
    Given the inbox holds:
      | id | kind    | title   |
      | 7  | message | message |
    When I post the form to the admin "/admin/inbox/message/7/snooze" with:
      | snoozed_until | <value> |
    And I follow the admin post
    Then the admin toast says "<toast>"
    And the database answers "none" for:
      """
      SELECT coalesce(snoozed_until::text, 'none') FROM mail_threads WHERE id = 7
      """
    And the inbox shows the rows "message"

    Examples:
      | case        | value            | toast                   |
      | a past time | 2020-10-07T10:00 | A snooze ends after now |
      | no time     |                  | Pick a time first       |

  Scenario: Snoozing answers 404 for a kind or a row that is not there
    Given the inbox holds:
      | id | kind    | title   |
      | 7  | message | message |
    When I post the form to the admin "/admin/inbox/post/7/snooze" with:
      | pick | 2030-01-08T08:00 |
    Then the admin post answers 404
    When I post the form to the admin "/admin/inbox/message/0/snooze" with:
      | pick | 2030-01-08T08:00 |
    Then the admin post answers 404

  Scenario Outline: A sleeping <kind> leaves the inbox and its nav count
    Given the inbox holds:
      | kind       | title      | arrived | snoozed            |
      | message    | message    | -300    | <message snoozed>  |
      | webmention | webmention | -200    | <mention snoozed>  |
      | issue      | task       | -100    | <issue snoozed>    |
    Then the inbox shows the rows "<left>"
    And the command palette's inbox entry counts "2 waiting"

    Examples:
      | kind       | message snoozed | mention snoozed | issue snoozed | left                |
      | message    | 3600            |                 |               | task, webmention    |
      | webmention |                 | 3600            |               | task, message       |
      | task       |                 |                 | 3600          | webmention, message |

  Scenario: A row whose snooze has passed comes back, sorted by when it ended
    Given the inbox holds:
      | kind       | title      | arrived | snoozed |
      | message    | message    | -300    | -150    |
      | webmention | webmention | -200    |         |
      | issue      | task       | -100    |         |
    Then the inbox shows the rows "task, message, webmention"

  Scenario: Snoozing leaves the seen, read and pending marks alone
    Given the inbox holds:
      | id | kind       | title      |
      | 7  | message    | message    |
      | 8  | webmention | webmention |
      | 9  | issue      | task       |
    When I post the form to the admin "/admin/inbox/snooze/all" with:
      | tasks[]       | 9                |
      | messages[]    | 7                |
      | webmentions[] | 8                |
      | pick          | 2030-01-08T08:00 |
    Then the inbox shows no rows
    And the database answers "unread, pending, unseen, unseen" for:
      """
      SELECT (SELECT status FROM mail_threads WHERE id = 7) AS message,
        (SELECT status FROM webmentions WHERE id = 8) AS mention,
        (SELECT coalesce(seen_at::text, 'unseen') FROM webmentions WHERE id = 8) AS mention_seen,
        (SELECT coalesce(seen_at::text, 'unseen') FROM task_sources WHERE task_id = 9) AS issue_seen
      """

  Scenario: The Snoozed section hides when nothing is snoozed
    Given the inbox holds:
      | kind    | title   |
      | message | message |
    When I visit "/admin/inbox"
    Then the inbox screen has no "#inbox-snoozed"

  Scenario: The Snoozed section lists every snoozed row soonest first, collapsed, with its kind and wake time
    Given the inbox holds:
      | kind       | title   | snoozed |
      | issue      | Issue   | 300     |
      | message    | Message | 100     |
      | webmention | Mention | 200     |
    When I visit "/admin/inbox"
    Then the inbox screen's "#inbox-snoozed .inbox-snoozed-title" read "Message, Mention, Issue"
    And the inbox screen has no "[data-key-list] .inbox-row-title"
    And the inbox screen has "details#inbox-snoozed:not([open])"
    And the inbox screen's "#inbox-snoozed .inbox-kind" read "message, webmention, issue"
    And the inbox screen holds 3 of "#inbox-snoozed time"

  Scenario: The Snoozed section puts the wake time in a time tag
    Given the inbox holds:
      | kind    | title   | snoozed              |
      | message | message | 2027-01-04T15:00:00Z |
    When I visit "/admin/inbox"
    Then the inbox screen's "#inbox-snoozed time" carry "datetime" "2027-01-04T09:00:00-06:00"

  Scenario: The Snoozed section leaves out a row that would no longer wait or whose snooze has ended
    Given the inbox holds:
      | kind       | title    | state    | snoozed |
      | message    | Read     | read     | 100     |
      | webmention | Approved | approved | 100     |
      | issue      | Done     | done     | 100     |
      | message    | Back     |          | -60     |
    When I visit "/admin/inbox"
    Then the inbox screen has no "#inbox-snoozed"
    And the inbox shows the rows "Back"

  Scenario Outline: Waking a <kind> brings it to the top of the inbox
    Given the inbox holds:
      | id | kind    | title | arrived | snoozed |
      | 1  | message | Newer | 0       |         |
      | 5  | <row>   | Woken | -600    | 3600    |
    When I post the form to the admin "/admin/inbox/wake/<kind>/5"
    And I follow the admin post
    Then I see "Back in the inbox"
    And the inbox screen has no "#inbox-snoozed"
    And the inbox shows the rows "Woken, Newer"

    Examples:
      | kind       | row        |
      | message    | message    |
      | webmention | webmention |
      | task       | issue      |

  Scenario: Waking answers 422 for a row that is not snoozed
    Given the inbox holds:
      | id | kind    | title   |
      | 7  | message | message |
    When I post the form to the admin "/admin/inbox/wake/message/7"
    Then the admin post answers 422

  Scenario: Waking answers 404 for a row that is not there or a kind it does not know
    Given the inbox holds:
      | id | kind    | title   |
      | 7  | message | message |
    When I post the form to the admin "/admin/inbox/wake/message/0"
    Then the admin post answers 404
    When I post the form to the admin "/admin/inbox/wake/comet/7"
    Then the admin post answers 404
