Feature: The calendar on the Today page
  The Calendar card lists today's events: all-day events first, then the timed ones still to come, with the ended
  ones folded away. Each row opens to its notes, its guests and buttons to join, prep or open it.

  Background:
    Given I am signed in to the admin
    And the country database holds the test networks

  Scenario: The calendar card links to the Calendar page
    When I visit "/admin"
    Then the calendar card links "week →" to "/admin/calendar"

  Scenario: A day with events lists what is left and folds away what ended
    Given these calendar events for the Today page:
      | title     | starts | ends |
      | Breakfast | -20m   | -10m |
      | Lunch     | +50m   | +60m |
      | Review    | +12m   | +40m |
      | Standup   | -5m    | +30m |
      | Holiday   |        |      |
    When I visit "/admin"
    Then the calendar card shows "Holiday, Standup, Review, Lunch"
    And the calendar card folds "Breakfast" under "1 earlier"
    And the calendar row "Breakfast" is "past"
    And the calendar card tally reads "3 of 4 left"
    And the calendar row "Standup" is "now"
    And the calendar row "Standup" is marked now
    And the calendar row "Lunch" is not marked now
    And the calendar row "Review" is "next"
    And the calendar row "Review" counts down "in 12m"
    And the calendar row "Lunch" shows no countdown
    And the calendar row "Holiday" starts "all day"

  Scenario: The countdown gives hours and minutes under three hours
    Given the Chicago day has at least 4 hours left
    And these calendar events for the Today page:
      | title    | starts  | ends |
      | Planning | +2h 15m | +3h  |
    When I visit "/admin"
    Then the calendar row "Planning" counts down "in 2h 15m"

  Scenario: The countdown stays blank three hours out or more
    Given the Chicago day has at least 5 hours left
    And these calendar events for the Today page:
      | title    | starts | ends |
      | Planning | +3h    | +4h  |
    When I visit "/admin"
    Then the calendar row "Planning" shows no countdown

  Scenario: A day with no events says the calendar is empty and reads clear
    When I visit "/admin"
    Then the calendar card says "Nothing on the calendar today."
    And the calendar card tally reads "clear"

  Scenario: A day with only all-day events reads clear
    Given these calendar events for the Today page:
      | title   |
      | Holiday |
    When I visit "/admin"
    Then the calendar card tally reads "clear"

  Scenario: Once the day is done the card names tomorrow's first timed event
    Given these calendar events for the Today page:
      | title     | starts | ends  | day |
      | Breakfast | -2m    | -1m   | 0   |
      | Holiday   |        |       | 1   |
      | Late      | 15:00  | 16:00 | 1   |
      | Dentist   | 09:00  | 09:45 | 1   |
    When I visit "/admin"
    Then the calendar card notes "Done for the day. First tomorrow: Dentist at 09:00."

  Scenario: Once the day is done the card says so alone with nothing tomorrow
    Given these calendar events for the Today page:
      | title     | starts | ends |
      | Breakfast | -2m    | -1m  |
    When I visit "/admin"
    Then the calendar card notes "Done for the day."

  Scenario: The card leaves out calendars hidden on the Calendar page
    Given these calendar events for the Today page:
      | title   | starts | ends | calendar |
      | Secret  | +1h    | +2h  | Hidden   |
      | Standup | +1h    | +2h  | Aaron    |
    When I visit "/admin"
    Then the calendar card shows "Standup"

  Scenario: A calendar row shows its details and the buttons to act on it
    Given these calendar events for the Today page:
      | title            | starts | ends  | place         | meet                        | notes             | guests | link                                   | until |
      | Coffee with Sean | 11:00  | 12:00 | Sawada Coffee | https://meet.google.com/abc | Talk about Hanami | Sean   | https://calendar.google.com/event?eid=1 |       |
    And the database runs:
      """
      insert into calendar_events (calendar_id, google_id, title, starts_on, ends_on)
      select id, 'trip', 'Trip', (now() at time zone 'America/Chicago')::date - 1, (now() at time zone 'America/Chicago')::date + 2
      from calendars where name = 'Aaron';
      """
    When I visit "/admin"
    Then the calendar row "Coffee with Sean" reads "Aaron11:00–12:00Sawada Coffee"
    And the calendar row "Trip" reads "Aaronuntil <today+2>"
    And the calendar row "Coffee with Sean" joins at "https://meet.google.com/abc"
    And the calendar row "Coffee with Sean" opens to "Talk about Hanami, Sean, me@example.com"
    And the calendar row "Coffee with Sean" offers the buttons:
      | Join Meet       | https://meet.google.com/abc                          |
      | Prep task       | /admin/tasks/new?origin=today&title=Coffee%20with%20Sean |
      | Google Calendar | https://calendar.google.com/event?eid=1              |
    And the calendar row "Coffee with Sean" preps a task titled "Coffee with Sean" in the dialog "task-create"

  Scenario: The new task page fills the title it is given
    When I visit "/admin/tasks/new?title=Coffee%20with%20Sean"
    Then the Today new task form's title holds "Coffee with Sean"
