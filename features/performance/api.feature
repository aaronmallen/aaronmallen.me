Feature: Reading performance through the API
  The JSON API and read_performance give the same p50, p95 and counts for
  routes, jobs and browser metrics.

  Scenario: The performance API ranks the routes and jobs by p95
    Given these performance_requests rows:
      | route    | verb | duration | query_count | query_time | occurred_at   |
      | /writing | GET  | 10       | 2           | 0.25       | today-1 12:00 |
      | /writing | GET  | 20       | 2           | 0.25       | today-1 12:00 |
      | /writing | GET  | 30       | 2           | 0.25       | today-1 12:00 |
      | /writing | GET  | 40       | 2           | 0.25       | today-1 12:00 |
      | /writing | POST | 90       | 2           | 0.3        | today-1 12:00 |
    And these performance_jobs rows:
      | job        | duration | occurred_at   |
      | Spec::Fast | 5        | today-1 12:00 |
      | Spec::Job  | 100      | today-1 12:00 |
      | Spec::Job  | 200      | today-1 12:00 |
    And an API token with the scopes "read"
    When I get "/performance?from={today-1}&to={today-1}" from the API
    Then the API answers 200
    And the answer at "routes" is:
      """
      [
        {"route": "/writing", "verb": "POST", "count": 1, "p50": 90.0, "p95": 90.0, "query_count": 2, "query_time": 0.3},
        {"route": "/writing", "verb": "GET", "count": 4, "p50": 25.0, "p95": 38.5, "query_count": 8, "query_time": 1.0}
      ]
      """
    And the answer at "jobs" is:
      """
      [
        {"job": "Spec::Job", "count": 2, "p50": 150.0, "p95": 195.0, "query_count": 6, "query_time": 3.0},
        {"job": "Spec::Fast", "count": 1, "p50": 5.0, "p95": 5.0, "query_count": 3, "query_time": 1.5}
      ]
      """

  Scenario: The performance API gives each page's browser figures
    Given these performance_pages rows:
      | route    | load | lcp  | occurred_at   |
      | /        | 500  | 300  | today-1 12:00 |
      | /writing | 900  | none | today-1 12:00 |
    And an API token with the scopes "read"
    When I get "/performance?from={today-1}&to={today-1}" from the API
    Then the answer at "pages" is:
      """
      [
        {"route": "/writing", "load": {"count": 1, "p50": 900.0, "p95": 900.0}, "lcp": null,
          "ttfb": {"count": 1, "p50": 10.0, "p95": 10.0}, "dom_content_loaded": {"count": 1, "p50": 20.0, "p95": 20.0}},
        {"route": "/", "load": {"count": 1, "p50": 500.0, "p95": 500.0}, "lcp": {"count": 1, "p50": 300.0, "p95": 300.0},
          "ttfb": {"count": 1, "p50": 10.0, "p95": 10.0}, "dom_content_loaded": {"count": 1, "p50": 20.0, "p95": 20.0}}
      ]
      """

  Scenario: The performance API weighs a rolled up day and today's raw rows by their counts
    Given these performance_requests rows:
      | route    | duration | query_time | occurred_at   |
      | /writing | 10       | 0.25       | today-1 12:00 |
      | /writing | 10       | 0.25       | today-1 12:00 |
      | /writing | 10       | 0.25       | today-1 12:00 |
    And the job "Performance::Jobs::RollUpTiming" runs
    And these performance_requests rows:
      | route    | duration | query_time | occurred_at |
      | /writing | 50       | 0.25       | today 00:00 |
    And an API token with the scopes "read"
    When I get "/performance?from={today-1}&to={today}" from the API
    Then the answer holds:
      """
      {"routes": [{"route": "/writing", "count": 4, "p50": 20.0, "p95": 20.0, "query_count": 8}]}
      """

  Scenario: The performance API leaves out timing from outside the range
    Given these performance_requests rows:
      | duration | query_time | occurred_at   |
      | 10       | 1          | today-2 12:00 |
    And these performance_jobs rows:
      | duration | occurred_at   |
      | 10       | today-2 12:00 |
    And these performance_pages rows:
      | load | occurred_at   |
      | 100  | today-2 12:00 |
    And an API token with the scopes "read"
    When I get "/performance?from={today-1}&to={today-1}" from the API
    Then the answer holds:
      """
      {"from": "{today-1}", "to": "{today-1}", "routes": [], "jobs": [], "pages": []}
      """

  Scenario: The performance API refuses a range that runs backwards
    Given an API token with the scopes "read"
    When I get "/performance?from={today}&to={today-1}" from the API
    Then the API answers 422

  Scenario: The performance API refuses a token without the read scope
    Given an API token with the scopes "write"
    When I get "/performance?from={today}&to={today}" from the API
    Then the API answers 403

  Scenario: read_performance answers with the same figures as the API
    Given these performance_requests rows:
      | duration | query_time | occurred_at   |
      | 10       | 1          | today-1 12:00 |
    And these performance_jobs rows:
      | duration | occurred_at   |
      | 20       | today-1 12:00 |
    And these performance_pages rows:
      | load | lcp | occurred_at   |
      | 300  | 200 | today-1 12:00 |
    And an API token with the scopes "read"
    And an MCP client connected with the scopes "read"
    When I get "/performance?from={today-1}&to={today-1}" from the API
    Then the answer is what read_performance answers with "{\"from\": \"{today-1}\", \"to\": \"{today-1}\"}"
