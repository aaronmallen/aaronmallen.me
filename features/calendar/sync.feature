Feature: Calendar sync
  A job reads each connected Google account's calendars and their events into a mirror the
  admin, the API and MCP read from. It reads from 90 days back to a year ahead.

  Background:
    Given the Google account "me@example.com" is connected with "calendar.events calendar.calendarlist.readonly"

  Scenario: A sync keeps each calendar and event Google lists
    Given Google Calendar lists the calendars:
      """
      [
        { "id": "me@example.com", "summary": "Aaron", "accessRole": "owner" },
        { "id": "holidays", "summary": "Holidays", "summaryOverride": "Days off", "accessRole": "reader" },
        { "id": "busy", "summary": "Busy", "accessRole": "freeBusyReader" }
      ]
      """
    And Google Calendar lists the events of "me@example.com":
      """
      {
        "items": [
          {
            "id": "coffee_1", "summary": "Coffee",
            "start": { "dateTime": "<today at 09:00>" }, "end": { "dateTime": "<today at 10:00>" },
            "location": "Lakeview", "hangoutLink": "https://meet.google.com/abc", "description": "Bring notes",
            "htmlLink": "https://calendar.google.com/event?eid=1",
            "attendees": [
              { "email": "me@example.com", "self": true },
              { "email": "dana@example.com", "displayName": "Dana" },
              { "email": "sam@example.com" },
              { "email": "room@resource.calendar.google.com", "resource": true }
            ]
          },
          {
            "id": "standup_1", "summary": "Standup", "recurringEventId": "standup",
            "start": { "dateTime": "<today at 11:00>" }, "end": { "dateTime": "<today at 11:30>" }
          },
          {
            "id": "late", "summary": "Late",
            "start": { "dateTime": "<today at 22:00>" }, "end": { "dateTime": "<today + 1 at 00:00>" }
          }
        ]
      }
      """
    And Google Calendar lists the events of "holidays":
      """
      { "items": [{ "id": "oncall", "summary": "On-call", "start": { "date": "<today + 1>" }, "end": { "date": "<today + 8>" } }] }
      """
    When the calendar sync runs
    Then the calendar sync records no failure
    And the calendar mirror holds the calendars:
      | me@example.com | Aaron    | true  |
      | me@example.com | Days off | false |
    And the calendar mirror holds the events:
      | google_id | title   | starts_on | ends_on   | starts_at        | ends_at              | place    | meet_url                    | attendees              | notes       | link                                    | recurring_id |
      | coffee_1  | Coffee  | today     | today     | today at 09:00   | today at 10:00       | Lakeview | https://meet.google.com/abc | Dana, sam@example.com  | Bring notes | https://calendar.google.com/event?eid=1 |              |
      | late      | Late    | today     | today     | today at 22:00   | today + 1 at 00:00   |          |                             |                        |             |                                         |              |
      | oncall    | On-call | today + 1 | today + 7 |                  |                      |          |                             |                        |             |                                         |              |
      | standup_1 | Standup | today     | today     | today at 11:00   | today at 11:30       |          |                             |                        |             |                                         | standup      |

  Scenario: A work account's calendars take no writes even where Google grants them
    Given the calendar account "me@example.com" is a work account
    And Google Calendar lists the calendars:
      """
      [{ "id": "me@example.com", "summary": "Day job", "accessRole": "owner" }]
      """
    And Google Calendar lists the events of "me@example.com":
      """
      { "items": [] }
      """
    When the calendar sync runs
    Then the calendar mirror holds the calendars:
      | me@example.com | Day job | false |

  Scenario: A second run updates what changed and drops what Google dropped
    Given Google Calendar lists the calendars:
      """
      [{ "id": "me@example.com", "summary": "Aaron", "accessRole": "owner" }]
      """
    And Google Calendar lists the events of "me@example.com":
      """
      {
        "items": [
          { "id": "kept", "summary": "Standup", "start": { "dateTime": "<today at 09:00>" }, "end": { "dateTime": "<today at 10:00>" } },
          { "id": "gone", "summary": "Retro", "start": { "dateTime": "<today at 11:00>" }, "end": { "dateTime": "<today at 12:00>" } }
        ]
      }
      """
    When the calendar sync runs
    And I note the calendar event rows
    And I hide every calendar
    And the all-day calendar event "Old" in "Aaron" from "today - 200" to "today - 200"
    And Google Calendar lists the events of "me@example.com":
      """
      {
        "items": [
          { "id": "kept", "summary": "Moved standup", "start": { "dateTime": "<today at 09:00>" }, "end": { "dateTime": "<today at 10:00>" } }
        ]
      }
      """
    And the calendar sync runs
    Then the calendar mirror holds the events:
      | google_id | title         |
      | kept      | Moved standup |
    And the calendar event "kept" keeps the row I noted
    And every calendar in the mirror is hidden

  Scenario: A sync drops a calendar the account no longer lists, with its events
    Given Google Calendar lists the calendars:
      """
      [{ "id": "me@example.com", "summary": "Aaron", "accessRole": "owner" }]
      """
    And Google Calendar lists the events of "me@example.com":
      """
      { "items": [{ "id": "kept", "summary": "Standup", "start": { "dateTime": "<today at 09:00>" }, "end": { "dateTime": "<today at 10:00>" } }] }
      """
    When the calendar sync runs
    And Google Calendar lists the calendars:
      """
      []
      """
    And the calendar sync runs
    Then the calendar mirror holds no calendars
    And the calendar mirror holds no events

  Scenario: A sync drops the calendars of an account that no longer grants Calendar
    Given the calendar "Aaron" of "me@example.com"
    And the calendar account "me@example.com" no longer grants Calendar
    When the calendar sync runs
    Then the calendar mirror holds no calendars

  Scenario: A sync token from the last run asks Google only for what changed
    Given Google Calendar lists the calendars:
      """
      [{ "id": "me@example.com", "summary": "Aaron", "accessRole": "owner" }]
      """
    And Google Calendar lists the events of "me@example.com":
      """
      {
        "nextSyncToken": "first",
        "items": [
          { "id": "kept", "summary": "Standup", "start": { "dateTime": "<today at 09:00>" }, "end": { "dateTime": "<today at 10:00>" } },
          { "id": "gone", "summary": "Retro", "start": { "dateTime": "<today at 11:00>" }, "end": { "dateTime": "<today at 12:00>" } },
          { "id": "stay", "summary": "Lunch", "start": { "dateTime": "<today at 12:00>" }, "end": { "dateTime": "<today at 13:00>" } }
        ]
      }
      """
    When the calendar sync runs
    Then the calendar "me@example.com" holds the sync token "first"
    When I note the calendar event rows
    And Google Calendar lists the events of "me@example.com":
      """
      { "nextSyncToken": "next", "items": [] }
      """
    And the calendar sync runs
    Then the calendar event rows are as I noted them
    And the calendar "me@example.com" holds the sync token "next"
    When Google Calendar lists the events of "me@example.com":
      """
      {
        "nextSyncToken": "later",
        "items": [
          { "id": "kept", "summary": "Moved standup", "start": { "dateTime": "<today at 09:00>" }, "end": { "dateTime": "<today at 10:00>" } },
          { "id": "gone", "status": "cancelled" },
          { "id": "new", "summary": "Review", "start": { "dateTime": "<today at 14:00>" }, "end": { "dateTime": "<today at 15:00>" } }
        ]
      }
      """
    And the calendar sync runs
    Then the calendar mirror holds the events:
      | google_id | title         |
      | kept      | Moved standup |
      | new       | Review        |
      | stay      | Lunch         |

  Scenario: On a new day the sync reads the new window in full, then goes back to the token
    Given Google Calendar lists the calendars:
      """
      [{ "id": "me@example.com", "summary": "Aaron", "accessRole": "owner" }]
      """
    And Google Calendar lists the events of "me@example.com":
      """
      {
        "nextSyncToken": "first",
        "items": [
          { "id": "kept", "summary": "Standup", "start": { "dateTime": "<today at 09:00>" }, "end": { "dateTime": "<today at 10:00>" } },
          { "id": "stay", "summary": "Lunch", "start": { "dateTime": "<today at 12:00>" }, "end": { "dateTime": "<today at 13:00>" } }
        ]
      }
      """
    When the calendar sync runs
    And the last calendar sync ran a day ago
    And the all-day calendar event "Old" in "Aaron" from "today - 91" to "today - 91"
    And Google Calendar lists the events of "me@example.com":
      """
      {
        "nextSyncToken": "moved",
        "items": [
          { "id": "kept", "summary": "Standup", "start": { "dateTime": "<today at 09:00>" }, "end": { "dateTime": "<today at 10:00>" } },
          { "id": "standup_last", "summary": "Standup", "recurringEventId": "standup", "start": { "dateTime": "<today + 365 at 09:00>" }, "end": { "dateTime": "<today + 365 at 10:00>" } }
        ]
      }
      """
    And the calendar sync runs
    Then the calendar mirror holds the events:
      | google_id    | starts_on   |
      | kept         | today       |
      | standup_last | today + 365 |
    And the calendar "me@example.com" holds the sync token "moved"
    When Google Calendar lists the events of "me@example.com":
      """
      { "nextSyncToken": "later", "items": [] }
      """
    And the calendar sync runs
    Then the calendar mirror holds the events:
      | google_id    |
      | kept         |
      | standup_last |
    And the calendar "me@example.com" holds the sync token "later"

  Scenario: An event that has not changed sends the admin no notice
    Given Google Calendar lists the calendars:
      """
      [{ "id": "me@example.com", "summary": "Aaron", "accessRole": "owner" }]
      """
    And Google Calendar lists the events of "me@example.com":
      """
      { "items": [{ "id": "kept", "summary": "Standup", "start": { "dateTime": "<today at 09:00>" }, "end": { "dateTime": "<today at 10:00>" } }] }
      """
    When the calendar sync runs
    And I listen for admin changes from the calendar sync
    And the calendar sync runs
    Then the calendar sync told the admin of no calendar change

  Scenario: One account failing leaves the others to sync and records the failure
    Given the Google account "work@example.com" is connected with "calendar.events calendar.calendarlist.readonly"
    And the calendar account "work@example.com" holds an expired token
    And Google OAuth answers POST "/token" with status 503
    And Google Calendar lists the calendars:
      """
      [{ "id": "me@example.com", "summary": "Aaron", "accessRole": "owner" }]
      """
    And Google Calendar lists the events of "me@example.com":
      """
      { "items": [] }
      """
    When the calendar sync runs
    Then the calendar sync records the failure "google_calendar_failed" saying "Google answered 503"
    And the calendar mirror holds the calendars:
      | me@example.com | Aaron | true |

  Scenario: A sync leaves an account without Calendar alone
    Given the Google account "health@example.com" is connected with "googlehealth.sleep.readonly"
    And the calendar account "me@example.com" no longer grants Calendar
    When the calendar sync runs
    Then Google Calendar received no GET "/users/me/calendarList"
    And the calendar mirror holds no calendars
    And the calendar sync records no failure

  Scenario: A revoked account keeps its calendars and records no failure
    Given the calendar "Aaron" of "me@example.com"
    And the calendar account "me@example.com" was revoked
    When the calendar sync runs
    Then the calendar sync records no failure
    And the calendar mirror holds the calendars:
      | me@example.com | Aaron | true |

  Scenario: A run that succeeds clears the last failure
    Given a calendar sync failed with "google_calendar_failed"
    And Google Calendar lists the calendars:
      """
      []
      """
    When the calendar sync runs
    Then the calendar sync records no failure

  Scenario: A run that crashes records the crash where the admin reads it
    Given Google Calendar lists the calendars:
      """
      [{ "id": "me@example.com", "summary": "Aaron", "accessRole": "owner" }]
      """
    And Google Calendar lists the events of "me@example.com":
      """
      { "items": [{ "summary": "No id", "start": { "date": "<today>" }, "end": { "date": "<today + 1>" } }] }
      """
    When the calendar sync runs
    Then the calendar sync records the failure "crashed" saying "key not found: \"id\""

  Scenario: A run steps aside while another holds the lock
    Given a calendar sync failed with "rate_limited"
    And another calendar sync holds the lock
    When the calendar sync runs beside it
    Then Google Calendar received no GET "/users/me/calendarList"
    And the calendar sync records the failure "rate_limited" once
