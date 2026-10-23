Feature: Admin live updates
  Each open admin page holds an event stream that says which table changed, so the page can
  fetch what is new.

  Scenario: The admin answers a signed in owner with an event stream
    Given I am signed in to the admin
    When 1 admin event streams open
    Then the admin event stream answers as an event stream

  Scenario: The admin turns away a visitor who has not signed in
    When a visitor opens the admin event stream
    Then the admin event stream answers with status 401

  Scenario: Every open stream hears when tasks change
    Given I am signed in to the admin
    When 2 admin event streams open
    And a task lands in the backlog beside the calendar
    Then every admin event stream hears a change to "tasks"

  Scenario: Every open stream hears about a new mail thread
    Given I am signed in to the admin
    When 2 admin event streams open
    And a mail thread arrives beside the calendar
    Then every admin event stream hears a change to "mail_threads"

  Scenario: Every open stream hears about a new webmention
    Given I am signed in to the admin
    When 2 admin event streams open
    And a webmention arrives beside the calendar
    Then every admin event stream hears a change to "webmentions"

  Scenario: The admin serves pages while more streams are open than it has threads
    Given I am signed in to the admin
    When 6 admin event streams open
    Then the admin inbox still loads

  Scenario: A browser page hears changes through an event source
    Given I am signed in to the admin
    When I listen for admin changes in the browser
    And a mail thread arrives beside the calendar
    Then the browser hears a change to "mail_threads"
