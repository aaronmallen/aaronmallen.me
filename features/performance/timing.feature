Feature: Timing requests, pages and jobs
  The site times each request it serves, each page a browser loads and each
  Sidekiq job it runs, and keeps the rows on this server.

  Scenario: A visitor's request stores its route, verb, status, time and queries
    Given these analytics posts:
      | slug  | published |
      | hello | today-1   |
    When a visitor fetches "/writing/hello"
    Then the performance_requests table holds 1 rows where "route = '/writing/:slug' AND verb = 'GET' AND status = 200 AND duration > 0 AND query_count > 0 AND query_time >= 0"

  Scenario: The owner's admin request stores the admin route
    Given I am signed in to the admin
    When I visit "/admin/tasks"
    Then the performance_requests table holds 1 rows where "route = '/admin/tasks' AND verb = 'GET' AND status = 200"

  Scenario: An agent's API request stores the API route
    Given an API token
    When I get "/attention" from the API
    Then the performance_requests table holds 1 rows where "route = '/api/v1/attention' AND verb = 'GET' AND status = 200"

  Scenario: A client's MCP call stores the MCP route
    When a client posts a JSON-RPC tools list to "/mcp"
    Then the performance_requests table holds 1 rows where "route = '/mcp' AND verb = 'POST'"

  Scenario: A request nothing serves stores no route
    When a visitor fetches "/nothing/here"
    Then the performance_requests table holds 1 rows where "route IS NULL AND status = 404"

  Scenario: A timing row that fails to write still answers and logs the loss
    Given the database refuses to insert performance_requests rows
    When a visitor fetches "/"
    Then the server answered 200
    When a visitor fetches "/"
    Then the server answered 200
    And the server log mentions "Timing row lost"
    And the performance_requests table holds 0 rows

  Scenario: A read that carries the page's timing stores it with the route and device class
    Given these analytics posts:
      | slug  | published |
      | hello | today-1   |
    When "an iPhone" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello", "view_token": "0123456789abcdef0123456789abcdef"}
      """
    And "an iPhone" sends the beacon:
      """
      {"kind": "read", "path": "/writing/hello", "read_seconds": 42, "view_token": "0123456789abcdef0123456789abcdef",
        "timing": {"ttfb": 120, "dom_content_loaded": 480, "load": 910, "lcp": 640}}
      """
    Then the server answered 202
    And the performance_pages rows are:
      | route          | device_class | ttfb | dom_content_loaded | load | lcp |
      | /writing/:slug | mobile       | 120  | 480                | 910  | 640 |
    And the performance_pages table has the columns "id, route, device_class, ttfb, dom_content_loaded, load, lcp, occurred_at, created_at, updated_at"
    And the analytics_events rows are:
      | read_seconds |
      | 42           |

  Scenario: A browser with no LCP stores its timing without one
    Given these analytics posts:
      | slug  | published |
      | hello | today-1   |
    When "an iPhone" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello", "view_token": "0123456789abcdef0123456789abcdef"}
      """
    And "an iPhone" sends the beacon:
      """
      {"kind": "read", "path": "/writing/hello", "read_seconds": 42, "view_token": "0123456789abcdef0123456789abcdef",
        "timing": {"ttfb": 120, "dom_content_loaded": 480, "load": 910}}
      """
    Then the performance_pages rows are:
      | load | lcp  |
      | 910  | none |

  Scenario: A read with no timing stores no timing
    Given these analytics posts:
      | slug  | published |
      | hello | today-1   |
    When "an iPhone" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello", "view_token": "0123456789abcdef0123456789abcdef"}
      """
    And "an iPhone" sends the beacon:
      """
      {"kind": "read", "path": "/writing/hello", "read_seconds": 42, "view_token": "0123456789abcdef0123456789abcdef"}
      """
    Then the server answered 202
    And the performance_pages table holds 0 rows

  Scenario Outline: A read with nonsense timing keeps the read and stores no timing
    Given these analytics posts:
      | slug  | published |
      | hello | today-1   |
    When "an iPhone" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello", "view_token": "0123456789abcdef0123456789abcdef"}
      """
    And "an iPhone" sends the beacon:
      """
      {"kind": "read", "path": "/writing/hello", "read_seconds": 42, "view_token": "0123456789abcdef0123456789abcdef", "timing": <timing>}
      """
    Then the server answered 202
    And the analytics_events rows are:
      | read_seconds |
      | 42           |
    And the performance_pages table holds 0 rows

    Examples:
      | case                    | timing                                                           |
      | no object               | "fast"                                                           |
      | a missing load          | {"ttfb": 120, "dom_content_loaded": 480}                         |
      | a fraction of a ms      | {"ttfb": 120.4, "dom_content_loaded": 480, "load": 910}          |
      | a time in words         | {"ttfb": "soon", "dom_content_loaded": 480, "load": 910}         |
      | a negative time         | {"ttfb": -5, "dom_content_loaded": 480, "load": 910}             |
      | times out of order      | {"ttfb": 120, "dom_content_loaded": 910, "load": 480}            |
      | a time past ten minutes | {"ttfb": 120, "dom_content_loaded": 480, "load": 600001}         |
      | a negative LCP          | {"ttfb": 120, "dom_content_loaded": 480, "load": 910, "lcp": -1} |

  Scenario Outline: A read from a bot or one that matches no view stores no timing
    Given these analytics posts:
      | slug  | published |
      | hello | today-1   |
    When "<agent>" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello", "view_token": "0123456789abcdef0123456789abcdef"}
      """
    And "<agent>" sends the beacon:
      """
      {"kind": "read", "path": "/writing/hello", "read_seconds": 42, "view_token": "<token>",
        "timing": {"ttfb": 120, "dom_content_loaded": 480, "load": 910}}
      """
    Then the performance_pages table holds 0 rows

    Examples:
      | agent     | token                            |
      | an iPhone | 00000000000000000000000000000000 |
      | Googlebot | 0123456789abcdef0123456789abcdef |

  Scenario: A read stores no timing while the owner is signed in
    Given these analytics posts:
      | slug  | published |
      | hello | today-1   |
    And I am signed in to the admin
    When "an iPhone" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello", "view_token": "0123456789abcdef0123456789abcdef"}
      """
    And "an iPhone" sends the beacon:
      """
      {"kind": "read", "path": "/writing/hello", "read_seconds": 42, "view_token": "0123456789abcdef0123456789abcdef",
        "timing": {"ttfb": 120, "dom_content_loaded": 480, "load": 910}}
      """
    Then the server answered 202
    And the performance_pages table holds 0 rows

  Scenario: A timing row that cannot be written keeps the visit
    Given these analytics posts:
      | slug  | published |
      | hello | today-1   |
    And the database refuses to insert performance_pages rows
    When "an iPhone" sends the beacon:
      """
      {"kind": "view", "path": "/writing/hello", "view_token": "0123456789abcdef0123456789abcdef"}
      """
    And "an iPhone" sends the beacon:
      """
      {"kind": "read", "path": "/writing/hello", "read_seconds": 42, "view_token": "0123456789abcdef0123456789abcdef",
        "timing": {"ttfb": 120, "dom_content_loaded": 480, "load": 910}}
      """
    Then the server answered 202
    And the analytics_events rows are:
      | read_seconds |
      | 42           |

  Scenario: A job that finishes stores its class, outcome, time and queries
    When the job "Mail::Jobs::RecleanMailHtml" runs
    Then the performance_jobs table holds 1 rows where "job = 'Mail::Jobs::RecleanMailHtml' AND outcome = 'succeeded' AND duration > 0 AND query_count > 0 AND query_time >= 0 AND error_class IS NULL AND error_message IS NULL AND schedule_key IS NULL"

  Scenario: A scheduled job stores the schedule key that tells its entries apart
    When the job "Tasks::Jobs::SyncIssues" runs with "linear"
    Then the performance_jobs rows where "job = 'Tasks::Jobs::SyncIssues'" are:
      | schedule_key       | outcome   |
      | sync_issues_linear | succeeded |

  Scenario: A job that fails stores a failed outcome with the error
    Given the database refuses to insert analytics_rollups rows
    When the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the performance_jobs table holds 1 rows where "job = 'Analytics::Jobs::RollUpAnalytics' AND outcome = 'failed' AND error_class IS NOT NULL AND error_message LIKE '%features refused it%'"

  Scenario: A job whose timing row fails to write still finishes
    Given the database refuses to insert performance_jobs rows
    When the job "Analytics::Jobs::RollUpAnalytics" is pushed
    Then the analytics_rollups rows where "day = '{today-1}'" are:
      | views |
      | 0     |
