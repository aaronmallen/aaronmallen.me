Feature: Today's calendar
  The admin's today page shows a card with the day's events: what has ended, what runs now and
  how soon the next one starts. Events built around now that would cross midnight are left out,
  and the checks that lean on them pass over them.

  Background:
    Given I am signed in to the admin
    And the calendar "Aaron" of "me@example.com"

  Scenario: The card lists the day's events around now
    Given the calendar event "Breakfast" in "Aaron" runs from -90 to -60 minutes from now
    And the calendar event "Standup" in "Aaron" runs from -30 to 30 minutes from now
    And the calendar event "Review" in "Aaron" runs from 12 to 40 minutes from now
    And the calendar event "Lunch" in "Aaron" runs from 180 to 240 minutes from now
    And the all-day calendar event "Holiday" in "Aaron" from "today" to "today"
    When I visit the admin
    Then the today calendar lists "Holiday, Standup, Review, Lunch"
    And the today calendar folds "Breakfast" under "1 earlier"
    And the today calendar marks "Breakfast" as past
    And the today calendar tally reads "3 of 4 left"
    And the today calendar marks "Standup" as now
    And the today calendar shows "Standup" as running now
    And the today calendar does not show "Lunch" as running now
    And the today calendar marks "Review" as next
    And the today calendar counts down "in 12m" for "Review"
    And the today calendar counts down nothing for "Lunch"
    And the today calendar times "Holiday" as "all day"
    And the today calendar links "week →" to "/admin/calendar"
    And the page has no axe breaches in light or dark

  Scenario: The card counts hours and minutes under three hours
    Given the calendar event "Planning" in "Aaron" runs from 135 to 180 minutes from now
    When I visit the admin
    Then the today calendar counts down "in 2h 15m" for "Planning"

  Scenario: The card counts nothing down three hours out or more
    Given the calendar event "Planning" in "Aaron" runs from 185 to 200 minutes from now
    When I visit the admin
    Then the today calendar counts down nothing for "Planning"

  Scenario: The card reads clear with no events
    When I visit the admin
    Then the today calendar says "Nothing on the calendar today."
    And the today calendar tally reads "clear"

  Scenario: The card reads clear with only all-day events
    Given the all-day calendar event "Holiday" in "Aaron" from "today" to "today"
    When I visit the admin
    Then the today calendar tally reads "clear"

  Scenario: Once the day is done the card names tomorrow's first timed event
    Given the calendar event "Breakfast" in "Aaron" runs from -90 to -60 minutes from now
    And the all-day calendar event "Holiday" in "Aaron" from "today + 1" to "today + 1"
    And the calendar event "Late" in "Aaron" on "today + 1" from "15:00" to "16:00"
    And the calendar event "Dentist" in "Aaron" on "today + 1" from "09:00" to "09:45"
    When I visit the admin
    Then the today calendar says "Done for the day. First tomorrow: Dentist at 09:00."

  Scenario: Once the day is done with nothing tomorrow the card says so alone
    Given the calendar event "Breakfast" in "Aaron" runs from -90 to -60 minutes from now
    When I visit the admin
    Then the today calendar says "Done for the day."

  Scenario: The card hides the events of calendars hidden on the calendar page
    Given the hidden calendar "Hidden" of "me@example.com"
    And the calendar event "Secret" in "Hidden" runs from 60 to 120 minutes from now
    And the calendar event "Standup" in "Aaron" runs from 60 to 120 minutes from now
    When I visit the admin
    Then the today calendar lists "Standup"

  Scenario: A row on the card opens to the event's details
    # The event has ended after 23:30, and the card folds it under the earlier events.
    Given the calendar event "Coffee with Sean" in "Aaron" on "today" from "23:00" to "23:30"
    And the calendar event "Coffee with Sean" has:
      | place     | Sawada Coffee                           |
      | meet_url  | https://meet.google.com/abc             |
      | notes     | Talk about Hanami                       |
      | attendees | Sean                                    |
      | link      | https://calendar.google.com/event?eid=1 |
    And the all-day calendar event "Trip" in "Aaron" from "today - 1" to "today + 2"
    When I visit the admin
    Then the today calendar event "Coffee with Sean" reads "Aaron23:00–23:30Sawada Coffee"
    And the today calendar event "Trip" reads "Aaronuntil <today + 2 short>"
    And the today calendar event "Coffee with Sean" joins at "https://meet.google.com/abc"
    And the today calendar event "Coffee with Sean" opens to:
      """
      Talk about Hanami
      Sean
      me@example.com
      """
    And the today calendar event "Coffee with Sean" offers the buttons:
      | Join Meet       | https://meet.google.com/abc                             |
      | Prep task       | /admin/tasks/new?origin=today&title=Coffee%20with%20Sean |
      | Google Calendar | https://calendar.google.com/event?eid=1                 |
    When I prep a task from the today calendar event "Coffee with Sean"
    Then the new task dialog holds the title "Coffee with Sean"

  Scenario: The new task page takes its title from the address
    When I visit "/admin/tasks/new?title=Coffee%20with%20Sean"
    Then the new task page holds the title "Coffee with Sean"
