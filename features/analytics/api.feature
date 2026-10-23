Feature: Reading analytics through the API
  The JSON API answers what read_analytics answers, with no untrusted marks.

  Background:
    Given an API token

  Scenario: The analytics API adds up the site's days and names each top path plainly
    Given these analytics_rollups rows:
      | day     | views | visitors | read_seconds |
      | today-1 | 50    | 30       | 500          |
    And these analytics_rollup_paths rows:
      | day     | path          | views | visitors | bounces |
      | today-1 | /writing/loud | 40    | 20       | 0       |
    And an MCP client connected with the scopes "read"
    When I get "/analytics?from={today-6}&to={today}" from the API
    Then the API answers 200
    And the answer at "totals" is:
      """
      {"views": 50, "visitors": 30, "read_seconds": 500, "read_throughs": 0, "reach": 0}
      """
    And the answer holds:
      """
      {"paths": [{"path": "/writing/loud", "views": 40}]}
      """
    And the answer is what read_analytics answers with "{\"from\": \"{today-6}\", \"to\": \"{today}\"}", less the untrusted marks

  Scenario: The analytics API reads one page alone
    When I get "/analytics?from={today-6}&to={today}&path=/writing/hello" from the API
    Then the API answers 200
    And the answer holds:
      """
      {"path": "/writing/hello", "clicks": []}
      """

  Scenario Outline: The analytics API refuses a range it cannot read with a 422
    When I get "/analytics?<query>" from the API
    Then the API answers 422
    And the answer holds:
      """
      {"message": "<refusal>"}
      """

    Examples:
      | query                                                 | refusal                                                            |
      | from={today-6}&to={today}&since=this%20morning        | give since as an ISO 8601 time, such as 2026-10-01T09:00:00-05:00 |
      | from={today-400}&to={today}                           | give a range of 366 days or fewer                                  |
