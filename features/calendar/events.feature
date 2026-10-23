Feature: Calendar events
  Events from the owner's Google calendars show on the month and in the day panel, and a picker
  hides the calendars the owner does not want to see.

  Background:
    Given the calendar "Aaron" of "me@example.com"
    And the read-only calendar "Work" of "work@example.com"

  Scenario: A visitor who has not signed in hides no calendar
    When a visitor sends the calendar form "/admin/calendar/calendars" with:
      | day | 2026-07-14 |
    Then the stored calendars are hidden as:
      | Aaron | false |
      | Work  | false |

  Scenario: A day with three events shows two and counts the rest
    Given I am signed in to the admin
    And the calendar event "Standup" in "Aaron" on "2026-07-14" from "09:00" to "09:30"
    And the all-day calendar event "On-call" in "Work" from "2026-07-14" to "2026-07-14"
    And the calendar event "Sync" in "Work" on "2026-07-14" from "14:00" to "14:30"
    When I open the calendar on "2026-07-14"
    Then the calendar cell for "2026-07-14" shows the marks:
      """
      On-call
      09:00Standup
      +1 events
      """
    And the calendar cell for "2026-07-14" tints its events:
      """
      --tone: var(--color-mk-green-text)
      --tone: var(--color-mk-pink-text)
      """

  Scenario: An event shows on every day it covers
    Given I am signed in to the admin
    And the all-day calendar event "On-call" in "Work" from "2026-07-14" to "2026-07-16"
    When I open the calendar on "2026-07-14"
    Then the calendar cell for "2026-07-14" shows the mark "On-call"
    And the calendar cell for "2026-07-15" shows the mark "On-call"
    And the calendar cell for "2026-07-16" shows the mark "On-call"
    And the calendar cell for "2026-07-17" does not show the mark "On-call"

  Scenario: The day panel describes each event
    Given I am signed in to the admin
    And the calendar event "Coffee with Sean" in "Aaron" on "2026-07-14" from "08:00" to "08:30"
    And the calendar event "Coffee with Sean" has:
      | place     | Sawada Coffee                          |
      | meet_url  | https://meet.google.com/abc            |
      | notes     | Talk about Hanami                      |
      | attendees | Sean                                   |
      | link      | https://calendar.google.com/event?eid=1 |
    And the all-day calendar event "On-call" in "Work" from "2026-07-14" to "2026-07-20"
    When I open the calendar on "2026-07-14"
    Then the calendar day panel lists the event times:
      """
      all day
      08:00
      """
    And the calendar event "Coffee with Sean" reads "Aaron08:00–08:30Sawada Coffee" in the day panel
    And the calendar event "On-call" reads "Workuntil Jul 20" in the day panel
    And the calendar event "Coffee with Sean" opens to "Talk about Hanami"
    And the calendar event "Coffee with Sean" opens to "Sean"
    And the calendar event "Coffee with Sean" opens to "me@example.com"
    And the calendar event "Coffee with Sean" links "Join Meet" to "https://meet.google.com/abc"
    And the calendar event "Coffee with Sean" links "Google Calendar" to "https://calendar.google.com/event?eid=1"
    And the calendar event "Coffee with Sean" links "Join Coffee with Sean" to "https://meet.google.com/abc"
    And the page has no axe breaches in light or dark

  Scenario: Saving a pick hides the calendars left out
    Given I am signed in to the admin
    And the calendar event "Standup" in "Aaron" on "2026-07-14" from "09:00" to "09:30"
    And the calendar event "Sync" in "Work" on "2026-07-14" from "14:00" to "14:30"
    When I open the calendar on "2026-07-14"
    Then the calendar picker reads "Calendars 2/2"
    And the calendar picker lists the accounts "me@example.com, work@example.com"
    And the calendar picker ticks:
      | Aaron         | true |
      | Workread-only | true |
    When I open the calendar picker
    And I untick the calendar "Work"
    And I press "Save" in the calendar picker
    Then I see the calendar toast "Calendars saved"
    And the calendar shows the address "/admin/calendar?day=2026-07-14"
    And the calendar cell for "2026-07-14" shows the marks:
      """
      09:00Standup
      """
    When I open the calendar on "2026-07-14"
    Then the calendar picker reads "Calendars 1/2"
    And the calendar picker ticks:
      | Aaron         | true  |
      | Workread-only | false |
    And the calendar day panel does not show "Sync"

  Scenario: The picker shows work calendars only, all of them, or none
    Given I am signed in to the admin
    And the read-only calendar "Holidays" of "me@example.com"
    And the Google account "me@example.com" is connected with "calendar.events calendar.calendarlist.readonly"
    And the Google account "work@example.com" is connected with "calendar.events calendar.calendarlist.readonly"
    And the calendar account "work@example.com" is a work account
    When I open the calendar on "2026-07-14"
    And I open the calendar picker
    And I press "Work only" in the calendar picker
    Then the stored calendars are hidden as:
      | Aaron    | true  |
      | Holidays | true  |
      | Work     | false |
    When I open the calendar picker
    And I press "Show all" in the calendar picker
    Then the stored calendars are hidden as:
      | Aaron    | false |
      | Holidays | false |
      | Work     | false |
    When I open the calendar picker
    And I untick every calendar
    And I press "Save" in the calendar picker
    Then the stored calendars are hidden as:
      | Aaron    | true |
      | Holidays | true |
      | Work     | true |

  Scenario: The calendar shows no picker before any calendar syncs
    Given I am signed in to the admin
    And the calendar "Aaron" is gone
    And the calendar "Work" is gone
    When I open the calendar on "2026-07-14"
    Then the calendar page shows no calendar picker
