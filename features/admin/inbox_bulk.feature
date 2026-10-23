Feature: Admin inbox bulk actions
  Mark All As Seen and Snooze All act on every row the inbox showed. Each posts the rows it saw by kind, so a row
  that arrives later stays, and a row that is gone changes nothing.

  Background:
    Given I am signed in to the admin

  Scenario: Mark All As Seen and Snooze All sit in the head when rows wait
    Given the inbox holds:
      | kind    | title   |
      | message | message |
    When I visit "/admin/inbox"
    Then the inbox screen's ".page-head-actions form[action='/admin/inbox/seen']" carry "data-confirm" "Mark every row here seen? Messages turn read, and webmentions stay pending on Webmentions."
    And the inbox screen's ".page-head-actions button:visible" read "Mark All As Seen, Snooze All"
    And the snooze dialog "dialog#inbox-snooze-all" offers the quick pick labels

  Scenario: Mark All As Seen and Snooze All post every row's id under its kind
    Given the inbox holds:
      | id | kind       | title   |
      | 9  | issue      | Issue   |
      | 7  | message    | Message |
      | 8  | webmention | Mention |
    When I visit "/admin/inbox"
    Then the inbox screen's ".page-head-actions form[action='/admin/inbox/seen']" post "tasks[]=9, messages[]=7, webmentions[]=8"
    And the inbox screen's "dialog#inbox-snooze-all" post "tasks[]=9, messages[]=7, webmentions[]=8"

  Scenario: Mark All As Seen clears the rows it posts, leaving the webmention pending
    Given the inbox holds:
      | id | kind       | title   |
      | 9  | issue      | Issue   |
      | 7  | message    | Message |
      | 8  | webmention | Mention |
    When I post the form to the admin "/admin/inbox/seen" with:
      | tasks[]       | 9 |
      | messages[]    | 7 |
      | webmentions[] | 8 |
    And I follow the admin post
    Then the admin toast says "Marked 3 rows seen"
    And the inbox shows no rows
    And the database answers "pending" for:
      """
      SELECT status FROM webmentions WHERE id = 8
      """

  Scenario: Mark All As Seen keeps a row that arrived after the page drew
    Given the inbox holds:
      | id | kind    | title |
      | 7  | message | Shown |
      | 8  | message | Later |
    When I post the form to the admin "/admin/inbox/seen" with:
      | messages[] | 7 |
    Then the inbox shows the rows "Later"

  Scenario: Mark All As Seen changes nothing when one row is gone and names it
    Given the inbox holds:
      | id | kind  | title |
      | 9  | issue | Kept  |
    When I post the form to the admin "/admin/inbox/seen" with:
      | tasks[]    | 9   |
      | messages[] | 999 |
    And I follow the admin post
    Then the admin toast says "Nothing changed · message 999 is gone"
    And the inbox shows the rows "Kept"

  Scenario: Mark All As Seen names a row that would not change
    Given the inbox holds:
      | id | kind | title      |
      | 9  | task | Sourceless |
    When I post the form to the admin "/admin/inbox/seen" with:
      | tasks[] | 9 |
    And I follow the admin post
    Then the admin toast says "Nothing changed · issue 9 would not change"

  Scenario: Snooze All snoozes the rows it posts until the time picked
    Given the inbox holds:
      | id | kind       | title   |
      | 9  | issue      | Issue   |
      | 7  | message    | Message |
      | 8  | webmention | Mention |
    When I post the form to the admin "/admin/inbox/snooze/all" with:
      | tasks[]       | 9                |
      | messages[]    | 7                |
      | webmentions[] | 8                |
      | pick          | 2030-01-08T08:00 |
    And I follow the admin post
    Then the admin toast says "Snoozed 3 rows until Jan 8, 2030 at 08:00"
    And the inbox shows no rows

  Scenario: Snooze All keeps a row that arrived after the page drew
    Given the inbox holds:
      | id | kind    | title |
      | 7  | message | Shown |
      | 8  | message | Later |
    When I post the form to the admin "/admin/inbox/snooze/all" with:
      | messages[]    | 7                |
      | snoozed_until | 2030-01-08T08:00 |
    Then the inbox shows the rows "Later"

  Scenario: Snooze All changes nothing when one row is gone and names it
    Given the inbox holds:
      | id | kind  | title |
      | 9  | issue | Kept  |
    When I post the form to the admin "/admin/inbox/snooze/all" with:
      | tasks[]    | 9                |
      | messages[] | 999              |
      | pick       | 2030-01-08T08:00 |
    And I follow the admin post
    Then the admin toast says "Nothing changed · message 999 is gone"
    And the inbox shows the rows "Kept"

  Scenario: Snooze All refuses a time in the past
    Given the inbox holds:
      | id | kind    | title   |
      | 7  | message | Message |
    When I post the form to the admin "/admin/inbox/snooze/all" with:
      | messages[]    | 7                |
      | snoozed_until | 2020-10-01T08:00 |
    And I follow the admin post
    Then the admin toast says "A snooze ends after now"
    And the inbox shows the rows "Message"
