Feature: Admin event stream
  The admin event stream tells each open admin page which tables changed, so the page can refresh.

  Background:
    Given I am signed in to the admin

  Scenario: The admin event stream answers as an event stream that retries
    When I open 1 admin event stream
    Then each admin event stream hears "retry: 2000"

  Scenario: Every open admin event stream hears a change to an admin table
    When I open 2 admin event streams
    And the database runs:
      """
      insert into tags (name, color, scope) values ('ruby', 'mk-blue', 'public')
      """
    Then each admin event stream hears "event: change\ndata: tags\n\n"

  Scenario: An admin event stream catches up when the hub's database connection comes back
    When I open 1 admin event stream
    And the database drops the admin hub's connection
    Then each admin event stream hears "event: change\ndata: *\n\n"
