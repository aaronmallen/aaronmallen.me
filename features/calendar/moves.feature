Feature: Calendar moves
  The day panel moves a scheduled post, a scheduled social post or an open sprint task to
  another day. A move keeps the time of day and never lands before today.

  Scenario: A visitor who has not signed in moves nothing
    Given the scheduled post "Spread me out" lands on the calendar on "today + 3" at "09:00"
    When a visitor sends the calendar form "/admin/calendar/posts/<post Spread me out>/move" with:
      | to  | <today + 10> |
      | day | <today + 3>  |
    Then the calendar post "Spread me out" goes out on "today + 3" at "09:00"

  Scenario: The day panel offers a move form only on what can move
    Given I am signed in to the admin
    And the scheduled post "Spread me out" lands on the calendar on "today + 3" at "09:15"
    And the scheduled social post "Queued note" lands on the calendar on "today + 3" at "16:45"
    And the published post "Out already" lands on the calendar on "today" at "00:00"
    And the posted social post "Sent note" lands on the calendar on "today" at "00:00"
    When I open the calendar on "today + 3"
    Then the calendar day panel offers the move forms:
      """
      /admin/calendar/posts/<post Spread me out>/move
      /admin/calendar/social/<social Queued note>/move
      """
    And the calendar move field "Move Spread me out to" starts on "today + 3" no earlier than "today"
    And the page has no axe breaches in light or dark
    When I open the calendar on "today"
    Then the calendar day panel offers no move form

  Scenario: Moving a scheduled post keeps its time of day
    Given I am signed in to the admin
    And the scheduled post "Spread me out" lands on the calendar on "today + 3" at "09:15"
    When I send the calendar form "/admin/calendar/posts/<post Spread me out>/move" with:
      | to  | <today + 10> |
      | day | <today + 3>  |
    Then the calendar shows the address "/admin/calendar?day=<today + 3>"
    And I see the calendar toast "Moved to <today + 10 medium> at 09:15"
    And the calendar post "Spread me out" goes out on "today + 10" at "09:15"
    And the calendar post "Spread me out" is still scheduled

  Scenario: Moving a scheduled social post keeps its time of day
    Given I am signed in to the admin
    And the scheduled social post "Queued note" lands on the calendar on "today + 3" at "16:45"
    When I send the calendar form "/admin/calendar/social/<social Queued note>/move" with:
      | to  | <today + 10> |
      | day | <today + 3>  |
    Then the calendar shows the address "/admin/calendar?day=<today + 3>"
    And the calendar social post "Queued note" goes out on "today + 10" at "16:45"

  Scenario: A move to today takes a time still ahead and refuses one gone by
    Given I am signed in to the admin
    And the scheduled post "Later today" lands on the calendar on "today + 3" at "23:59"
    And the scheduled social post "Later note" lands on the calendar on "today + 3" at "23:59"
    And the scheduled post "Gone by" lands on the calendar on "today + 3" at "00:00"
    And the scheduled social post "Gone note" lands on the calendar on "today + 3" at "00:00"
    And a post "Due now" scheduled for an hour ago
    When I send the calendar form "/admin/calendar/posts/<post Later today>/move" with:
      | to  | <today>     |
      | day | <today + 3> |
    And I send the calendar form "/admin/calendar/social/<social Later note>/move" with:
      | to  | <today>     |
      | day | <today + 3> |
    And I send the calendar form "/admin/calendar/posts/<post Gone by>/move" with:
      | to  | <today>     |
      | day | <today + 3> |
    And I send the calendar form "/admin/calendar/social/<social Gone note>/move" with:
      | to  | <today>     |
      | day | <today + 3> |
    Then the calendar post "Later today" goes out on "today" at "23:59"
    And the calendar social post "Later note" goes out on "today" at "23:59"
    And the calendar post "Gone by" goes out on "today + 3" at "00:00"
    And the calendar social post "Gone note" goes out on "today + 3" at "00:00"
    When the due posts job runs
    Then the home page lists "Due now"
    And the calendar post "Gone by" is still scheduled

  Scenario: A move to a past day leaves the post where it was
    Given I am signed in to the admin
    And the scheduled post "Spread me out" lands on the calendar on "today + 3" at "09:15"
    And the scheduled social post "Queued note" lands on the calendar on "today + 3" at "16:45"
    When I send the calendar form "/admin/calendar/social/<social Queued note>/move" with:
      | to  | <today - 1> |
      | day | <today + 3> |
    And I send the calendar form "/admin/calendar/posts/<post Spread me out>/move" with:
      | to  | <today - 1> |
      | day | <today + 3> |
    Then I see the calendar toast "A move lands on today or a day after it"
    And the calendar post "Spread me out" goes out on "today + 3" at "09:15"
    And the calendar social post "Queued note" goes out on "today + 3" at "16:45"

  Scenario: The calendar refuses a move it cannot make
    Given I am signed in to the admin
    And the scheduled social post "Queued note" lands on the calendar on "today + 3" at "16:45"
    And the scheduled social post "Sending note" lands on the calendar on "today + 3" at "17:00"
    And the calendar social post "Sending note" has started sending
    And the published post "Out already" lands on the calendar on "today - 2" at "09:00"
    And the posted social post "Sent note" lands on the calendar on "today - 2" at "08:00"
    And the scheduled post "Spread me out" lands on the calendar on "today + 3" at "09:15"
    When I send the calendar form "/admin/calendar/social/<social Queued note>/move" with:
      | to  |             |
      | day | <today + 3> |
    Then I see the calendar toast "Pick a day first"
    When I send the calendar form "/admin/calendar/posts/<post Out already>/move" with:
      | to  | <today + 10> |
      | day | <today + 3>  |
    Then the calendar post "Out already" goes out on "today - 2" at "09:00"
    When I send the calendar form "/admin/calendar/social/<social Sent note>/move" with:
      | to  | <today + 10> |
      | day | <today + 3>  |
    Then I see the calendar toast "Only a scheduled post moves"
    When I send the calendar form "/admin/calendar/social/<social Sending note>/move" with:
      | to  | <today + 10> |
      | day | <today + 3>  |
    Then the calendar social post "Sending note" goes out on "today + 3" at "17:00"
    When I send the calendar form "/admin/calendar/posts/999999/move" with:
      | to  | <today + 10> |
      | day | <today + 3>  |
    Then the calendar form answers with status 404
    When I send the calendar form "/admin/calendar/posts/<post Spread me out>/move" with:
      | to  | <today + 10> |
      | day | someday      |
    Then the calendar shows the address "/admin/calendar"

  Scenario: The day panel offers a move form on each open sprint task
    Given I am signed in to the admin
    And the sprint on the calendar day "today + 3" holds the open task "Lighten the day"
    And the sprint on the calendar day "today + 3" holds the done task "Done already"
    And the sprint on the calendar day "today + 3" holds the canceled task "Dropped"
    When I open the calendar on "today + 3"
    Then the calendar day panel offers the move forms:
      """
      /admin/calendar/tasks/<task Lighten the day>/move
      """
    And the calendar move field "Move Lighten the day to" starts on "today + 3" no earlier than "today"

  Scenario: Moving a sprint task puts it in the sprint on the new day
    Given I am signed in to the admin
    And the sprint on the calendar day "today + 3" holds the open task "Lighten the day"
    And the sprint on the calendar day "today + 3" holds the open task "Plan the trip"
    And an empty sprint lands on the calendar on "today + 10"
    When I send the calendar form "/admin/calendar/tasks/<task Lighten the day>/move" with:
      | to  | <today + 10> |
      | day | <today + 3>  |
    Then the calendar task "Lighten the day" sits in the sprint on "today + 10"
    And one sprint lands on the calendar on "today + 10"
    When I send the calendar form "/admin/calendar/tasks/<task Plan the trip>/move" with:
      | to  | <today + 12> |
      | day | <today + 3>  |
    Then the calendar shows the address "/admin/calendar?day=<today + 3>"
    And I see the calendar toast "Moved to the <today + 12 medium> sprint"
    And the calendar task "Plan the trip" sits in the sprint on "today + 12"
    When I open the calendar task "Plan the trip"
    Then the task timeline reads "Moved from the <today + 3 medium> sprint to the <today + 12 medium> sprint"

  Scenario: A sprint task stays put when the move cannot land
    Given I am signed in to the admin
    And the sprint on the calendar day "today + 3" holds the open task "Lighten the day"
    And the sprint on the calendar day "today + 3" holds the done task "Done already"
    When I send the calendar form "/admin/calendar/tasks/<task Lighten the day>/move" with:
      | to  | <today - 1> |
      | day | <today + 3> |
    Then I see the calendar toast "A move lands on today or a day after it"
    When I send the calendar form "/admin/calendar/tasks/<task Lighten the day>/move" with:
      | to  |             |
      | day | <today + 3> |
    Then I see the calendar toast "Pick a day first"
    And the calendar task "Lighten the day" sits in the sprint on "today + 3"
    When I send the calendar form "/admin/calendar/tasks/<task Done already>/move" with:
      | to  | <today + 10> |
      | day | <today + 3>  |
    Then I see the calendar toast "A closed task stays where it closed"
    And the calendar task "Done already" sits in the sprint on "today + 3"
    When I send the calendar form "/admin/calendar/tasks/999999/move" with:
      | to  | <today + 10> |
      | day | <today + 3>  |
    Then the calendar form answers with status 404
