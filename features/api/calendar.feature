Feature: Calendar API
  The API lists a range of days with what lands on each: the sprint, posts, social posts, the
  journal and Google events. It also writes events to the owner's own Google calendars.

  Scenario: The API calendar answers every day in the range, oldest first
    Given an API token
    When I call the API with GET "/calendar?from=2026-07-13&to=2026-07-19"
    Then the API answers with status 200
    And the API calendar runs from "2026-07-13" to "2026-07-19"
    And the API calendar day "2026-07-13" is empty

  Scenario: The API calendar gives each day what lands on it
    Given an API token
    And the sprint on the calendar day "2026-07-14" holds the open task "Plan the week"
    And the sprint on the calendar day "2026-07-14" holds the open task "Write the calendar"
    And the scheduled post "Calendar post" lands on the calendar on "2026-07-15" at "09:00"
    And the scheduled social post "Calendar note" lands on the calendar on "2026-07-16" at "10:00"
    And a journal entry lands on the calendar on "2026-07-17"
    And the draft post "Draft post" lands on the calendar on "2026-07-13" at "12:00"
    And the draft social post "Draft note" lands on the calendar on "2026-07-13" at "12:00"
    And the published post "Late post" lands on the calendar on "2026-07-18" at "23:30"
    When I call the API with GET "/calendar?from=2026-07-13&to=2026-07-19"
    Then the API calendar day "2026-07-14" holds:
      """
      { "sprint": { "id": <sprint 2026-07-14>, "task_count": 2 } }
      """
    And the API calendar day "2026-07-15" holds:
      """
      {
        "posts": [
          { "id": <post Calendar post>, "title": "Calendar post", "status": "scheduled", "published_at": "2026-07-15T14:00:00Z" }
        ]
      }
      """
    And the API calendar day "2026-07-16" holds:
      """
      {
        "social_posts": [
          { "id": <social Calendar note>, "status": "scheduled", "posted_at": "2026-07-16T15:00:00Z", "parts": ["Calendar note"] }
        ]
      }
      """
    And the API calendar marks a journal on "2026-07-17" alone
    And the API calendar day "2026-07-13" is empty
    And the API calendar day "2026-07-18" holds:
      """
      { "posts": [{ "id": <post Late post> }] }
      """
    And the API calendar day "2026-07-19" is empty

  Scenario: The API calendar leaves out records dated outside the range
    Given an API token
    And an empty sprint lands on the calendar on "2026-07-20"
    And the published post "Before" lands on the calendar on "2026-07-12" at "23:59"
    And the posted social post "After" lands on the calendar on "2026-07-20" at "00:01"
    And a journal entry lands on the calendar on "2026-07-12"
    When I call the API with GET "/calendar?from=2026-07-13&to=2026-07-19"
    Then every API calendar day is empty

  Scenario: The API calendar lists the posts and social posts the calendar page shows
    Given I am signed in to the admin
    And an API token
    And the published post "Morning" lands on the calendar on "2026-07-14" at "08:00"
    And the scheduled post "Evening" lands on the calendar on "2026-07-14" at "17:00"
    And the draft post "Draft" lands on the calendar on "2026-07-14" at "12:00"
    And the posted social post "Sent note" lands on the calendar on "2026-07-14" at "09:00"
    And the scheduled social post "Late note" lands on the calendar on "2026-07-18" at "23:30"
    When I call the API with GET "/calendar?from=2026-07-13&to=2026-07-19"
    Then the API calendar lists the posts and social posts the calendar page shows

  Scenario: The API calendar takes a range of up to 366 days
    Given an API token
    When I call the API with GET "/calendar?from=2026-07-13&to=2027-07-13"
    Then the API calendar lists 366 days
    When I call the API with GET "/calendar?from=2026-07-13&to=2027-07-14"
    Then the API answers with status 422
    And the calendar API answer holds:
      """
      { "errors": { "from": ["give a range of 366 days or fewer"], "to": ["give a range of 366 days or fewer"] } }
      """

  Scenario: The API calendar refuses a range it cannot read
    Given an API token
    When I call the API with GET "/calendar?from=2026-07-13&to=2026-07-12"
    Then the API answers with status 422
    And the calendar API answer holds:
      """
      { "errors": { "from": ["from comes after to"] } }
      """
    When I call the API with GET "/calendar?from=July&to=2026-07-19"
    Then the API answers with status 422
    When I call the API with GET "/calendar"
    Then the calendar API answer names errors on "from, to"

  Scenario: The API calendar describes each Google event
    Given an API token
    And the read-only calendar "Work" of "work@example.com"
    And the calendar event "Platform sync" in "Work" on "2026-07-14" from "14:00" to "15:00"
    And the calendar event "Platform sync" has:
      | place     | Room 4                                  |
      | meet_url  | https://meet.google.com/abc             |
      | notes     | Agenda                                  |
      | attendees | Dana                                    |
      | link      | https://calendar.google.com/event?eid=1 |
    And the all-day calendar event "On-call" in "Work" from "2026-07-14" to "2026-07-16"
    And I hide every calendar
    When I call the API with GET "/calendar?from=2026-07-13&to=2026-07-19"
    Then the API calendar titles the events per day:
      | 2026-07-14 | On-call, Platform sync |
      | 2026-07-16 | On-call                |
      | 2026-07-17 |                        |
    And the API calendar day "2026-07-14" holds:
      """
      {
        "events": [
          { "all_day": true, "starts_at": null, "ends_at": null, "ends_on": "2026-07-16" },
          {
            "title": "Platform sync",
            "calendar": { "id": <calendar Work>, "name": "Work", "account": "work@example.com" },
            "all_day": false, "starts_on": "2026-07-14", "ends_on": "2026-07-14",
            "starts_at": "2026-07-14T19:00:00Z", "ends_at": "2026-07-14T20:00:00Z",
            "place": "Room 4", "meet_url": "https://meet.google.com/abc", "attendees": ["Dana"],
            "notes": "Agenda", "link": "https://calendar.google.com/event?eid=1"
          }
        ]
      }
      """

  Scenario: The MCP tool list_calendar answers as the API does
    Given I am signed in to the admin
    And an API token
    And an empty sprint lands on the calendar on "2026-07-13"
    And the published post "Calendar post" lands on the calendar on "2026-07-15" at "09:00"
    And the posted social post "Calendar note" lands on the calendar on "2026-07-16" at "08:00"
    And a journal entry lands on the calendar on "2026-07-17"
    And the read-only calendar "Work" of "work@example.com"
    And the calendar event "Platform sync" in "Work" on "2026-07-14" from "14:00" to "15:00"
    And the calendar event "Platform sync" has:
      | place | Room 4 |
      | notes | Agenda |
    And the all-day calendar event "On-call" in "Work" from "2026-07-14" to "2026-07-16"
    When an MCP client connects with the scopes "read" and I approve it
    Then the MCP tool list_calendar answers as the API does from "2026-07-13" to "2026-07-19"
    When I call the calendar MCP tool "list_calendar" with:
      """
      { "from": "2026-07-13", "to": "2027-07-14" }
      """
    Then the calendar MCP tool refuses

  Scenario: The API writes events to Google under the write and delete scopes
    Given the Google account "me@example.com" is connected with "calendar.events calendar.calendarlist.readonly"
    And the calendar "Aaron" of "me@example.com"
    And the all-day calendar event "Standup" in "Aaron" from "2026-07-19" to "2026-07-19"
    And Google Calendar takes writes to the calendar "Aaron"
    And an API token with the scopes "read write"
    When I call the calendar API with POST "/calendar/events" and:
      """
      { "calendar_id": <calendar Aaron>, "title": "Trip", "date": "2026-07-19", "all_day": true }
      """
    Then the API answers with status 201
    And the calendar API answer is:
      """
      { "calendar_id": <calendar Aaron>, "created": true }
      """
    And the calendar sync was queued
    When I call the calendar API with DELETE "/calendar/events/<event Standup>"
    Then the API answers with status 403
    And Google Calendar got no DELETE "standup" in "Aaron"
    Given an API token with the scopes "read delete"
    When I call the calendar API with PATCH "/calendar/events/<event Standup>" and:
      """
      { "title": "Retro" }
      """
    Then the API answers with status 403
    Given an API token with the scopes "read write delete"
    When I call the calendar API with DELETE "/calendar/events/<event Standup>"
    Then the calendar API answer is:
      """
      { "id": <event Standup>, "deleted": true }
      """
    And Google Calendar got DELETE "standup" in "Aaron"
