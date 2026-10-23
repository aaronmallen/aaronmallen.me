Feature: Calendar drag
  The owner drags a record from the day panel onto another day to move it there, without
  loading the page.

  Background:
    Given I am signed in to the admin

  Scenario: A scheduled post moves to the day it lands on
    Given the scheduled post "Spread me out" lands on the calendar on "soon" at "09:00"
    When I open the calendar on "soon"
    And I mark the calendar page
    And I drag "Spread me out" onto the calendar day "soon + 1"
    Then I see the calendar toast "Moved to <soon + 1 medium>"
    And the calendar day panel does not show "Spread me out"
    And the calendar cell for "soon + 1" shows a post mark
    And the calendar cell for "soon" does not show the mark "Spread me out"
    And the calendar post "Spread me out" goes out on "soon + 1" at "09:00"
    And the calendar page is still the one I marked
    And the page has no axe breaches in light or dark

  Scenario: A scheduled social post moves to the day it lands on
    Given the scheduled social post "Queued note" lands on the calendar on "soon" at "16:00"
    When I open the calendar on "soon"
    And I drag "Queued note" onto the calendar day "soon + 1"
    Then the calendar cell for "soon + 1" shows a social mark
    And the calendar social post "Queued note" goes out on "soon + 1" at "16:00"

  Scenario: An open sprint task moves to the sprint on the day it lands on
    Given the sprint on the calendar day "soon" holds the open task "Lighten the day"
    When I open the calendar on "soon"
    And I drag "Lighten the day" onto the calendar day "soon + 1"
    Then the calendar cell for "soon + 1" shows a sprint mark
    And the calendar task "Lighten the day" sits in the sprint on "soon + 1"

  Scenario: An event on a writable calendar moves to the day it lands on at the same time
    Given the Google account "me@example.com" is connected with "calendar.events calendar.calendarlist.readonly"
    And the calendar "Aaron" of "me@example.com"
    And the calendar event "Coffee" in "Aaron" on "soon" from "09:00" to "10:00"
    And Google Calendar takes writes to the calendar "Aaron"
    When I open the calendar on "soon"
    And I drag "Coffee" onto the calendar day "soon + 1"
    Then I see the calendar toast "Moved to <soon + 1 medium>"
    And the calendar day panel does not show "Coffee"
    And Google Calendar got PATCH "coffee" in "Aaron" with only:
      """
      {
        "start": { "date": null, "dateTime": "<soon + 1 at 09:00>", "timeZone": "America/Chicago" },
        "end": { "date": null, "dateTime": "<soon + 1 at 10:00>", "timeZone": "America/Chicago" }
      }
      """
    And the calendar sync was queued

  Scenario: Deleting an event after a drag asks first
    Given the scheduled post "Spread me out" lands on the calendar on "soon" at "09:00"
    And the calendar "Aaron" of "me@example.com"
    And the all-day calendar event "Coffee" in "Aaron" from "soon" to "soon"
    When I open the calendar on "soon"
    And I drag "Spread me out" onto the calendar day "soon + 1"
    Then the calendar day panel does not show "Spread me out"
    When I ask to delete the calendar event "Coffee"
    Then the calendar asks "Delete Coffee from Google Calendar?"

  Scenario: An event on a work calendar has no grip
    Given the read-only calendar "Work" of "work@example.com"
    And the all-day calendar event "Sync" in "Work" from "soon" to "soon"
    When I open the calendar on "soon"
    Then the calendar day panel shows "Sync"
    And the calendar day panel offers no grip

  Scenario: A record the day panel cannot move has no grip
    Given the published post "Out already" lands on the calendar on "today" at "00:00"
    And the posted social post "Sent note" lands on the calendar on "today" at "00:00"
    And the sprint on the calendar day "today" holds the done task "Done already"
    When I open the calendar on "today"
    Then the calendar day panel shows "Done already"
    And the calendar day panel offers no grip

  Scenario: A drag the browser cancels leaves the post on its day
    Given the scheduled post "Stay scheduled" lands on the calendar on "soon" at "09:00"
    When I open the calendar on "soon"
    And I drag "Stay scheduled" toward the calendar day "soon + 1" and the browser cancels it
    Then the calendar shows no drag leftovers
    And the calendar day panel shows "Stay scheduled"
    And the calendar post "Stay scheduled" goes out on "soon" at "09:00"

  Scenario: A drop on a past day leaves the task on its day
    Given the sprint on the calendar day "2026-07-14" holds the open task "Stay put"
    When I open the calendar on "2026-07-14"
    And I drag "Stay put" onto the calendar day "2026-07-15"
    Then I see the calendar failure toast "A move lands on today or a day after it"
    And the calendar day panel shows "Stay put"
    And the calendar task "Stay put" sits in the sprint on "2026-07-14"

  Scenario: A save that fails says so and leaves the post where it was
    Given the scheduled post "Hold still" lands on the calendar on "soon" at "09:00"
    When I open the calendar on "soon"
    And I point the move of "Hold still" at a post that is gone
    And I drag "Hold still" onto the calendar day "soon + 1"
    Then I see the calendar failure toast "Couldn't move it · try again"
    And the calendar day panel shows "Hold still"
    And the calendar cell for "soon" shows the mark "Hold still"

  Scenario: A drag shows the refusal when the post went out first
    Given the scheduled post "Hold still" lands on the calendar on "soon" at "09:00"
    When I open the calendar on "soon"
    And the calendar post "Hold still" has gone out
    And I drag "Hold still" onto the calendar day "soon + 1"
    Then I see the calendar failure toast "Only a scheduled post moves"
    And the calendar day panel shows "Hold still"
