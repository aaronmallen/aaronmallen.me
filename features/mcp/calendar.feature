Feature: Calendar MCP tools
  An agent adds, edits, moves and deletes events on the owner's own Google calendars. Work
  calendars take no change, and each tool needs the permission it names.

  Background:
    Given I am signed in to the admin
    And the Google account "me@example.com" is connected with "calendar.events calendar.calendarlist.readonly"
    And the Google account "work@example.com" is connected with "calendar.events calendar.calendarlist.readonly"
    And the calendar account "work@example.com" is a work account
    And the calendar "Aaron" of "me@example.com"
    And the calendar "Work" of "work@example.com"

  Scenario: create_event writes the event to Google and queues the sync
    Given Google Calendar takes writes to the calendar "Aaron"
    And an MCP client connected with the scopes "read write"
    When I call the calendar MCP tool "create_event" with:
      """
      { "calendar_id": <calendar Aaron>, "title": "Lunch", "date": "<today + 3>", "starts": "12:00", "ends": "13:00", "place": "Sawada" }
      """
    Then the calendar MCP tool answers:
      """
      { "calendar_id": <calendar Aaron>, "created": true }
      """
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
    When I call the calendar MCP tool "create_event" with:
      """
      { "calendar_id": <calendar Aaron>, "title": "Trip", "date": "<today + 3>", "all_day": true }
      """
    Then Google Calendar got POST "" in "Aaron" with the event:
      """
      {
        "start": { "date": "<today + 3>", "dateTime": null, "timeZone": null },
        "end": { "date": "<today + 4>", "dateTime": null, "timeZone": null }
      }
      """

  Scenario: create_event refuses what it cannot write
    Given an MCP client connected with the scopes "read write"
    When I call the calendar MCP tool "create_event" with:
      """
      { "calendar_id": <calendar Work>, "title": "Lunch", "date": "<today + 3>", "starts": "12:00", "ends": "13:00" }
      """
    Then the calendar MCP tool refuses with "the calendar is on a work account or one Google lets you only read, so it takes no changes"
    When I call the calendar MCP tool "create_event" with:
      """
      { "calendar_id": <calendar Aaron>, "title": "Lunch", "date": "<today + 3>", "starts": "12:00", "ends": "11:00" }
      """
    Then the calendar MCP tool says "ends: ends comes before starts; pick a later time"
    When I call the calendar MCP tool "create_event" with:
      """
      { "calendar_id": 999999, "title": "Lunch", "date": "<today + 3>", "all_day": true }
      """
    Then the calendar MCP tool says "no calendar has the ID 999999"
    And Google Calendar heard no event write

  Scenario: edit_event keeps every field left out
    Given the calendar event "Standup" in "Aaron" on "today + 3" from "09:00" to "09:30"
    And the calendar event "Standup" has:
      | place | Room 2 |
    And Google Calendar takes writes to the calendar "Aaron"
    And an MCP client connected with the scopes "read write"
    When I call the calendar MCP tool "edit_event" with:
      """
      { "id": <event Standup>, "title": "Retro" }
      """
    Then the calendar MCP tool answers:
      """
      { "id": <event Standup>, "saved": true }
      """
    And Google Calendar got PATCH "standup" in "Aaron" with only:
      """
      {
        "summary": "Retro",
        "location": "Room 2",
        "start": { "date": null, "dateTime": "<today + 3 at 09:00>", "timeZone": "America/Chicago" },
        "end": { "date": null, "dateTime": "<today + 3 at 09:30>", "timeZone": "America/Chicago" }
      }
      """
    And the calendar sync was queued

  Scenario: edit_event changes one event of a series or the whole series
    Given the calendar event "Standup" in "Aaron" on "today + 3" from "09:00" to "09:30"
    And the calendar event "Standup" has:
      | google_id    | standup_1 |
      | recurring_id | standup   |
    And Google Calendar takes writes to the calendar "Aaron"
    And Google Calendar holds the series "standup" in "Aaron" from "today - 27" at "09:00"
    And an MCP client connected with the scopes "read write"
    When I call the calendar MCP tool "edit_event" with:
      """
      { "id": <event Standup>, "title": "Retro", "scope": "this" }
      """
    Then Google Calendar got PATCH "standup_1" in "Aaron"
    And Google Calendar got no PATCH "standup" in "Aaron"
    When I call the calendar MCP tool "edit_event" with:
      """
      { "id": <event Standup>, "title": "Retro", "scope": "all" }
      """
    Then Google Calendar got PATCH "standup" in "Aaron" with the event:
      """
      { "summary": "Retro" }
      """
    And the calendar sync was queued

  Scenario: move_event moves the event in Google and the mirror
    Given the calendar event "Standup" in "Aaron" on "today + 3" from "09:00" to "09:30"
    And Google Calendar takes writes to the calendar "Aaron"
    And an MCP client connected with the scopes "read write"
    When I call the calendar MCP tool "move_event" with:
      """
      { "id": <event Standup>, "to": "<today + 5>" }
      """
    Then the calendar MCP tool answers:
      """
      { "id": <event Standup>, "date": "<today + 5>" }
      """
    And Google Calendar got PATCH "standup" in "Aaron" with only:
      """
      {
        "start": { "date": null, "dateTime": "<today + 5 at 09:00>", "timeZone": "America/Chicago" },
        "end": { "date": null, "dateTime": "<today + 5 at 09:30>", "timeZone": "America/Chicago" }
      }
      """
    And the calendar event "Standup" starts on "today + 5"
    And the calendar sync was queued

  Scenario: move_event moves one event of a series or the whole series
    Given the calendar event "Standup" in "Aaron" on "today + 3" from "09:00" to "09:30"
    And the calendar event "Standup" has:
      | google_id    | standup_1 |
      | recurring_id | standup   |
    And Google Calendar takes writes to the calendar "Aaron"
    And Google Calendar holds the series "standup" in "Aaron" from "today - 27" at "09:00"
    And an MCP client connected with the scopes "read write"
    When I call the calendar MCP tool "move_event" with:
      """
      { "id": <event Standup>, "to": "<today + 4>" }
      """
    Then Google Calendar got PATCH "standup_1" in "Aaron"
    And Google Calendar got no PATCH "standup" in "Aaron"
    And Google Calendar got no GET "standup" in "Aaron"
    When I call the calendar MCP tool "move_event" with:
      """
      { "id": <event Standup>, "to": "<today + 5>", "scope": "all" }
      """
    Then Google Calendar got PATCH "standup" in "Aaron" with the event:
      """
      { "start": { "dateTime": "<today - 26 at 09:00>" }, "end": { "dateTime": "<today - 26 at 09:30>" } }
      """
    And the calendar sync was queued

  Scenario: move_event refuses a day before today
    Given the calendar event "Standup" in "Aaron" on "today + 3" from "09:00" to "09:30"
    And an MCP client connected with the scopes "read write"
    When I call the calendar MCP tool "move_event" with:
      """
      { "id": <event Standup>, "to": "<today - 1>" }
      """
    Then the calendar MCP tool says "to falls before today; pick today or a later day"
    And Google Calendar heard no event write

  Scenario: delete_event deletes one event or the whole series from Google
    Given the calendar event "Standup" in "Aaron" on "today + 3" from "09:00" to "09:30"
    And the calendar event "Retro" in "Aaron" on "today + 3" from "11:00" to "11:30"
    And the calendar event "Retro" has:
      | google_id    | retro_1 |
      | recurring_id | retro   |
    And Google Calendar takes writes to the calendar "Aaron"
    And an MCP client connected with the scopes "read write delete"
    When I call the calendar MCP tool "delete_event" with:
      """
      { "id": <event Standup> }
      """
    Then the calendar MCP tool answers:
      """
      { "id": <event Standup>, "deleted": true }
      """
    And Google Calendar got DELETE "standup" in "Aaron"
    When I call the calendar MCP tool "delete_event" with:
      """
      { "id": <event Retro>, "scope": "all" }
      """
    Then Google Calendar got DELETE "retro" in "Aaron"
    And the calendar sync was queued

  Scenario: delete_event says so when Google refuses it
    Given the calendar event "Standup" in "Aaron" on "today + 3" from "09:00" to "09:30"
    And Google Calendar turns away DELETE to the event "standup" in "Aaron"
    And an MCP client connected with the scopes "read write delete"
    When I call the calendar MCP tool "delete_event" with:
      """
      { "id": <event Standup> }
      """
    Then the calendar MCP tool says "Google did not take the change, so nothing changed; try again soon"

  Scenario: Every event tool refuses an event on a work calendar
    Given the calendar event "Sync" in "Work" on "today + 3" from "09:00" to "09:30"
    And an MCP client connected with the scopes "read write delete"
    When I call the calendar MCP tool "edit_event" with:
      """
      { "id": <event Sync>, "title": "Retro" }
      """
    Then the calendar MCP tool refuses
    When I call the calendar MCP tool "move_event" with:
      """
      { "id": <event Sync>, "to": "<today + 4>" }
      """
    Then the calendar MCP tool refuses
    When I call the calendar MCP tool "delete_event" with:
      """
      { "id": <event Sync> }
      """
    Then the calendar MCP tool refuses
    And Google Calendar heard no event write

  Scenario: delete_event needs the delete permission
    Given the calendar event "Standup" in "Aaron" on "today + 3" from "09:00" to "09:30"
    And an MCP client connected with the scopes "read write"
    When I call the calendar MCP tool "delete_event" with:
      """
      { "id": <event Standup> }
      """
    Then the calendar MCP call fails with "delete_event needs the delete permission,"
    And Google Calendar heard no event write

  Scenario: Every event write needs the write permission
    Given an MCP client connected with the scopes "read delete"
    When I call the calendar MCP tool "create_event" with:
      """
      {}
      """
    Then the calendar MCP call fails with "create_event needs the write permission,"
    When I call the calendar MCP tool "edit_event" with:
      """
      {}
      """
    Then the calendar MCP call fails with "edit_event needs the write permission,"
    When I call the calendar MCP tool "move_event" with:
      """
      {}
      """
    Then the calendar MCP call fails with "move_event needs the write permission,"
    When I call the calendar MCP tool "delete_event" with:
      """
      {}
      """
    Then the calendar MCP call fails with "delete_event needs the write permission,"

  Scenario: The MCP server tells the client what it may write to the calendar
    Given an MCP client connected with the scopes "read"
    Then the MCP server tells the client "work calendars take no change"
