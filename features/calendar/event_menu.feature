Feature: Calendar event menu
  A right click on an event in the day panel opens a menu of what the event takes. Edits and
  deletes made there stay on the page.

  Background:
    Given I am signed in to the admin
    And the Google account "me@example.com" is connected with "calendar.events calendar.calendarlist.readonly"
    And the calendar "Aaron" of "me@example.com"

  Scenario: The menu edits an event in a dialog and stays on the page
    Given the calendar event "Coffee" in "Aaron" on "today" from "09:00" to "10:00"
    And the calendar event "Coffee" has:
      | link     | https://calendar.google.com/event?eid=abc |
      | meet_url | https://meet.google.com/abc               |
    And Google Calendar takes writes to the calendar "Aaron"
    When I open the calendar on "today"
    And I mark the calendar page
    And I open the menu of the calendar event "Coffee"
    Then the calendar event menu is headed "Coffee"
    And the calendar event menu holds:
      """
      Edit
      Join Meet
      Open in Google Calendar
      Delete event
      """
    And the calendar event menu opens "https://calendar.google.com/event?eid=abc" in a new tab
    And the calendar event menu opens "https://meet.google.com/abc" in a new tab
    When I pick "Edit" in the calendar event menu
    And I retitle the calendar event to "Tea"
    Then I see the calendar toast "Saved to Aaron"
    And Google Calendar got PATCH "coffee" in "Aaron" with the event:
      """
      { "summary": "Tea" }
      """
    And the calendar page is still the one I marked
    And the calendar sync was queued

  Scenario: The menu deletes an event on a second click and stays on the page
    Given the calendar event "Coffee" in "Aaron" on "today" from "09:00" to "10:00"
    And Google Calendar takes writes to the calendar "Aaron"
    When I open the calendar on "today"
    And I mark the calendar page
    And I open the menu of the calendar event "Coffee"
    And I pick "Delete event" in the calendar event menu
    Then the calendar event menu offers "Click again · Google loses it too"
    And Google Calendar got no DELETE "coffee" in "Aaron"
    When I pick "Click again · Google loses it too" in the calendar event menu
    Then I see the calendar toast "Deleted from Aaron"
    And Google Calendar got DELETE "coffee" in "Aaron"
    And the calendar page is still the one I marked
    And the calendar sync was queued

  Scenario: The menu deletes one event of a series or the whole series
    Given the calendar event "Standup" in "Aaron" on "today" from "09:00" to "09:30"
    And the calendar event "Standup" has:
      | google_id    | standup_1 |
      | recurring_id | standup   |
    And Google Calendar takes writes to the calendar "Aaron"
    When I open the calendar on "today"
    And I open the menu of the calendar event "Standup"
    Then the calendar event menu holds:
      """
      Edit
      Delete this one
      Delete the whole series
      """
    When I pick "Delete the whole series" in the calendar event menu
    And I pick "Click again · Google loses it too" in the calendar event menu
    Then I see the calendar toast "Deleted from Aaron"
    And Google Calendar got DELETE "standup" in "Aaron"
    And Google Calendar got no DELETE "standup_1" in "Aaron"
    And the calendar sync was queued

  Scenario: The menu offers only the links on a read-only calendar
    Given the read-only calendar "Work" of "work@example.com"
    And the calendar event "Sync" in "Work" on "today" from "11:00" to "11:30"
    And the calendar event "Sync" has:
      | link | https://calendar.google.com/event?eid=sync |
    When I open the calendar on "today"
    And I open the menu of the calendar event "Sync"
    Then the calendar event menu holds:
      """
      Open in Google Calendar
      """

  Scenario: The menu of an event that is gone answers not found
    Then the calendar answers GET "/admin/calendar/events/0/menu" with status 404
