Feature: Calendar event writes
  The owner adds, edits, moves and deletes events on their own Google calendars from the day
  panel. Each change goes to Google first, then a sync brings the mirror up to date. Work
  calendars and calendars the owner can only view take no change.

  Background:
    Given I am signed in to the admin
    And the Google account "me@example.com" is connected with "calendar.events calendar.calendarlist.readonly"
    And the calendar "Aaron" of "me@example.com"
    And the read-only calendar "Work" of "work@example.com"

  Scenario: A visitor who has not signed in writes nothing to Google
    Given Google Calendar takes writes to the calendar "Aaron"
    When a visitor sends the calendar form "/admin/calendar/events" with:
      | calendar | <calendar Aaron> |
      | title    | Lunch            |
      | date     | <today + 3>      |
      | starts   | 12:00            |
      | ends     | 13:00            |
    Then Google Calendar heard no event write

  Scenario: Adding an event sends it to Google and syncs the mirror
    Given Google Calendar takes writes to the calendar "Aaron"
    When I open the calendar on "today + 3"
    And I fill in the new calendar event with:
      | Title    | Lunch       |
      | Calendar | Aaron       |
      | Date     | <today + 3> |
      | Start    | 12:00       |
      | End      | 13:00       |
      | Where    | Sawada      |
    And I add the calendar event
    Then I see the calendar toast "Added to Aaron"
    And Google Calendar got POST "" in "Aaron" with only:
      """
      {
        "summary": "Lunch",
        "location": "Sawada",
        "start": { "date": null, "dateTime": "<today + 3 at 12:00>", "timeZone": "America/Chicago" },
        "end": { "date": null, "dateTime": "<today + 3 at 13:00>", "timeZone": "America/Chicago" }
      }
      """
    And the calendar sync was queued
    And the page has no axe breaches in light or dark

  Scenario: An all-day event goes to Google as whole days
    Given Google Calendar takes writes to the calendar "Aaron"
    When I send the calendar form "/admin/calendar/events" with:
      | day      | <today + 3>      |
      | calendar | <calendar Aaron> |
      | title    | Trip             |
      | date     | <today + 3>      |
      | starts   |                  |
      | ends     |                  |
      | all_day  | 1                |
    Then Google Calendar got POST "" in "Aaron" with the event:
      """
      {
        "start": { "date": "<today + 3>", "dateTime": null, "timeZone": null },
        "end": { "date": "<today + 4>", "dateTime": null, "timeZone": null }
      }
      """
    And the calendar sync was queued

  Scenario: An event that ends before it starts opens the form again and says why
    When I send the calendar form "/admin/calendar/events" with:
      | day      | <today + 3>      |
      | calendar | <calendar Aaron> |
      | title    | Lunch            |
      | date     | <today + 3>      |
      | starts   | 12:00            |
      | ends     | 11:00            |
      | all_day  | 0                |
      | place    | Sawada           |
    Then the calendar form answers with status 422
    And Google Calendar heard no event write
    And the new calendar event form is open
    And the calendar form "cal-event-new" holds "Lunch" in "title"
    And the calendar form "cal-event-new" holds "11:00" in "ends"
    And the calendar form "cal-event-new" holds "Sawada" in "place"
    And the calendar form "cal-event-new" holds "<calendar Aaron>" in "calendar"
    And the calendar form "cal-event-new" says "End it after it starts." under "ends"

  Scenario: The new event form names each field it cannot take
    When I send the calendar form "/admin/calendar/events" with:
      | day      | <today + 3>      |
      | calendar | <calendar Aaron> |
      | title    | Lunch            |
      | date     | <today + 3>      |
      | starts   | 25:00            |
      | ends     | noon             |
      | all_day  | 0                |
    Then the calendar form "cal-event-new" says "Give a start time, such as 10:00." under "starts"
    And the calendar form "cal-event-new" says "Give an end time, such as 10:30." under "ends"
    And the calendar form "cal-event-new" marks "starts" wrong
    When I send the calendar form "/admin/calendar/events" with:
      | day      | <today + 3>      |
      | calendar | <calendar Aaron> |
      | title    |                  |
      | date     | <today + 3>      |
      | starts   | 12:00            |
      | ends     | 13:00            |
      | all_day  | 0                |
    Then the calendar form "cal-event-new" says "Give it a title." under "title"
    When I send the calendar form "/admin/calendar/events" with:
      | day      | <today + 3>      |
      | calendar | <calendar Aaron> |
      | title    |                  |
      | date     | <today + 3>      |
      | all_day  | 1                |
    Then the calendar form "cal-event-new" ticks "all_day"
    And Google Calendar heard no event write

  Scenario: Calendars that take no writes get no new event
    Given the read-only calendar "Holidays" of "me@example.com"
    When I send the calendar form "/admin/calendar/events" with:
      | day      | <today + 3>      |
      | calendar | <calendar Work>  |
      | title    | Lunch            |
      | date     | <today + 3>      |
      | starts   | 12:00            |
      | ends     | 13:00            |
    Then I see the calendar toast "That calendar is read-only"
    When I send the calendar form "/admin/calendar/events" with:
      | day      | <today + 3>         |
      | calendar | <calendar Holidays> |
      | title    | Lunch               |
      | date     | <today + 3>         |
      | starts   | 12:00               |
      | ends     | 13:00               |
    Then I see the calendar toast "That calendar is read-only"
    And Google Calendar heard no event write
    When I open the calendar on "today + 3"
    Then the new calendar event form hints "Work calendars and calendars you can only view take no new events."
    And the new calendar event form offers the calendars:
      | me@example.com | Aaron |

  Scenario: Google refusing a new event says so
    Given Google Calendar answers POST "/calendars/me%40example.com/events" with status 403
    When I send the calendar form "/admin/calendar/events" with:
      | day      | <today + 3>      |
      | calendar | <calendar Aaron> |
      | title    | Lunch            |
      | date     | <today + 3>      |
      | starts   | 12:00            |
      | ends     | 13:00            |
    Then I see the calendar toast "Google didn't take that · try again"

  Scenario: Editing an event changes it in Google
    Given the calendar event "Standup" in "Aaron" on "today + 3" from "09:00" to "09:30"
    And Google Calendar takes writes to the calendar "Aaron"
    When I send the calendar form "/admin/calendar/events/<event Standup>" with:
      | day     | <today + 3> |
      | title   | Standup     |
      | date    | <today + 4> |
      | starts  | 12:00       |
      | ends    | 13:00       |
      | all_day | 0           |
    Then I see the calendar toast "Saved to Aaron"
    And Google Calendar got PATCH "standup" in "Aaron" with the event:
      """
      {
        "start": { "dateTime": "<today + 4 at 12:00>", "timeZone": "America/Chicago" },
        "end": { "dateTime": "<today + 4 at 13:00>", "timeZone": "America/Chicago" }
      }
      """
    And the calendar sync was queued

  Scenario: Editing an event keeps the days it covers
    Given the all-day calendar event "Trip" in "Aaron" from "today + 3" to "today + 5"
    And the calendar event "Night shift" in "Aaron" from "today + 3" at "22:00" to "today + 4" at "02:00"
    And the calendar event "Offsite" in "Aaron" from "today + 3" at "09:00" to "today + 5" at "17:00"
    And the calendar event "Late shift" in "Aaron" from "today + 3" at "22:00" to "today + 4" at "01:00"
    And the calendar event "Long trip" in "Aaron" from "today + 3" at "22:00" to "today + 5" at "01:00"
    And the calendar event "Late" in "Aaron" from "today + 3" at "22:00" to "today + 4" at "00:00"
    And the all-day calendar event "Visit" in "Aaron" from "today + 3" to "today + 4"
    And Google Calendar takes writes to the calendar "Aaron"
    When I send the calendar form "/admin/calendar/events/<event Trip>" with:
      | day     | <today + 3>  |
      | title   | Trip         |
      | date    | <today + 10> |
      | all_day | 1            |
    Then Google Calendar got PATCH "trip" in "Aaron" with the event:
      """
      { "start": { "date": "<today + 10>" }, "end": { "date": "<today + 13>" } }
      """
    When I send the calendar form "/admin/calendar/events/<event Night shift>" with:
      | day     | <today + 3> |
      | title   | Night shift |
      | date    | <today + 3> |
      | starts  | 22:00       |
      | ends    | 02:00       |
      | all_day | 0           |
    Then Google Calendar got PATCH "night-shift" in "Aaron" with the event:
      """
      { "start": { "dateTime": "<today + 3 at 22:00>" }, "end": { "dateTime": "<today + 4 at 02:00>" } }
      """
    When I send the calendar form "/admin/calendar/events/<event Offsite>" with:
      | day     | <today + 3> |
      | title   | Retreat     |
      | date    | <today + 3> |
      | starts  | 09:00       |
      | ends    | 17:00       |
      | all_day | 0           |
    Then Google Calendar got PATCH "offsite" in "Aaron" with the event:
      """
      { "start": { "dateTime": "<today + 3 at 09:00>" }, "end": { "dateTime": "<today + 5 at 17:00>" } }
      """
    When I send the calendar form "/admin/calendar/events/<event Late shift>" with:
      | day     | <today + 3> |
      | title   | Late shift  |
      | date    | <today + 3> |
      | starts  | 09:00       |
      | ends    | 10:00       |
      | all_day | 0           |
    Then Google Calendar got PATCH "late-shift" in "Aaron" with the event:
      """
      { "start": { "dateTime": "<today + 3 at 09:00>" }, "end": { "dateTime": "<today + 3 at 10:00>" } }
      """
    When I send the calendar form "/admin/calendar/events/<event Long trip>" with:
      | day     | <today + 3> |
      | title   | Long trip   |
      | date    | <today + 3> |
      | starts  | 09:00       |
      | ends    | 10:00       |
      | all_day | 0           |
    Then Google Calendar got PATCH "long-trip" in "Aaron" with the event:
      """
      { "start": { "dateTime": "<today + 3 at 09:00>" }, "end": { "dateTime": "<today + 4 at 10:00>" } }
      """
    When I send the calendar form "/admin/calendar/events/<event Late>" with:
      | day     | <today + 3> |
      | title   | Late        |
      | date    | <today + 3> |
      | starts  | 22:00       |
      | ends    | 00:00       |
      | all_day | 0           |
    Then Google Calendar got PATCH "late" in "Aaron" with the event:
      """
      { "start": { "dateTime": "<today + 3 at 22:00>" }, "end": { "dateTime": "<today + 4 at 00:00>" } }
      """
    When I send the calendar form "/admin/calendar/events/<event Visit>" with:
      | day     | <today + 3> |
      | title   | Visit       |
      | date    | <today + 3> |
      | starts  | 09:00       |
      | ends    | 17:00       |
      | all_day | 0           |
    Then Google Calendar got PATCH "visit" in "Aaron" with the event:
      """
      { "start": { "dateTime": "<today + 3 at 09:00>" }, "end": { "dateTime": "<today + 3 at 17:00>" } }
      """
    When I send the calendar form "/admin/calendar/events/<event Visit>" with:
      | day     | <today + 3> |
      | title   | Visit       |
      | date    | <today + 3> |
      | starts  | 22:00       |
      | ends    | 01:00       |
      | all_day | 0           |
    Then Google Calendar got PATCH "visit" in "Aaron" with the event:
      """
      { "start": { "dateTime": "<today + 3 at 22:00>" }, "end": { "dateTime": "<today + 4 at 01:00>" } }
      """
    And the calendar sync was queued

  Scenario: An edit the day panel cannot take opens its form again and says why
    Given the calendar event "Standup" in "Aaron" on "today + 3" from "09:00" to "09:30"
    And the calendar event "Standup" has:
      | google_id    | standup_1 |
      | recurring_id | standup   |
    When I send the calendar form "/admin/calendar/events/<event Standup>" with:
      | day     | <today + 3> |
      | scope   | all         |
      | title   | Lunch       |
      | date    | <today + 3> |
      | starts  | 12:00       |
      | ends    | 11:00       |
      | all_day | 0           |
    Then the calendar form answers with status 422
    And Google Calendar heard no event write
    And the edit form of the calendar event "Standup" is open
    And the calendar form "cal-event-<event Standup>" holds "Lunch" in "title"
    And the calendar form "cal-event-<event Standup>" ticks "all"
    And the calendar form "cal-event-<event Standup>" says "End it after it starts." under "ends"
    When I send the calendar form "/admin/calendar/events/<event Standup>" with:
      | day     | <today + 3> |
      | menu    | 1           |
      | title   | Lunch       |
      | date    | <today + 3> |
      | starts  | 9           |
      | ends    | 13:00       |
      | all_day | 0           |
    Then the calendar form "cal-event-<event Standup>-menu" says "Give a start time, such as 10:00." under "starts"

  Scenario: Editing a recurring event changes this one or moves the whole series
    Given the calendar event "Standup" in "Aaron" on "today + 3" from "09:00" to "09:30"
    And the calendar event "Standup" has:
      | google_id    | standup_1 |
      | recurring_id | standup   |
    And the calendar event "Offsite" in "Aaron" from "today + 3" at "09:00" to "today + 5" at "17:00"
    And the calendar event "Offsite" has:
      | google_id    | offsite_1 |
      | recurring_id | standup   |
    And Google Calendar takes writes to the calendar "Aaron"
    And Google Calendar holds the series "standup" in "Aaron" from "today - 27" at "09:00"
    When I send the calendar form "/admin/calendar/events/<event Standup>" with:
      | day     | <today + 3> |
      | scope   | this        |
      | title   | Lunch       |
      | date    | <today + 3> |
      | starts  | 12:00       |
      | ends    | 13:00       |
      | all_day | 0           |
    Then Google Calendar got PATCH "standup_1" in "Aaron"
    And Google Calendar got no PATCH "standup" in "Aaron"
    When I send the calendar form "/admin/calendar/events/<event Standup>" with:
      | day     | <today + 3> |
      | scope   | all         |
      | title   | Lunch       |
      | date    | <today + 4> |
      | starts  | 12:00       |
      | ends    | 13:00       |
      | all_day | 0           |
    Then Google Calendar got PATCH "standup" in "Aaron" with the event:
      """
      { "start": { "dateTime": "<today - 26 at 12:00>" }, "end": { "dateTime": "<today - 26 at 13:00>" } }
      """
    When I send the calendar form "/admin/calendar/events/<event Offsite>" with:
      | day     | <today + 3> |
      | scope   | all         |
      | title   | Offsite     |
      | date    | <today + 3> |
      | starts  | 09:00       |
      | ends    | 17:00       |
      | all_day | 0           |
    Then Google Calendar got PATCH "standup" in "Aaron" with the event:
      """
      { "start": { "dateTime": "<today - 27 at 09:00>" }, "end": { "dateTime": "<today - 25 at 17:00>" } }
      """
    And the calendar sync was queued

  Scenario: Deleting an event deletes it from Google
    Given the calendar event "Standup" in "Aaron" on "today + 3" from "09:00" to "09:30"
    And the calendar event "Retro" in "Aaron" on "today + 3" from "11:00" to "11:30"
    And the calendar event "Retro" has:
      | google_id    | retro_1 |
      | recurring_id | retro   |
    And Google Calendar takes writes to the calendar "Aaron"
    When I send the calendar form "/admin/calendar/events/<event Standup>/delete" with:
      | day | <today + 3> |
    Then I see the calendar toast "Deleted from Aaron"
    And Google Calendar got DELETE "standup" in "Aaron"
    When I send the calendar form "/admin/calendar/events/<event Retro>/delete" with:
      | day   | <today + 3> |
      | scope | all         |
    Then Google Calendar got DELETE "retro" in "Aaron"
    And Google Calendar got no DELETE "retro_1" in "Aaron"
    And the calendar sync was queued
    When I send the calendar form "/admin/calendar/events/0/delete"
    Then the calendar form answers with status 404

  Scenario: Events on a work calendar take no change
    Given the calendar event "Sync" in "Work" on "today + 3" from "09:00" to "09:30"
    When I send the calendar form "/admin/calendar/events/<event Sync>" with:
      | day     | <today + 3> |
      | title   | Lunch       |
      | date    | <today + 3> |
      | starts  | 12:00       |
      | ends    | 13:00       |
      | all_day | 0           |
    Then I see the calendar toast "That calendar is read-only"
    When I send the calendar form "/admin/calendar/events/<event Sync>/delete" with:
      | day | <today + 3> |
    Then I see the calendar toast "That calendar is read-only"
    When I send the calendar form "/admin/calendar/events/<event Sync>/move" with:
      | day | <today + 3> |
      | to  | <today + 5> |
    Then I see the calendar toast "That calendar is read-only"
    And Google Calendar heard no event write

  Scenario: Moving an event moves it in Google to the same time on the new day
    Given the calendar event "Standup" in "Aaron" on "today + 3" from "09:00" to "09:30"
    And Google Calendar takes writes to the calendar "Aaron"
    When I send the calendar form "/admin/calendar/events/<event Standup>/move" with:
      | day | <today + 3> |
      | to  | <today + 5> |
    Then I see the calendar toast "Moved to <today + 5 medium>"
    And Google Calendar got PATCH "standup" in "Aaron" with only:
      """
      {
        "start": { "date": null, "dateTime": "<today + 5 at 09:00>", "timeZone": "America/Chicago" },
        "end": { "date": null, "dateTime": "<today + 5 at 09:30>", "timeZone": "America/Chicago" }
      }
      """
    And the calendar event "Standup" starts on "today + 5" at "09:00"
    And the calendar sync was queued

  Scenario: Moving an all-day event keeps the days it covers
    Given the all-day calendar event "Trip" in "Aaron" from "today + 3" to "today + 5"
    And Google Calendar takes writes to the calendar "Aaron"
    When I send the calendar form "/admin/calendar/events/<event Trip>/move" with:
      | day | <today + 3>  |
      | to  | <today + 10> |
    Then Google Calendar got PATCH "trip" in "Aaron" with only:
      """
      {
        "start": { "date": "<today + 10>", "dateTime": null, "timeZone": null },
        "end": { "date": "<today + 13>", "dateTime": null, "timeZone": null }
      }
      """
    And the calendar sync was queued

  Scenario: Moving a recurring event moves only this one
    Given the calendar event "Standup" in "Aaron" on "today + 3" from "09:00" to "09:30"
    And the calendar event "Standup" has:
      | google_id    | standup_1 |
      | recurring_id | standup   |
    And Google Calendar takes writes to the calendar "Aaron"
    When I send the calendar form "/admin/calendar/events/<event Standup>/move" with:
      | day | <today + 3> |
      | to  | <today + 5> |
    Then Google Calendar got PATCH "standup_1" in "Aaron"
    And Google Calendar got no PATCH "standup" in "Aaron"
    And Google Calendar got no GET "standup" in "Aaron"
    And the calendar sync was queued

  Scenario: A move the calendar cannot take leaves the event where it was
    Given the calendar event "Standup" in "Aaron" on "today + 3" from "09:00" to "09:30"
    And Google Calendar takes writes to the calendar "Aaron"
    And Google Calendar turns away PATCH to the event "standup" in "Aaron"
    When I send the calendar form "/admin/calendar/events/<event Standup>/move" with:
      | day | <today + 3> |
      | to  | <today - 1> |
    Then I see the calendar toast "A move lands on today or a day after it"
    When I send the calendar form "/admin/calendar/events/<event Standup>/move" with:
      | day | <today + 3> |
      | to  | <today + 5> |
    Then I see the calendar toast "Google didn't take that · try again"
    And the calendar event "Standup" starts on "today + 3"
    When I send the calendar form "/admin/calendar/events/0/move" with:
      | to | <today + 5> |
    Then the calendar form answers with status 404

  Scenario: The day panel offers changes only on calendars that take them
    Given the calendar event "Standup" in "Aaron" on "today + 3" from "09:00" to "09:30"
    And the calendar event "Standup" has:
      | recurring_id | standup |
    And the calendar event "Sync" in "Work" on "today + 3" from "10:00" to "10:30"
    When I open the calendar on "today + 3"
    Then the new calendar event form offers the calendars:
      | me@example.com | Aaron |
    And the calendar event "Standup" can be edited and deleted
    And the calendar event "Standup" asks "This event, All events, This event, All events"
    And the calendar event "Standup" moves through "/admin/calendar/events/<event Standup>/move"
    And the calendar event "Sync" takes no change
    And the calendar event "Sync" has no move form

  Scenario: The calendar offers no new event when no calendar takes writes
    Given the calendar "Aaron" is gone
    And the calendar event "Sync" in "Work" on "today + 3" from "10:00" to "10:30"
    When I open the calendar on "today + 3"
    Then the calendar day panel offers no new event

  Scenario: Once the owner marks the account a work account its calendars take no change
    Given the calendar event "Lunch" in "Aaron" on "today + 3" from "12:00" to "13:00"
    When I send the calendar form "/admin/services/<connection me@example.com>/work" with:
      | work | 1 |
    And I send the calendar form "/admin/calendar/events" with:
      | day      | <today + 3>      |
      | calendar | <calendar Aaron> |
      | title    | Lunch            |
      | date     | <today + 3>      |
      | starts   | 12:00            |
      | ends     | 13:00            |
    Then I see the calendar toast "That calendar is read-only"
    When I send the calendar form "/admin/calendar/events/<event Lunch>" with:
      | day     | <today + 3> |
      | title   | Lunch       |
      | date    | <today + 3> |
      | starts  | 12:00       |
      | ends    | 13:00       |
      | all_day | 0           |
    Then I see the calendar toast "That calendar is read-only"
    When I send the calendar form "/admin/calendar/events/<event Lunch>/delete" with:
      | day | <today + 3> |
    Then Google Calendar heard no event write
    When I open the services settings for the calendar account "me@example.com"
    Then the services settings hint "The site never changes a work account's calendars."
