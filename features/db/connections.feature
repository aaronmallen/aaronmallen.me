Feature: Database connections
  The server and the worker ride out dropped database connections, a web request's query stops at the
  statement timeout while a job's query waits, and each request leaves a timing row.

  Scenario: The site answers the next request after the database drops its connections
    When I visit the home page
    And the database drops the app's connections
    Then the home page answers 200

  Scenario: The worker runs the next job after the database drops its connections
    Given a post "Due now" scheduled for an hour ago
    When the database drops the app's connections
    And the due posts job runs
    Then the home page lists "Due now"

  Scenario: A request writes its timing row once the response finishes
    When I visit the home page
    Then the database soon answers "GET / 200" for:
      """
      select verb, route, status from performance_requests where route <> '/pulse'
      """

  Scenario: A new database connection has no statement timeout, as migrations need
    Then the database answers "0" for:
      """
      show statement_timeout
      """

  @slow
  Scenario: A web request's query stops at 15 seconds and still writes its timing row, while a job's query waits
    Given a post "Due now" scheduled for an hour ago
    And another session locks the posts table
    When the due posts job runs
    And I ask for "/writing"
    Then it answers 500 after 15 seconds
    When the other session lets the posts table go
    Then the home page lists "Due now"
    And the database soon answers "GET /writing 500" for:
      """
      select verb, route, status from performance_requests where route = '/writing'
      """
