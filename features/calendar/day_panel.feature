Feature: Calendar day panel in place
  A click on a day opens its panel without loading the whole page.

  Background:
    Given I am signed in to the admin
    And the scheduled post "A post on its day" lands on the calendar on "2026-07-14" at "09:00"
    When I open the calendar month "2026-07"
    And I mark the calendar page
    And I open the calendar day "2026-07-14" in place

  Scenario: A click on a day opens its panel in place
    Then the calendar day panel links "A post on its day" to "/admin/posts/<post A post on its day>/edit"
    And the calendar page is still the one I marked
    And the calendar shows the address "/admin/calendar?day=2026-07-14"
    And the calendar marks only "2026-07-14" as picked
    And the calendar day panel has focus

  Scenario: Deleting an event on a day opened in place asks first
    Given the calendar "Aaron" of "me@example.com"
    And the all-day calendar event "Coffee" in "Aaron" from "2026-07-15" to "2026-07-15"
    When I open the calendar day "2026-07-15" in place
    And I ask to delete the calendar event "Coffee"
    Then the calendar asks "Delete Coffee from Google Calendar?"

  Scenario: A later day keeps the panel when an earlier day answers after it
    Then the calendar day panel is for "2026-07-14"
    When the calendar holds back the panel for "2026-07-15"
    And I open the calendar day "2026-07-15" in place
    And the calendar asks for the held panel
    And I open the calendar day "2026-07-16" in place
    Then the calendar day panel is for "2026-07-16"
    When the held calendar panel arrives
    Then the calendar day panel is for "2026-07-16"
    And the calendar shows the address "/admin/calendar?day=2026-07-16"
