Feature: Admin bulk select mode
  The tasks and mail screens start with select mode off behind a Select button. Select mode and the ticked rows
  live through a live refresh, but not through a reload or a visit from another page. A setup step that throws
  leaves the Select button working.

  Background:
    Given I am signed in to the admin

  Scenario Outline: On <screen>, with a setup step that throws on load, Select shows with select mode off and turns it on
    Given the menu screens hold "<seed>"
    And an admin setup step throws on load
    When I visit "<path>"
    Then select mode is off for "<form>"
    When I click the button "Select"
    Then select mode is on for "<form>"

    Examples:
      | screen | seed         | path                     | form       |
      | tasks  | two tasks    | /admin/tasks?filter=next | #task-bulk |
      | mail   | two messages | /admin/mail              | #mail-bulk |

  Scenario Outline: On <screen>, with a setup step that throws after a live refresh, Select still shows with select mode off
    Given the menu screens hold "<seed>"
    When I open "<path>" and its live stream
    And an admin setup step throws from now on
    And a <kind> arrives for bulk select
    And the live page hears it and settles
    Then "<arrived>" shows
    And select mode is off for "<form>"

    Examples:
      | screen | seed         | path                     | form       | kind | arrived                       |
      | tasks  | two tasks    | /admin/tasks?filter=next | #task-bulk | task | .task:has-text('arrived')     |
      | mail   | two messages | /admin/mail              | #mail-bulk | mail | .mail-row:has-text('Arrived') |

  Scenario Outline: On <screen>, select mode and a ticked row live through a live refresh
    Given the menu screens hold "<seed>"
    When I open "<path>" and its live stream
    And I click the button "Select"
    And I tick the first "<row>" row
    And a <kind> arrives for bulk select
    And the live page hears it and settles
    Then "<arrived>" shows
    And select mode is on for "<form>"
    And only that row stays ticked

    Examples:
      | screen | seed         | path                     | form       | row       | kind | arrived                       |
      | tasks  | two tasks    | /admin/tasks?filter=next | #task-bulk | .task     | task | .task:has-text('arrived')     |
      | mail   | two messages | /admin/mail              | #mail-bulk | .mail-row | mail | .mail-row:has-text('Arrived') |

  Scenario Outline: On <screen>, select mode with nothing ticked lives through a live refresh
    Given the menu screens hold "<seed>"
    When I open "<path>" and its live stream
    And I click the button "Select"
    And a <kind> arrives for bulk select
    And the live page hears it and settles
    Then "<arrived>" shows
    And select mode is on for "<form>"
    And "<row> input[name='ids[]']" shows

    Examples:
      | screen | seed         | path                     | form       | row       | kind | arrived                       |
      | tasks  | two tasks    | /admin/tasks?filter=next | #task-bulk | .task     | task | .task:has-text('arrived')     |
      | mail   | two messages | /admin/mail              | #mail-bulk | .mail-row | mail | .mail-row:has-text('Arrived') |

  Scenario Outline: On <screen>, select mode starts off with nothing ticked after a reload
    Given the menu screens hold "<seed>"
    When I visit "<path>"
    And I click the button "Select"
    And I tick the first "<row>" row
    And I load the admin page again
    Then select mode is off for "<form>"
    And no row box is ticked

    Examples:
      | screen | seed         | path                     | form       | row       |
      | tasks  | two tasks    | /admin/tasks?filter=next | #task-bulk | .task     |
      | mail   | two messages | /admin/mail              | #mail-bulk | .mail-row |

  Scenario Outline: On <screen>, select mode starts off with nothing ticked on a visit from another page
    Given the menu screens hold "<seed>"
    When I visit "<path>"
    And I click the button "Select"
    And I tick the first "<row>" row
    And I visit "/admin"
    And I visit "<path>"
    Then select mode is off for "<form>"
    And no row box is ticked

    Examples:
      | screen | seed         | path                     | form       | row       |
      | tasks  | two tasks    | /admin/tasks?filter=next | #task-bulk | .task     |
      | mail   | two messages | /admin/mail              | #mail-bulk | .mail-row |

  Scenario Outline: The <screen> screen passes axe with select mode on
    Given the menu screens hold "<seed>"
    When I visit "<path>"
    And I click the button "Select"
    Then the page has no axe breaches in light or dark

    Examples:
      | screen | seed         | path                     |
      | tasks  | two tasks    | /admin/tasks?filter=next |
      | mail   | two messages | /admin/mail              |
